import 'package:flutter_test/flutter_test.dart';
import 'package:oplog_sync/oplog_sync.dart';
import 'package:planner/data/local_meta_dao.dart';
import 'package:planner/data/projection/default_registry.dart';
import 'package:planner/data/projection/entity_fields.dart';
import 'package:planner/sync/io_sync_fs.dart';
import 'package:planner/sync/node_identity.dart';

import 'support/devices.dart';

void main() {
  group('узел', () {
    test('новая база — новый id в базе и в метке', () async {
      final dev = await TestDevice.start();

      expect(dev.services.identity.isNew, isTrue);
      expect(dev.services.identity.previousNodeId, isNull);
      expect(await dev.services.meta.nodeId(), dev.nodeId);
      expect(dev.marker.value, dev.nodeId);
    });

    test('перезапуск — тот же узел, «Входящие» не создаются заново', () async {
      final first = await TestDevice.start();
      final ops = (await first.services.store.allOps()).length;
      final again = await first.restart();

      expect(again.nodeId, first.nodeId);
      expect(again.services.identity.isNew, isFalse);
      expect(await again.services.store.allOps(), hasLength(ops));
    });

    test(
      'копия базы на другом устройстве (метка с другим id) — новый узел',
      () async {
        final original = await TestDevice.start();
        final copy = await TestDevice.start(
          db: original.db,
          marker: MemoryNodeMarker('метка-другого-устройства'),
          seed: 2,
        );

        expect(copy.nodeId, isNot(original.nodeId));
        expect(copy.services.identity.previousNodeId, original.nodeId);
        expect(await copy.services.meta.nodeId(), copy.nodeId);
        expect(copy.marker.value, copy.nodeId);
      },
    );

    test('копия: невыгруженные правки прежнего узла записаны заново от '
        'нового и доходят до других устройств', () async {
      final folder = tempDir('copy_');
      final original = await TestDevice.start();
      final m = original.services.mutator;
      final t1 = await m.create(EntityTypes.task, {
        TaskFields.content: 'выгружена',
        TaskFields.priority: 3,
      });
      await original.folder(IoSyncFs(folder.path)).syncOnce();
      original.advance(const Duration(minutes: 1));
      final t2 = await m.create(EntityTypes.task, {
        TaskFields.content: 'не выгружена',
      });
      await m.update(EntityTypes.task, t1, {TaskFields.content: 'правка'});

      // База скопирована на другое устройство, исходного больше нет.
      final copy = await TestDevice.start(
        db: original.db,
        marker: MemoryNodeMarker(),
        seed: 2,
      );
      expect(await copy.services.meta.uploadedUpTo(), isNull);
      final adopted = {
        for (final op in await copy.ownOps()) (op.entityId, op.field),
      };
      expect(adopted, {
        (t1, TaskFields.content),
        (t2, TaskFields.content),
      }, reason: 'приоритет t1 уже выгружен — его не повторяем');

      await copy.folder(IoSyncFs(folder.path)).syncOnce();
      final other = await TestDevice.start(seed: 3);
      await other.folder(IoSyncFs(folder.path)).syncOnce();
      expect(await other.aliveTasks(), {
        t1: 'правка',
        t2: 'не выгружена',
        // «Входящие» — проект, в задачах их нет.
      });
      expect(await other.conflicts(), isEmpty);
    });
  });

  group('часы при запуске', () {
    test(
      'системное время ушло назад — выгрузка после перезапуска идёт',
      () async {
        final folder = tempDir('clock_');
        final dev = await TestDevice.start();
        await dev.services.mutator.create(EntityTypes.task, {
          TaskFields.content: 'до',
        });
        await dev.folder(IoSyncFs(folder.path)).syncOnce();

        dev.clock.set(testStart.subtract(const Duration(hours: 1)));
        final again = await dev.restart();
        final id = await again.services.mutator.create(EntityTypes.task, {
          TaskFields.content: 'после',
        });
        final report = await again.folder(IoSyncFs(folder.path)).syncOnce();

        expect(report?.uploaded, 1);
        final op = (await again.ownOps()).last;
        expect(op.entityId, id);
      },
    );

    test('сохранённых часов нет, время ушло назад — часы из журнала, выгрузка '
        'новой задачи идёт', () async {
      final folder = tempDir('clock_');
      final dev = await TestDevice.start();
      await dev.services.mutator.create(EntityTypes.task, {
        TaskFields.content: 'до',
      });
      await dev.folder(IoSyncFs(folder.path)).syncOnce();
      await dev.services.meta.remove(LocalMetaDao.hlcKey);

      dev.clock.set(testStart.subtract(const Duration(hours: 1)));
      final again = await dev.restart();
      await again.services.mutator.create(EntityTypes.task, {
        TaskFields.content: 'новая сущность — её ops в журнале ещё нет',
      });
      final report = await again.folder(IoSyncFs(folder.path)).syncOnce();

      expect(report?.uploaded, 1);
    });

    test(
      'без сохранённых часов правка всё равно позже увиденной чужой',
      () async {
        final folder = tempDir('clock_');
        final a = await TestDevice.start(seed: 1);
        final b = await TestDevice.start(seed: 2);
        // Часы a на 30 минут впереди — в пределах допуска, op принимается.
        a.advance(const Duration(minutes: 30));
        final id = await a.services.mutator.create(EntityTypes.task, {
          TaskFields.content: 'от a',
        });
        await a.folder(IoSyncFs(folder.path)).syncOnce();
        await b.folder(IoSyncFs(folder.path)).syncOnce();

        await b.services.meta.remove(LocalMetaDao.hlcKey);
        final again = await b.restart();
        await again.services.mutator.update(EntityTypes.task, id, {
          TaskFields.content: 'от b, после того как увидел a',
        });

        expect(
          (await again.taskRow(id))?.content,
          'от b, после того как увидел a',
        );
      },
    );

    test('сохранённые часы впереди журнала — следующая op позже них', () async {
      final dev = await TestDevice.start();
      final ahead = Hlc(
        wallMs: testStart.millisecondsSinceEpoch + 3600000,
        counter: 7,
        nodeId: dev.nodeId,
      );
      await dev.services.meta.setHlc(ahead);
      final again = await dev.restart();
      await again.services.mutator.create(EntityTypes.task, {
        TaskFields.content: 'x',
      });

      expect((await again.ownOps()).last.hlc > ahead, isTrue);
    });
  });

  test(
    'реестр проекторов обновился — таблицы переложены при запуске',
    () async {
      final dev = await TestDevice.start();
      final id = await dev.services.mutator.create(EntityTypes.task, {
        TaskFields.content: 'в таблице',
      });
      // Будто таблицу раскладывала старая версия, не знавшая content.
      await dev.db.customStatement("UPDATE tasks SET content = ''");
      await dev.services.meta.setProjectorVersion(projectorVersion - 1);

      final again = await dev.restart();

      expect((await again.taskRow(id))?.content, 'в таблице');
      expect(await again.services.meta.projectorVersion(), projectorVersion);
    },
  );

  test('«Входящие» — фиксированный id, создаются при первом запуске', () async {
    final dev = await TestDevice.start();
    final row = await (dev.db.select(
      dev.db.projects,
    )..where((t) => t.id.equals(inboxProjectId))).getSingle();

    expect((row.name, row.isInbox, row.deleted), ('Inbox', true, false));
  });
}
