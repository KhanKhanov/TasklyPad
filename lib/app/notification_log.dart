import 'package:logger/logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/notification_log.dart';
import 'data_providers.dart';

part 'notification_log.g.dart';

/// Журнал «Уведомления» этого устройства (решения 2А–4А plans/m5 «Решения
/// M5.3a»): загружается при запуске, каждое нижнее уведомление дописывается
/// ([record]). Изменения идут по очереди: две записи подряд не теряют друг
/// друга. Состояние в памяти меняется сразу, сохранение — следом; ошибка
/// сохранения пишется в лог, а не тостом — тост снова попал бы в журнал.
/// Подписки на базу нет: журнал пишет только этот процесс (один экземпляр
/// приложения), а `local_meta` меняется на каждую правку (часы движка).
@Riverpod(keepAlive: true)
class NotificationLogController extends _$NotificationLogController {
  static final Logger _log = Logger();

  Future<void> _tail = Future.value();

  @override
  Future<NotificationLog> build() =>
      ref.watch(notificationLogRepositoryProvider).load();

  /// Показано нижнее уведомление [text].
  Future<void> record(String text) {
    final at = ref.read(clockProvider).nowMs();
    return _change((log) => log.add(text, at));
  }

  /// Удалить запись [id].
  Future<void> remove(int id) => _change((log) => log.remove(id));

  /// «Очистить всё».
  Future<void> clear() => _change((log) => log.clear());

  /// Журнал открыли — счётчик непрочитанных обнуляется.
  Future<void> markRead() => _change((log) => log.markRead());

  /// Ошибка внутри шага не доходит до очереди: иначе упавший [_tail] не дал
  /// бы выполниться ни одной следующей записи до перезапуска. Без перемен
  /// (прочитано уже всё, журнал уже пуст) — ничего не пишется: каждая запись
  /// в `local_meta` будит подписки темы и конфликтов.
  Future<void> _change(NotificationLog Function(NotificationLog) f) {
    final repo = ref.read(notificationLogRepositoryProvider);
    return _tail = _tail.then((_) async {
      try {
        if (!ref.mounted) return;
        final current = await future;
        if (!ref.mounted) return;
        final next = f(current);
        if (next == current) return;
        state = AsyncData(next);
        await repo.save(next);
      } on Object catch (error, stack) {
        _log.e(
          'Журнал уведомлений не изменён',
          error: error,
          stackTrace: stack,
        );
      }
    });
  }
}
