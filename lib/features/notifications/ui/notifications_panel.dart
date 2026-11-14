import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/data_providers.dart';
import '../../../app/notification_log.dart';
import '../../../app/theme/app_palette.dart';
import '../../../domain/notification_log.dart';
import '../../../l10n/app_localizations.dart';

/// Журнал «Уведомления» (решения 2А–4А, вопрос 1А plans/m5 «Решения
/// M5.3a»): от новых к старым, у записи — текст и время, «×» удаляет её,
/// «Очистить всё» — все. «Отменить» нет: как в Todoist, отмена работает,
/// только пока тост на экране. Пока журнал открыт, всё в нём прочитано —
/// счётчик на вкладке обнуляется. [onClose] — кнопка «Закрыть» в заголовке
/// (журнал во весь экран на телефоне).
class NotificationsPanel extends ConsumerStatefulWidget {
  const NotificationsPanel({super.key, this.onClose});

  final VoidCallback? onClose;

  @override
  ConsumerState<NotificationsPanel> createState() => _NotificationsPanelState();
}

class _NotificationsPanelState extends ConsumerState<NotificationsPanel> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _markRead();
    });
  }

  void _markRead() {
    final log = ref.read(notificationLogControllerProvider).value;
    if (log != null && log.unread > 0) {
      ref.read(notificationLogControllerProvider.notifier).markRead();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Пришло новое уведомление, пока журнал открыт, — оно уже прочитано.
    ref.listen(notificationLogControllerProvider, (_, _) => _markRead());
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final log =
        ref.watch(notificationLogControllerProvider).value ??
        const NotificationLog();
    final items = log.items.reversed.toList();
    final controller = ref.read(notificationLogControllerProvider.notifier);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
          child: Row(
            children: [
              if (widget.onClose case final close?)
                IconButton(
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  icon: const Icon(Icons.close),
                  onPressed: close,
                ),
              Expanded(
                child: Text(
                  l10n.notifications,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: items.isEmpty ? null : controller.clear,
                child: Text(l10n.notificationsClearAll),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: palette.divider),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
            child: Text(
              l10n.notificationsEmpty,
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.textSecondary),
            ),
          )
        else
          // Колонка в прокрутке, а не ленивый список: меню измеряет
          // естественную ширину содержимого, а ленивый список так не
          // измерить; записей не больше 200.
          Flexible(
            child: SingleChildScrollView(
              primary: false,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final entry in items)
                    NotificationTile(
                      key: ValueKey(entry.id),
                      entry: entry,
                      onDelete: () => controller.remove(entry.id),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Запись журнала: текст, время (сегодня — только часы и минуты, иначе дата
/// и время по местному времени) и «×» — удалить.
class NotificationTile extends ConsumerWidget {
  const NotificationTile({
    super.key,
    required this.entry,
    required this.onDelete,
  });

  final NotificationEntry entry;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    // Стенное время записи — по тем же часам, что «сейчас»: пояс часов
    // приложения, а не машины (в тестах они могут различаться).
    final clock = ref.read(clockProvider);
    final now = clock.nowWall();
    final at = DateTime.fromMillisecondsSinceEpoch(
      entry.atMs,
      isUtc: true,
    ).add(now.difference(clock.nowUtc()));
    final today =
        at.year == now.year && at.month == now.month && at.day == now.day;
    final time = today
        ? DateFormat.Hm(locale).format(at)
        : DateFormat.MMMd(locale).add_Hm().format(at);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.text,
                    style: TextStyle(color: palette.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    time,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: l10n.notificationDelete,
            icon: Icon(Icons.close, size: 18, color: palette.textSecondary),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

/// Журнал во весь экран — на телефоне (из пункта сайдбара).
Future<void> showNotificationsFullscreen(BuildContext context) =>
    showDialog<void>(
      context: context,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: AppPalette.of(context).background,
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: NotificationsPanel(onClose: () => Navigator.pop(context)),
          ),
        ),
      ),
    );
