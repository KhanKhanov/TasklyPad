import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/ui/ui_kit.dart';
import '../../../app/data_providers.dart';
import '../../../app/theme/app_palette.dart';
import '../../../domain/workspace.dart';
import '../../../l10n/app_localizations.dart';
import '../../labels/ui/label_tile.dart';
import '../../projects/ui/project_dialog.dart';
import '../../projects/ui/project_tile.dart';
import '../../quick_add/ui/quick_add_dialog.dart';
import '../state/sidebar_state.dart';
import 'sidebar_items.dart';

/// Боковая панель, как в Todoist: «Входящие», «Фильтры и метки», «Избранное»
/// (проекты и метки), «Мои проекты» деревом. «Конфликты» (нашего дополнения)
/// видны, только пока есть нерешённые. «Добавить задачу» открывает окно
/// быстрого добавления; «Поиск», «Сегодня», «Предстоящее» появятся вместе со
/// своими экранами.
class Sidebar extends ConsumerWidget {
  const Sidebar({super.key, required this.location});

  /// Текущий путь — для выделения открытого пункта.
  final String location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final conflicts = ref.watch(
      openConflictsProvider.select((cards) => cards.value?.length ?? 0),
    );
    return ColoredBox(
      color: palette.sidebar,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 10, 4),
              child: Row(
                children: [
                  // Меню под названием — как меню аккаунта в Todoist:
                  // «Настройки» (`o s`).
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: PopupMenuButton<void>(
                        tooltip: l10n.settings,
                        itemBuilder: (context) => [
                          PopupMenuItem<void>(
                            onTap: () => navigate(context, '/settings'),
                            child: Text(l10n.settings),
                          ),
                        ],
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                l10n.appTitle,
                                style: TextStyle(
                                  color: palette.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Icon(
                                Icons.keyboard_arrow_down,
                                size: 18,
                                color: palette.textSecondary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.toggleSidebar,
                    icon: const Icon(Icons.view_sidebar_outlined, size: 20),
                    color: palette.textSecondary,
                    onPressed: () => _close(context, ref),
                  ),
                ],
              ),
            ),
            Expanded(
              child: WorkspaceView(
                builder: (context, ws) => ListView(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 16),
                  children: _content(context, ref, ws, conflicts),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _content(
    BuildContext context,
    WidgetRef ref,
    Workspace ws,
    int conflicts,
  ) {
    final l10n = AppLocalizations.of(context);
    final inbox = ws.inbox;
    final favorites = ws.favoriteProjects;
    final favoriteLabels = [
      for (final l in ws.labels)
        if (l.isFavorite) l,
    ];
    return [
      SidebarNavItem(
        icon: Icons.add_circle,
        iconColor: AppPalette.of(context).accent,
        label: l10n.addTask,
        count: 0,
        selected: false,
        onTap: () {
          final scaffold = Scaffold.maybeOf(context);
          if (scaffold != null && scaffold.isDrawerOpen) scaffold.closeDrawer();
          openQuickAdd(context, ref, location);
        },
      ),
      if (inbox != null)
        SidebarNavItem(
          icon: Icons.inbox_outlined,
          label: l10n.inbox,
          count: ws.activeTaskCount(inbox.id),
          selected: location == '/' || location == '/project/${inbox.id}',
          onTap: () => navigate(context, '/'),
        ),
      SidebarNavItem(
        icon: Icons.grid_view_outlined,
        label: l10n.filtersAndLabels,
        count: 0,
        // Метка из «Избранного» подсвечивается там, а не здесь.
        selected:
            location == '/filters-labels' ||
            (location.startsWith('/label/') &&
                !favoriteLabels.any((l) => location == '/label/${l.id}')),
        onTap: () => navigate(context, '/filters-labels'),
      ),
      if (conflicts > 0)
        SidebarNavItem(
          icon: Icons.sync_problem_outlined,
          label: l10n.conflicts,
          count: conflicts,
          countColor: AppPalette.of(context).danger,
          selected: location == '/conflicts',
          onTap: () => navigate(context, '/conflicts'),
        ),
      if (favorites.isNotEmpty || favoriteLabels.isNotEmpty) ...[
        SidebarGroupHeader(label: l10n.favorites),
        for (final p in favorites)
          ProjectTile(
            key: ValueKey('fav-${p.id}'),
            project: p,
            count: ws.activeTaskCount(p.id),
            selected: location == '/project/${p.id}',
          ),
        for (final l in favoriteLabels)
          LabelTile(
            key: ValueKey('fav-label-${l.id}'),
            label: l,
            count: ws.labelTaskCount(l.id),
            selected: location == '/label/${l.id}',
          ),
      ],
      SidebarGroupHeader(
        label: l10n.myProjects,
        onTap: () => navigate(context, '/projects'),
        selected: location == '/projects',
        trailing: IconButton(
          tooltip: l10n.addProject,
          icon: const Icon(Icons.add, size: 18),
          onPressed: () => showProjectDialog(context),
        ),
      ),
      for (final item in ws.projectTree())
        ProjectTile(
          key: ValueKey(item.value.id),
          project: item.value,
          count: ws.activeTaskCount(item.value.id),
          depth: item.depth,
          childCount: item.childCount,
          selected: location == '/project/${item.value.id}',
        ),
    ];
  }

  void _close(BuildContext context, WidgetRef ref) {
    final scaffold = Scaffold.maybeOf(context);
    if (scaffold != null && scaffold.isDrawerOpen) {
      scaffold.closeDrawer();
    } else {
      ref.read(sidebarOpenProvider.notifier).toggle();
    }
  }
}
