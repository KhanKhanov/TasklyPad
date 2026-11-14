import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/notification_log.dart';
import '../../../app/theme/app_palette.dart';
import '../../../l10n/app_localizations.dart';
import '../../common/ui/shielded_menu_anchor.dart';
import '../../common/ui/toast_lamp_anchor.dart';
import 'notifications_panel.dart';

/// Высота вкладки «Уведомления» — на столько панель выделения задач стоит
/// выше на компьютере.
const double notificationsTabHeight = 28;

/// Вкладка «Уведомления» на нижнем крае окна справа (решения 1А, 4А plans/m5
/// «Решения M5.3a»; наше дополнение): колокольчик, подпись и число
/// непрочитанных. Она же «лампа» нижних уведомлений — они выходят из неё и
/// втекают в неё. Нажатие (или `Enter`) открывает журнал всплывающей панелью
/// над вкладкой, как «Отображение» (вопрос 1А); `Esc` и щелчок мимо
/// закрывают её.
class NotificationsTab extends ConsumerWidget {
  const NotificationsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final unread =
        ref.watch(notificationLogControllerProvider).value?.unread ?? 0;
    return ShieldedMenuAnchor(
      menuChildren: [
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 360,
            minWidth: 360,
            // Не выше 60% окна: панель открывается над вкладкой.
            maxHeight: MediaQuery.sizeOf(context).height * 0.6 < 420
                ? MediaQuery.sizeOf(context).height * 0.6
                : 420,
          ),
          child: const NotificationsPanel(),
        ),
      ],
      builder: (context, controller, _) => ToastLampAnchor(
        anchor: Alignment.bottomCenter,
        child: Semantics(
          container: true,
          button: true,
          label: l10n.notificationsUnread(unread),
          // Потомки скрыты от диктора — нажатие задаём здесь.
          onTap: () =>
              controller.isOpen ? controller.close() : controller.open(),
          excludeSemantics: true,
          child: Material(
            color: palette.raised,
            shape: RoundedRectangleBorder(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
              side: BorderSide(color: palette.divider),
            ),
            child: InkWell(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
              onTap: () =>
                  controller.isOpen ? controller.close() : controller.open(),
              child: SizedBox(
                height: notificationsTabHeight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.notifications_none,
                        size: 16,
                        color: palette.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        l10n.notifications,
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      if (unread > 0) ...[
                        const SizedBox(width: 6),
                        UnreadBadge(count: unread),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Кружок с числом непрочитанных, больше 99 — «99+».
class UnreadBadge extends StatelessWidget {
  const UnreadBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 18),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: palette.accent,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
