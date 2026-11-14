import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/app/data_providers.dart';
import 'package:planner/app/notification_log.dart';
import 'package:planner/app/sync_providers.dart';
import 'package:planner/data/local_meta_dao.dart';
import 'package:planner/data/repositories/notification_log_repository.dart';
import 'package:planner/domain/notification_log.dart';

import '../sync/support/devices.dart';

// Журнал «Уведомления» в приложении (решения 2А–4А plans/m5 «Решения
// M5.3a»): время — из часов приложения, записи не теряются, журнал
// переживает перезапуск; битое значение — пустой журнал.
void main() {
  ProviderContainer containerOf(TestDevice dev) {
    final container = ProviderContainer(
      overrides: [syncServicesProvider.overrideWithValue(dev.services)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('запись — время из часов приложения; две подряд не теряются', () async {
    final dev = await TestDevice.start();
    final container = containerOf(dev);
    final log = container.read(notificationLogControllerProvider.notifier);
    await container.read(notificationLogControllerProvider.future);
    await Future.wait([log.record('A'), log.record('B')]);
    final state = container.read(notificationLogControllerProvider).value!;
    expect([for (final e in state.items) e.text], ['A', 'B']);
    expect(state.items.first.atMs, dev.clock.nowMs());
    expect(state.unread, 2);
  });

  test('после перезапуска журнал и счётчик на месте', () async {
    final dev = await TestDevice.start();
    final first = containerOf(dev);
    final log = first.read(notificationLogControllerProvider.notifier);
    await first.read(notificationLogControllerProvider.future);
    await log.record('A');
    await log.record('B');
    await log.markRead();
    await log.record('C');

    final again = containerOf(await dev.restart());
    final state = await again.read(notificationLogControllerProvider.future);
    expect([for (final e in state.items) e.text], ['A', 'B', 'C']);
    expect(state.unread, 1);
  });

  test('удалить одну и «Очистить всё»', () async {
    final dev = await TestDevice.start();
    final container = containerOf(dev);
    final log = container.read(notificationLogControllerProvider.notifier);
    await container.read(notificationLogControllerProvider.future);
    await log.record('A');
    await log.record('B');
    await log.remove(1);
    expect(
      [
        for (final e
            in container.read(notificationLogControllerProvider).value!.items)
          e.text,
      ],
      ['B'],
    );
    await log.clear();
    expect((await NotificationLogRepository(dev.db).load()).items, isEmpty);
  });

  for (final (name, value) in const [
    ('не JSON', '{oops'),
    ('не объект', '[]'),
    ('число строкой', '{"v":1,"next":"1","seen":0,"items":[]}'),
    (
      'запись без текста',
      '{"v":1,"next":2,"seen":0,"items":[{"id":1,"at":0}]}',
    ),
    (
      'повтор id',
      '{"v":1,"next":3,"seen":0,"items":[{"id":1,"at":0,"text":"a"},{"id":1,"at":0,"text":"b"}]}',
    ),
    (
      'next не больше id',
      '{"v":1,"next":1,"seen":0,"items":[{"id":1,"at":0,"text":"a"}]}',
    ),
    ('другая версия', '{"v":2,"next":1,"seen":0,"items":[]}'),
  ]) {
    test(
      'битое значение в local_meta ($name) — пустой журнал без ошибки',
      () async {
        final dev = await TestDevice.start();
        await LocalMetaDao(dev.db)
            .write(LocalMetaDao.notificationLogKey, value);
        expect(
          await NotificationLogRepository(dev.db).load(),
          const NotificationLog(),
        );
      },
    );
  }

  test('загрузка упала — запись не бросает и не ломает очередь; без перемен '
      'ничего не пишется', () async {
    final dev = await TestDevice.start();
    final repo = _FlakyRepository(dev);
    final container = ProviderContainer(
      overrides: [
        syncServicesProvider.overrideWithValue(dev.services),
        notificationLogRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    final log = container.read(notificationLogControllerProvider.notifier);
    await expectLater(log.record('A'), completes);
    expect(repo.saves, 0);

    // База снова читается — следующая запись проходит.
    repo.failLoad = false;
    container.invalidate(notificationLogControllerProvider);
    final again = container.read(notificationLogControllerProvider.notifier);
    await again.record('B');
    expect(repo.saves, 1);
    await again.markRead();
    await again.markRead();
    expect(repo.saves, 2);
  });
}

/// Хранилище, у которого загрузка падает, пока [failLoad].
final class _FlakyRepository extends NotificationLogRepository {
  _FlakyRepository(TestDevice dev) : super(dev.db);

  bool failLoad = true;
  int saves = 0;

  @override
  Future<NotificationLog> load() async {
    if (failLoad) throw StateError('база занята');
    return super.load();
  }

  @override
  Future<void> save(NotificationLog log) async {
    saves++;
    await super.save(log);
  }
}
