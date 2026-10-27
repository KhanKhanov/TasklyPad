import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_palette.dart';
import '../../../l10n/app_localizations.dart';
import '../../settings/state/sync_controller.dart';
import '../state/sidebar_state.dart';
import 'shell_keys.dart';
import 'sidebar.dart';

/// Ширина, начиная с которой сайдбар стоит рядом с контентом, а не
/// выезжает поверх (телефон, узкое окно).
const double wideLayoutWidth = 720;
const double _sidebarWidth = 280;

/// Оболочка всех экранов: сайдбар слева и контент справа; на узком экране
/// сайдбар — выдвижная панель.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  final GlobalKey<ScaffoldState> _scaffold = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final open = ref.watch(sidebarOpenProvider);
    // Синхронизация работает, пока открыто приложение, а не только экран
    // настроек: подписка держит её состояние и таймеры.
    ref.listen(syncControllerProvider, (_, _) {});
    final location = widget.location;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= wideLayoutWidth;
        return ShellKeys(
          onToggleSidebar: () {
            final scaffold = _scaffold.currentState;
            if (wide) {
              ref.read(sidebarOpenProvider.notifier).toggle();
            } else if (scaffold == null) {
              return;
            } else if (scaffold.isDrawerOpen) {
              scaffold.closeDrawer();
            } else {
              scaffold.openDrawer();
            }
          },
          child: Scaffold(
            key: _scaffold,
            backgroundColor: palette.background,
            drawer: wide
                ? null
                : Drawer(
                    width: _sidebarWidth,
                    child: Sidebar(location: location),
                  ),
            body: Row(
              children: [
                if (wide && open)
                  SizedBox(
                    width: _sidebarWidth,
                    child: Sidebar(location: location),
                  ),
                Expanded(
                  child: Column(
                    children: [
                      _TopBar(showToggle: !wide || !open),
                      Expanded(child: widget.child),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Верхняя строка контента: кнопка открыть сайдбар, когда он скрыт.
class _TopBar extends ConsumerWidget {
  const _TopBar({required this.showToggle});

  final bool showToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          if (showToggle)
            IconButton(
              tooltip: l10n.toggleSidebar,
              icon: const Icon(Icons.view_sidebar_outlined, size: 20),
              color: AppPalette.of(context).textSecondary,
              onPressed: () {
                final scaffold = Scaffold.of(context);
                if (scaffold.hasDrawer) {
                  scaffold.openDrawer();
                } else {
                  ref.read(sidebarOpenProvider.notifier).toggle();
                }
              },
            ),
        ],
      ),
    );
  }
}
