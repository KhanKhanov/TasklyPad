import 'package:logger/logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/recently_viewed.dart';
import 'data_providers.dart';
import 'router.dart';

part 'recently_viewed.g.dart';

/// Просмотр по адресу экрана: «Входящие», «Сегодня», «Предстоящее», проект,
/// метка, фильтр; остальные экраны (списки проектов, настройки, конфликты) —
/// `null` (в help не описано — допущение, О-69).
ViewedItem? viewedItemOf(Uri location) => switch (location.pathSegments) {
  [] => const ViewedItem(ViewedKind.inbox),
  ['today'] => const ViewedItem(ViewedKind.today),
  ['upcoming'] => const ViewedItem(ViewedKind.upcoming),
  ['project', final id] => ViewedItem(ViewedKind.project, id),
  ['label', final id] => ViewedItem(ViewedKind.label, id),
  ['filter', final id] => ViewedItem(ViewedKind.filter, id),
  _ => null,
};

/// «Недавно просмотренное» окна поиска (решение 1А plans/m5 «Решения M5.4»):
/// экраны — по адресу роутера (один источник для сайдбара, клавиш, поиска и
/// истории), задачи — [recordTask] из окна задачи. Память устройства в
/// `local_meta`; изменения по очереди, ошибка сохранения — в лог (как журнал
/// «Уведомления»), без перемен ничего не пишется.
@Riverpod(keepAlive: true)
class RecentlyViewedController extends _$RecentlyViewedController {
  static final Logger _log = Logger();

  Future<void> _tail = Future.value();

  @override
  Future<RecentlyViewed> build() {
    final delegate = ref.watch(routerProvider).routerDelegate;
    void record() {
      final config = delegate.currentConfiguration;
      if (config.isEmpty) return;
      final item = viewedItemOf(config.uri);
      if (item != null) _visit(item);
    }

    delegate.addListener(record);
    ref.onDispose(() => delegate.removeListener(record));
    // Первый экран — после загрузки: `_visit` ждёт `future`.
    Future.microtask(record);
    return ref.watch(recentlyViewedRepositoryProvider).load();
  }

  /// Открыли окно задачи [id] (и соседнюю — `J` / `K`).
  Future<void> recordTask(String id) => _visit(ViewedItem(ViewedKind.task, id));

  Future<void> _visit(ViewedItem item) {
    final repo = ref.read(recentlyViewedRepositoryProvider);
    return _tail = _tail.then((_) async {
      try {
        if (!ref.mounted) return;
        final current = await future;
        if (!ref.mounted) return;
        final next = current.visit(item);
        if (identical(next, current)) return;
        state = AsyncData(next);
        await repo.save(next);
      } on Object catch (error, stack) {
        _log.e(
          'Недавно просмотренное не изменено',
          error: error,
          stackTrace: stack,
        );
      }
    });
  }
}
