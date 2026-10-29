import 'package:flutter_test/flutter_test.dart';
import 'package:oplog_sync/oplog_sync.dart';
import 'package:planner/core/clock.dart';
import 'package:planner/data/app_database.dart';
import 'package:planner/data/local_meta_dao.dart';
import 'package:planner/data/projection/entity_fields.dart';
import 'package:planner/sync/io_sync_fs.dart';
import 'package:planner/sync/sync_lease.dart';

import '../data/support/drift_probe.dart';
import 'support/devices.dart';

void main() {
  late AppDatabase db;
  late FixedClock clock;

  setUp(() {
    db = memoryDatabase();
    clock = FixedClock(testStart);
  });

  SyncLease lease(String owner) => SyncLease(db, owner: owner, clock: clock);

  test('свободная аренда захватывается, второй владелец — отказ', () async {
    expect(await lease('ui').tryAcquire(), isTrue);
    expect(await lease('фон').tryAcquire(), isFalse);
  });

  test('свой владелец продлевает аренду', () async {
    final ui = lease('ui');
    expect(await ui.tryAcquire(), isTrue);
    clock.advance(const Duration(minutes: 9));
    expect(await ui.tryAcquire(), isTrue);
    clock.advance(const Duration(minutes: 9));
    expect(await lease('фон').tryAcquire(), isFalse, reason: 'продлена');
  });

  test('истёкшая аренда (владелец упал) перехватывается', () async {
    expect(await lease('ui').tryAcquire(), isTrue);
    clock.advance(const Duration(minutes: 10));
    expect(await lease('фон').tryAcquire(), isTrue);
  });

  test('release отдаёт только свою аренду', () async {
    final ui = lease('ui');
    await ui.tryAcquire();
    await lease('фон').release();
    expect(await lease('фон').tryAcquire(), isFalse);
    await ui.release();
    expect(await lease('фон').tryAcquire(), isTrue);
  });

  test('битая запись аренды считается свободной', () async {
    await LocalMetaDao(db).write(LocalMetaDao.syncLeaseKey, 'не json');
    expect(await lease('ui').tryAcquire(), isTrue);
  });

  test(
    'JSON без нужных ключей — аренда свободна, а не занята навсегда',
    () async {
      await LocalMetaDao(db).write(LocalMetaDao.syncLeaseKey, '{}');
      expect(await lease('ui').tryAcquire(), isTrue);
    },
  );

  group('FolderSync', () {
    test(
      'пока синхронизирует другой экземпляр — пропуск, папка не тронута',
      () async {
        final folder = tempDir('lease_');
        final dev = await TestDevice.start();
        await dev.services.mutator.create(EntityTypes.task, {
          TaskFields.content: 'x',
        });
        final other = SyncLease(dev.db, owner: 'фон', clock: dev.clock);
        expect(await other.tryAcquire(), isTrue);

        final report = await dev.folder(IoSyncFs(folder.path)).syncOnce();

        expect(report, isNull);
        expect(folder.listSync(), isEmpty);
      },
    );

    test('аренда прежнего запуска (окно закрыли посреди прохода) не мешает '
        'первому проходу после перезапуска', () async {
      final folder = tempDir('lease_');
      final dev = await TestDevice.start();
      final stale = SyncLease(
        dev.db,
        owner: 'прежний запуск',
        clock: dev.clock,
      );
      expect(await stale.tryAcquire(), isTrue);

      final again = await dev.restart();
      final report = await again.folder(IoSyncFs(folder.path)).syncOnce();
      expect(report, isNotNull);
    });

    test('аренда отпускается и после ошибки транспорта', () async {
      final folder = tempDir('lease_');
      final fs = IoSyncFs(folder.path);
      await fs.writeString('planner-sync/format.json', '{"v": 99}\n');
      final dev = await TestDevice.start();

      await expectLater(
        dev.folder(fs).syncOnce(),
        throwsA(isA<SyncFormatException>()),
      );
      final other = SyncLease(dev.db, owner: 'фон', clock: dev.clock);
      expect(await other.tryAcquire(), isTrue);
    });
  });
}
