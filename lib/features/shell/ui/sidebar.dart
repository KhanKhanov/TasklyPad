import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/ui/ui_kit.dart';
import '../../../app/theme/app_palette.dart';
import '../../../domain/workspace.dart';
import '../../../l10n/app_localizations.dart';
import '../../projects/ui/project_dialog.dart';
import '../../projects/ui/project_tile.dart';
import '../state/sidebar_state.dart';

/// Боковая панель, как в Todoist: «Входящие», «Избранное», «Мои проекты»
/// деревом. Пункты «Добавить задачу», «Поиск», «Сегодня», «Предстоящее» и
/// «Фильтры и метки» появляются вместе со своими экранами (M2.2–M5).
class Sidebar extends ConsumerWidget {
  const Sidebar({super.key, required this.location});

  /// Текущий путь — для выделения открытого пункта.
  final String location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    return ColoredBox(
      color: palette.sidebar,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 10, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.appTitle,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w600,
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
                  children: _content(context, ws),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _content(BuildContext context, Workspace ws) {
    final l10n = AppLocalizations.of(context);
    final inbox = ws.inbox;
    final favorites = ws.favoriteProjects;
    return [
      if (inbox != null)
        _NavItem(
          icon: Icons.inbox_outlined,
          label: l10n.inbox,
          count: ws.activeTaskCount(inbox.id),
          selected: location == '/' || location == '/project/${inbox.id}',
          onTap: () => navigate(context, '/'),
        ),
      if (favorites.isNotEmpty) ...[
        _GroupHeader(label: l10n.favorites),
        for (final p in favorites)
          ProjectTile(
            key: ValueKey('fav-${p.id}'),
            project: p,
            count: ws.activeTaskCount(p.id),
            selected: location == '/project/${p.id}',
          ),
      ],
      _GroupHeader(
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

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final color = selected ? palette.onSelected : palette.textPrimary;
    return Material(
      color: selected ? palette.selected : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: SizedBox(
          height: 34,
          child: Row(
            children: [
              const SizedBox(width: 8),
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label, style: TextStyle(color: color)),
              ),
              if (count > 0)
                SizedBox(
                  width: 36,
                  child: Text(
                    '$count',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.label,
    this.onTap,
    this.trailing,
    this.selected = false,
  });

  final String label;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Material(
        color: selected ? palette.selected : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: SizedBox(
            height: 34,
            child: Row(
              children: [
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
