import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/nav_history.dart';
import '../../../app/notification_log.dart';
import '../../../app/theme/app_palette.dart';
import '../../../l10n/app_localizations.dart';
import '../../common/ui/drag_layer.dart';
import '../../common/ui/layout.dart';
import '../../common/ui/toast_lamp_anchor.dart';
import '../../common/ui/ui_kit.dart';
import '../../conflicts/ui/conflict_toast.dart';
import '../../filters/ui/filter_dialog.dart';
import '../../notifications/ui/notifications_tab.dart';
import '../../quick_add/ui/quick_add_dialog.dart';
import '../../settings/state/sync_controller.dart';
import '../../tasks/state/selection.dart';
import '../../tasks/ui/selection_keys.dart';
import '../../tasks/ui/selection_toolbar.dart';
import '../state/sidebar_state.dart';
import 'account_menu.dart';
import 'shell_keys.dart';
import 'sidebar.dart';

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

  /// Содержимое окна без нижнего уведомления: тут ищется место броска.
  final GlobalKey _bodyKey = GlobalKey();

  /// Первая кнопка панели выделения — на неё ведёт `,`.
  final FocusNode _toolbarFocus = FocusNode();

  @override
  void didUpdateWidget(AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Выделение — у вида: другой экран его снимает (решение 9 плана M4).
    // После кадра: менять провайдер, пока строится дерево, нельзя.
    if (oldWidget.location != widget.location) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(taskSelectionProvider.notifier).clear();
      });
    }
  }

  @override
  void dispose() {
    _toolbarFocus.dispose();
    super.dispose();
  }

  /// Шаг по истории экранов: [step] берёт адрес у истории (назад или вперёд).
  void _travel(String? Function(NavHistory history) step) {
    final path = step(ref.read(navHistoryProvider));
    if (path != null) navigate(context, path);
  }

  /// Боковые кнопки мыши «Назад» и «Вперёд» — как `Alt+←` и `Alt+→`. Над
  /// панелью задачи и другими окнами не срабатывают: окно лежит поверх
  /// оболочки и забирает нажатия.
  void _onPointerDown(PointerDownEvent event) {
    if (event.buttons & kBackMouseButton != 0) {
      _travel((h) => h.back());
    } else if (event.buttons & kForwardMouseButton != 0) {
      _travel((h) => h.forward());
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final open = ref.watch(sidebarOpenProvider);
    // Синхронизация работает, пока открыто приложение, а не только экран
    // настроек: подписка держит её состояние и таймеры.
    ref.listen(syncControllerProvider, (_, _) {});
    final location = widget.location;
    final selecting = ref.watch(taskSelectionProvider.select((s) => s.active));
    // История экранов ведётся с первого показа оболочки.
    ref.watch(navHistoryProvider);
    // Журнал «Уведомления» загружается сразу, а не с первым тостом;
    // подписка без перестройки оболочки на каждую запись.
    ref.listen(notificationLogControllerProvider, (_, _) {});
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= wideLayoutWidth;
        final tab = wide ? notificationsTabHeight : 0.0;
        // Уведомления о конфликтах — тоже на всё время работы приложения.
        // Системная «Назад» при выделении снимает его, а не уходит с экрана.
        return PopScope(
          canPop: !selecting,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) ref.read(taskSelectionProvider.notifier).clear();
          },
          child: ConflictNoticeListener(
            child: ShellKeys(
              onQuickAdd: () => openQuickAdd(context, ref, location),
              onSync: () => syncFromShell(context, ref),
              onAddFilter: () => showFilterDialog(context),
              onBack: () => _travel((h) => h.back()),
              onForward: () => _travel((h) => h.forward()),
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
              child: Listener(
                onPointerDown: _onPointerDown,
                // Один приёмник перетаскивания на всё окно: списки, сайдбар.
                child: DragLayer(
                  // Слоты ищутся в теле `Scaffold`, а не во всём окне: нижнее
                  // уведомление непрозрачно для попадания, и на узком экране бросок
                  // под ним пропадал бы. Выдвижная панель сайдбара на узком экране
                  // вне тела: пока она открыта, затемнение закрывает её по касанию,
                  // и перетаскивание не начать — бросать в неё нечего.
                  hitRoot: _bodyKey,
                  child: Scaffold(
                    key: _scaffold,
                    backgroundColor: palette.background,
                    drawer: wide
                        ? null
                        : Drawer(
                            width: _sidebarWidth,
                            child: Sidebar(
                              location: location,
                              showNotifications: true,
                            ),
                          ),
                    body: Row(
                      key: _bodyKey,
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
                              Expanded(
                                child: SelectionKeys(
                                  toolbarFocus: _toolbarFocus,
                                  child: Stack(
                                    children: [
                                      // Панель выделения не закрывает конец
                                      // списка.
                                      Positioned.fill(
                                        child: Padding(
                                          padding: EdgeInsets.only(
                                            bottom: selecting ? 72 + tab : 0,
                                          ),
                                          child: widget.child,
                                        ),
                                      ),
                                      // Над вкладкой «Уведомления».
                                      Positioned(
                                        left: 16,
                                        right: 16,
                                        bottom: 16 + tab,
                                        child: Center(
                                          child: SelectionToolbar(
                                            focus: _toolbarFocus,
                                          ),
                                        ),
                                      ),
                                      // Вкладка «Уведомления» — на 78% ширины
                                      // контента (решение 1А plans/m5
                                      // «Решения M5.3a»); на телефоне «лампа»
                                      // — правый нижний угол.
                                      if (wide)
                                        const Positioned(
                                          left: 0,
                                          right: 0,
                                          bottom: 0,
                                          child: Align(
                                            alignment: Alignment(0.56, 1),
                                            heightFactor: 1,
                                            child: NotificationsTab(),
                                          ),
                                        )
                                      else
                                        const Positioned(
                                          right: 0,
                                          bottom: 0,
                                          child: ToastLampAnchor(
                                            anchor: Alignment.bottomRight,
                                            mouth: 24,
                                            child: SizedBox(
                                              width: 1,
                                              height: 1,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Верхняя строка контента: кнопка открыть сайдбар, когда он скрыт; справа —
/// «Настройки», как в шапке Todoist (решение пользователя 2А «Ход M3.8»).
class _TopBar extends ConsumerWidget {
  const _TopBar({required this.showToggle});

  final bool showToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          if (showToggle)
            IconButton(
              tooltip: l10n.toggleSidebar,
              icon: const Icon(Icons.view_sidebar_outlined, size: 20),
              color: palette.textSecondary,
              onPressed: () {
                final scaffold = Scaffold.of(context);
                if (scaffold.hasDrawer) {
                  scaffold.openDrawer();
                } else {
                  ref.read(sidebarOpenProvider.notifier).toggle();
                }
              },
            ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: palette.textSecondary,
              ),
              icon: const Icon(Icons.settings_outlined, size: 20),
              label: Text(l10n.settings),
              onPressed: () => navigate(context, '/settings'),
            ),
          ),
        ],
      ),
    );
  }
}
