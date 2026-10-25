import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:oplog_sync/oplog_sync.dart';
import 'package:planner/core/ids.dart';
import 'package:planner/data/projection/entity_fields.dart';

import 'support/devices.dart';

void main() {
  late TestDevice dev;

  setUp(() async => dev = await TestDevice.start());

  Future<List<Op>> opsOf(String id) async =>
      (await dev.ownOps()).where((o) => o.entityId == id).toList();

  test(
    'create — id UUIDv7, op на каждое поле с одним HLC, строка в tasks',
    () async {
      final id = await dev.services.mutator.create(EntityTypes.task, {
        TaskFields.content: 'Купить молоко',
        TaskFields.priority: 1,
      });

      expect(uuidV7Pattern.hasMatch(id), isTrue);
      final ops = await opsOf(id);
      expect(ops.map((o) => o.field), unorderedEquals(['content', 'priority']));
      expect(ops.map((o) => o.hlc).toSet(), hasLength(1));
      final row = await dev.taskRow(id);
      expect((row?.content, row?.priority), ('Купить молоко', 1));
    },
  );

  test('update — меняет только переданные поля', () async {
    final id = await dev.services.mutator.create(EntityTypes.task, {
      TaskFields.content: 'Отчёт',
      TaskFields.priority: 4,
    });
    await dev.services.mutator.update(EntityTypes.task, id, {
      TaskFields.priority: 2,
    });

    final row = await dev.taskRow(id);
    expect((row?.content, row?.priority), ('Отчёт', 2));
  });

  test('delete → tombstone, restore → задача снова жива', () async {
    final id = await dev.services.mutator.create(EntityTypes.task, {
      TaskFields.content: 'Временная',
    });
    await dev.services.mutator.delete(EntityTypes.task, id);
    expect(await dev.aliveTasks(), isNot(contains(id)));

    await dev.services.mutator.restore(EntityTypes.task, id);
    expect(await dev.aliveTasks(), containsPair(id, 'Временная'));
  });

  group('срок (due) — слияние объекта', () {
    // Повторение появится в M5; до тех пор его ключи для этой версии
    // приложения незнакомые — как поля от более новой версии.
    const recurring = {
      'date': '2026-10-26',
      'time': '10:00',
      'string': 'каждый пн',
      'is_recurring': true,
      'rule_v2': {'freq': 'weekly', 'by_day': 'MO'},
    };

    Future<String> taskWithDue(Map<String, Object?> due) =>
        dev.services.mutator.create(EntityTypes.task, {
          TaskFields.content: 'Планёрка',
          TaskFields.due: due,
        });

    test('новый срок сохраняет незнакомые ключи и заменяет известные — '
        'дата без времени убирает время', () async {
      final id = await taskWithDue(recurring);
      await dev.services.mutator.update(EntityTypes.task, id, {
        TaskFields.due: {'date': '2026-11-02'},
      });

      expect((await dev.entity(EntityTypes.task, id))?[TaskFields.due], {
        'date': '2026-11-02',
        'string': 'каждый пн',
        'is_recurring': true,
        'rule_v2': {'freq': 'weekly', 'by_day': 'MO'},
      });
      final row = await dev.taskRow(id);
      expect((row?.dueDate, row?.dueTime), ('2026-11-02', null));
    });

    test('ключ со значением null не записывается', () async {
      final id = await taskWithDue({'date': '2026-10-26'});
      await dev.services.mutator.update(EntityTypes.task, id, {
        TaskFields.due: {'date': '2026-10-27', 'time': null},
      });

      expect((await dev.entity(EntityTypes.task, id))?[TaskFields.due], {
        'date': '2026-10-27',
      });
    });

    test('объект без ключей — срока нет', () async {
      final id = await taskWithDue({'date': '2026-10-26'});
      await dev.services.mutator.update(EntityTypes.task, id, {
        TaskFields.due: {'date': null},
      });

      expect((await dev.entity(EntityTypes.task, id))?[TaskFields.due], isNull);
    });

    test('null у поля убирает срок целиком', () async {
      final id = await taskWithDue(recurring);
      await dev.services.mutator.update(EntityTypes.task, id, {
        TaskFields.due: null,
      });

      expect((await dev.entity(EntityTypes.task, id))?[TaskFields.due], isNull);
      expect((await dev.taskRow(id))?.dueDate, isNull);
    });
  });

  test('часы движка сохраняются в local_meta вместе с правкой', () async {
    final id = await dev.services.mutator.create(EntityTypes.task, {
      TaskFields.content: 'x',
    });

    final saved = await dev.services.meta.hlc();
    expect(saved, dev.services.engine.clock);
    expect(saved, (await opsOf(id)).single.hlc);
  });

  test('ошибка в правке откатывает и ops, и часы', () async {
    final opsBefore = (await dev.services.store.allOps()).length;
    final hlcBefore = await dev.services.meta.hlc();

    await expectLater(
      dev.services.mutator.create(EntityTypes.task, {
        TaskFields.content: DateTime.utc(2026), // не JSON
      }),
      throwsA(isA<JsonUnsupportedObjectError>()),
    );

    expect(await dev.services.store.allOps(), hasLength(opsBefore));
    expect(await dev.services.meta.hlc(), hlcBefore);
  });

  test('сущность conflict напрямую не пишется — только resolveConflict', () {
    expect(
      () => dev.services.mutator.update(conflictEntityType, 'c1', {
        conflictResolvedField: true,
      }),
      throwsArgumentError,
    );
  });

  test(
    'update — поле с прежним значением op не получает, изменённое — получает',
    () async {
      final id = await dev.services.mutator.create(EntityTypes.task, {
        TaskFields.content: 'Отчёт',
        TaskFields.due: {DueKeys.date: '2026-10-30'},
      });
      final before = (await opsOf(id)).length;

      final ops = await dev.services.mutator.update(EntityTypes.task, id, {
        TaskFields.content: 'Отчёт',
        TaskFields.due: {DueKeys.date: '2026-10-30'},
        TaskFields.priority: 1,
      });

      expect(ops.map((o) => o.field), [TaskFields.priority]);
      expect(await opsOf(id), hasLength(before + 1));
    },
  );
}
