import 'dart:math';

import 'package:drift/drift.dart' show Table, TableInfo;
import 'package:flutter_test/flutter_test.dart';
import 'package:oplog_sync/oplog_sync.dart';
import 'package:planner/core/ids.dart';
import 'package:planner/data/app_database.dart';
import 'package:planner/data/local_meta_dao.dart';
import 'package:planner/data/projection/default_registry.dart';
import 'package:planner/data/projection/entity_fields.dart';
import 'package:planner/data/projection/projector.dart';
import 'package:planner/sync/io_sync_fs.dart';
import 'package:planner/sync/node_identity.dart';
import 'package:planner/sync/sync_services.dart';

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

  group('правила конфликтов (О-58)', () {
    test('новая база — версия правил записана при первом запуске', () async {
      final dev = await TestDevice.start();

      expect(
        await dev.services.meta.conflictRulesVersion(),
        conflictRulesVersion,
      );
    });

    test('конфликты посчитаны прежними правилами — запуск один раз '
        'пересобирает: ложной строки нет, разрешённый конфликт остаётся '
        'разрешённым', () async {
      final pc = await TestDevice.start();
      final phone = await TestDevice.start(seed: 2);
      final id = await pc.services.mutator.create(EntityTypes.task, {
        TaskFields.content: 'v0',
      });
      await phone.services.engine.applyAll(await pc.ownOps());
      pc.advance(const Duration(seconds: 1));
      phone.advance(const Duration(seconds: 2));
      await pc.services.mutator.update(EntityTypes.task, id, {
        TaskFields.content: 'с ПК',
      });
      await phone.services.mutator.update(EntityTypes.task, id, {
        TaskFields.content: 'с телефона',
      });
      await pc.services.engine.applyAll(await phone.ownOps());
      final real = (await pc.conflicts()).single;
      await pc.services.mutator.resolveConflict(real.id, {
        TaskFields.content: 'с ПК',
      });

      // База M2: строка, которую правила M3.1 не дают, и нет версии правил.
      Future<void> addFalseRow() => pc.db
          .into(pc.db.conflicts)
          .insert(
            ConflictsCompanion.insert(
              id: 'ложный',
              kind: ConflictKind.delete.name,
              entityType: EntityTypes.task,
              entityId: id,
              field: TaskFields.content,
              olderOpId: 'x',
              newerOpId: 'y',
            ),
          );
      await addFalseRow();
      await pc.services.meta.remove(LocalMetaDao.conflictRulesVersionKey);

      final updated = await pc.restart();
      final after = await updated.conflicts();
      expect(after.map((c) => (c.id, c.resolved)), [(real.id, true)]);
      expect(
        await updated.services.meta.conflictRulesVersion(),
        conflictRulesVersion,
      );
      expect((await updated.taskRow(id))?.content, 'с ПК');

      // Версия совпадает — следующий запуск базу не пересобирает.
      await addFalseRow();
      final again = await updated.restart();
      expect((await again.conflicts()).map((c) => c.id).toSet(), {
        real.id,
        'ложный',
      });
    });

    test('копия базы M2 на другом устройстве — в одном запуске пересборка и '
        'переиздание невыгруженных правок, база устойчива к rebuild', () async {
      final original = await TestDevice.start();
      final id = await original.services.mutator.create(EntityTypes.task, {
        TaskFields.content: 'не выгружена',
      });
      await original.services.meta.remove(LocalMetaDao.conflictRulesVersionKey);

      final copy = await TestDevice.start(
        db: original.db,
        marker: MemoryNodeMarker(),
        seed: 2,
      );
      expect(copy.services.identity.previousNodeId, original.nodeId);
      expect(
        await copy.services.meta.conflictRulesVersion(),
        conflictRulesVersion,
      );
      expect(
        (await copy.ownOps()).map((op) => (op.entityId, op.field)),
        contains((id, TaskFields.content)),
      );
      expect(await copy.conflicts(), isEmpty);
      final tasks = await copy.aliveTasks();
      await copy.services.engine.rebuild();
      expect(await copy.aliveTasks(), tasks);
      expect(await copy.conflicts(), isEmpty);
    });

    test('сбой посреди пересборки — откат, версия не записана, следующий '
        'запуск повторяет', () async {
      final dev = await TestDevice.start();
      final id = await dev.services.mutator.create(EntityTypes.task, {
        TaskFields.content: 'Отчёт',
      });
      await dev.services.meta.remove(LocalMetaDao.conflictRulesVersionKey);
      final ops = (await dev.services.store.allOps()).length;

      // Реестр той же версии (без reproject), проектор задач падает.
      final normal = defaultRegistry(dev.db);
      final failing = ProjectorRegistry(normal.version, [
        for (final p in normal.all)
          p.entityType == EntityTypes.task ? _FailingProjector(p) : p,
      ]);
      await expectLater(
        startSync(
          dev.db,
          clock: dev.clock,
          ids: IdGenerator(random: Random(7)),
          marker: dev.marker,
          registry: failing,
        ),
        throwsA(isA<StateError>()),
      );
      expect(await dev.services.meta.conflictRulesVersion(), isNull);
      expect(await dev.services.store.allOps(), hasLength(ops));
      expect((await dev.taskRow(id))?.content, 'Отчёт');

      final again = await dev.restart();
      expect(
        await again.services.meta.conflictRulesVersion(),
        conflictRulesVersion,
      );
      expect((await again.taskRow(id))?.content, 'Отчёт');
    });
  });

  test('«Входящие» — фиксированный id, создаются при первом запуске', () async {
    final dev = await TestDevice.start();
    final row = await (dev.db.select(
      dev.db.projects,
    )..where((t) => t.id.equals(inboxProjectId))).getSingle();

    expect((row.name, row.isInbox, row.deleted), ('Inbox', true, false));
  });
}

/// Проектор, который падает на любой записи, — сбой посреди пересборки.
final class _FailingProjector implements EntityProjector {
  _FailingProjector(this._inner);

  final EntityProjector _inner;

  @override
  String get entityType => _inner.entityType;

  @override
  Set<String> get fields => _inner.fields;

  @override
  TableInfo<Table, Object?> get table => _inner.table;

  @override
  Future<bool> write(String id, String field, Object? value) =>
      throw StateError('сбой посреди пересборки');

  @override
  Future<void> clear() => _inner.clear();

  @override
  Set<String> columnsOf(String field) => _inner.columnsOf(field);

  @override
  bool isDefault(String field, Object? value) => _inner.isDefault(field, value);
}
