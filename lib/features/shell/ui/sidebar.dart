import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../common/ui/ui_kit.dart';
import '../../conflicts/ui/conflicts_navigation.dart';
import '../../../app/data_providers.dart';
import '../../../app/theme/app_palette.dart';
import '../../../domain/workspace.dart';
import '../../../l10n/app_localizations.dart';
import '../../labels/ui/label_tile.dart';
import '../../projects/ui/project_dialog.dart';
import '../../projects/ui/project_drag.dart';
import '../../projects/ui/project_tile.dart';
import '../../quick_add/ui/quick_add_dialog.dart';
import '../../tasks/logic/due_dates.dart';
import '../../tasks/state/today.dart';
import '../../tasks/ui/task_drop_places.dart';
import '../state/sidebar_state.dart';
import 'account_menu.dart';
import 'sidebar_items.dart';

/// Боковая панель, как в Todoist: «Входящие», «Сегодня» (со счётчиком
/// сегодняшних и просроченных — допущение О-69), «Предстоящее», «Фильтры и
/// метки», «Избранное» (проекты и метки), «Мои проекты» деревом.
/// «Конфликты» (нашего дополнения) видны, только пока есть нерешённые.
/// «Добавить задачу» открывает окно быстрого добавления; «Поиск» появится
/// вместе со своим экраном.
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
                  const Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: AccountMenu(),
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
    // Счётчик «Сегодня» меняется в полночь.
    final today = ref.watch(todayProvider);
    final tree = ws.projectTree();
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
      // Бросок задач на проект — в конец его задач без раздела.
      if (inbox != null)
        ProjectDropSlot(
          projectId: inbox.id,
          child: SidebarNavItem(
            icon: Icons.inbox_outlined,
            label: l10n.inbox,
            count: ws.activeTaskCount(inbox.id),
            selected: location == '/' || location == '/project/${inbox.id}',
            onTap: () => navigate(context, '/'),
          ),
        ),
      SidebarNavItem(
        icon: Icons.calendar_today_outlined,
        label: l10n.todayView,
        count: ws.todayCount(isoDate(today)),
        selected: location == '/today',
        onTap: () => navigate(context, '/today'),
      ),
      SidebarNavItem(
        icon: Icons.calendar_month_outlined,
        label: l10n.upcomingView,
        count: 0,
        selected: location == '/upcoming',
        onTap: () => navigate(context, '/upcoming'),
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
          onTap: () {
            final scaffold = Scaffold.maybeOf(context);
            if (scaffold != null && scaffold.isDrawerOpen) {
              scaffold.closeDrawer();
            }
            showConflictsScreen(GoRouter.of(context));
          },
        ),
      if (favorites.isNotEmpty || favoriteLabels.isNotEmpty) ...[
        SidebarGroupHeader(label: l10n.favorites),
        for (final p in favorites)
          ProjectDropSlot(
            key: ValueKey('fav-${p.id}'),
            projectId: p.id,
            child: ProjectTile(
              project: p,
              count: ws.activeTaskCount(p.id),
              selected: location == '/project/${p.id}',
            ),
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
      for (final item in tree)
        ProjectDropSlot(
          key: ValueKey(item.value.id),
          projectId: item.value.id,
          // Проект тянется за всю строку; задачи на него по-прежнему падают.
          child: ProjectDragTile(
            item: item,
            items: tree,
            ws: ws,
            surface: 'side',
            child: ProjectTile(
              project: item.value,
              count: ws.activeTaskCount(item.value.id),
              depth: item.depth,
              childCount: item.childCount,
              selected: location == '/project/${item.value.id}',
            ),
          ),
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
