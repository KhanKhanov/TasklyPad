import 'package:flutter_test/flutter_test.dart';
import 'package:oplog_sync/oplog_sync.dart';
import 'package:planner/data/app_database.dart';
import 'package:planner/data/projection/default_registry.dart';
import 'package:planner/data/projection/entity_fields.dart';
import 'package:planner/sync/drift_op_store.dart';

import 'support/drift_probe.dart';

/// Срок как объект модели (как будет у freezed-класса): JSON через toJson.
final class _Due {
  _Due(this.date);

  final String date;

  Map<String, Object?> toJson() => {'date': date};
}

void main() {
  late AppDatabase db;
  late DriftOpStore store;
  late List<String> warnings;
  var seq = 0;

  setUp(() {
    db = memoryDatabase();
    warnings = [];
    store = DriftOpStore(db, registry: defaultRegistry(db, warn: warnings.add));
  });

  /// Записать поле напрямую в хранилище (без движка: проверяем проекцию).
  Future<void> put(String type, String id, String field, Object? value) =>
      store.writeField(
        Op(
          opId: 'op-${++seq}',
          nodeId: 'a',
          hlc: Hlc(wallMs: 1761110400000 + seq, counter: 0, nodeId: 'a'),
          entityType: type,
          entityId: id,
          field: field,
          value: value,
        ),
      );

  Future<TaskRow?> task(String id) =>
      (db.select(db.tasks)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<ProjectRow?> project(String id) =>
      (db.select(db.projects)..where((t) => t.id.equals(id))).getSingleOrNull();

  test('задача — каждое поле ложится в свою колонку', () async {
    const fields = {
      TaskFields.content: 'Купить молоко',
      TaskFields.description: '**2 литра**',
      TaskFields.projectId: 'p1',
      TaskFields.sectionId: 's1',
      TaskFields.parentId: 't0',
      TaskFields.orderKey: 'a0',
      TaskFields.priority: 1,
      TaskFields.due: {
        'date': '2026-10-24',
        'time': '09:30',
        'tz': 'Europe/Moscow',
      },
      TaskFields.isCompleted: true,
      TaskFields.completedAt: '2026-10-24T06:31:00Z',
      TaskFields.addedAt: '2026-10-23T10:00:00Z',
      TaskFields.deleted: true,
    };
    for (final entry in fields.entries) {
      await put(EntityTypes.task, 't1', entry.key, entry.value);
    }
    final row = (await task('t1'))!;
    expect(row.content, 'Купить молоко');
    expect(row.description, '**2 литра**');
    expect(row.projectId, 'p1');
    expect(row.sectionId, 's1');
    expect(row.parentId, 't0');
    expect(row.orderKey, 'a0');
    expect(row.priority, 1);
    expect(row.dueDate, '2026-10-24');
    expect(row.dueTime, '09:30');
    expect(row.dueTz, 'Europe/Moscow');
    expect(row.isCompleted, isTrue);
    expect(row.completedAt, '2026-10-24T06:31:00Z');
    expect(row.addedAt, '2026-10-23T10:00:00Z');
    expect(row.deleted, isTrue);
    expect(warnings, isEmpty);
  });

  test('проект — каждое поле ложится в свою колонку', () async {
    const fields = {
      ProjectFields.name: 'Дом',
      ProjectFields.color: 'berry_red',
      ProjectFields.parentId: 'p0',
      ProjectFields.orderKey: 'b0',
      ProjectFields.isFavorite: true,
      ProjectFields.isArchived: true,
      ProjectFields.isInbox: true,
      ProjectFields.viewStyle: 'board',
      ProjectFields.deleted: true,
    };
    for (final entry in fields.entries) {
      await put(EntityTypes.project, 'p1', entry.key, entry.value);
    }
    final row = (await project('p1'))!;
    expect(row.name, 'Дом');
    expect(row.color, 'berry_red');
    expect(row.parentId, 'p0');
    expect(row.orderKey, 'b0');
    expect(row.isFavorite, isTrue);
    expect(row.isArchived, isTrue);
    expect(row.isInbox, isTrue);
    expect(row.viewStyle, 'board');
    expect(row.deleted, isTrue);
  });

  test('правка одного поля — остальные колонки не сбрасываются', () async {
    await put(EntityTypes.task, 't1', TaskFields.content, 'Отчёт');
    await put(EntityTypes.task, 't1', TaskFields.priority, 2);
    await put(EntityTypes.task, 't1', TaskFields.content, 'Квартальный отчёт');
    final row = (await task('t1'))!;
    expect(row.content, 'Квартальный отчёт');
    expect(row.priority, 2);
  });

  test(
    'поле пришло раньше названия — строка со значениями по умолчанию',
    () async {
      await put(EntityTypes.task, 't1', TaskFields.priority, 1);
      final row = (await task('t1'))!;
      expect(row.priority, 1);
      expect(row.content, '');
      expect(row.projectId, isNull);
      expect(row.deleted, isFalse);
    },
  );

  test('значение не того типа — колонка по умолчанию, исходное значение '
      'сохранено, предупреждение', () async {
    await put(EntityTypes.task, 't1', TaskFields.priority, 'высокий');
    expect((await task('t1'))!.priority, 4);
    expect(
      await store.fieldHlc(EntityTypes.task, 't1', TaskFields.priority),
      isNotNull,
    );
    final probe = DriftProbe(db);
    expect(
      (await probe.entity(EntityTypes.task, 't1'))![TaskFields.priority],
      'высокий',
    );
    expect(warnings.single, contains('priority'));
  });

  test('приоритет 2.0 (целое в виде дробного из JSON) — 2', () async {
    await put(EntityTypes.task, 't1', TaskFields.priority, 2.0);
    expect((await task('t1'))!.priority, 2);
  });

  test(
    'срок — объект раскладывается на дату, время и зону; null очищает',
    () async {
      await put(EntityTypes.task, 't1', TaskFields.due, {
        'date': '2026-10-24',
        'is_recurring': true,
        'string': 'каждый день',
      });
      var row = (await task('t1'))!;
      expect(row.dueDate, '2026-10-24');
      expect(row.dueTime, isNull);
      expect(row.dueTz, isNull);
      final due =
          (await DriftProbe(db)
                  .entity(EntityTypes.task, 't1'))![TaskFields.due]!
              as Map<String, Object?>;
      expect(due['string'], 'каждый день', reason: 'лишние ключи сохранены');

      await put(EntityTypes.task, 't1', TaskFields.due, null);
      row = (await task('t1'))!;
      expect(row.dueDate, isNull);
    },
  );

  test('срок как Map<dynamic, dynamic> или объект с toJson — разложен так же, '
      'как при reproject', () async {
    await put(EntityTypes.task, 't1', TaskFields.due, <dynamic, dynamic>{
      'date': '2026-10-24',
    });
    await put(EntityTypes.task, 't2', TaskFields.due, _Due('2026-10-25'));
    expect((await task('t1'))!.dueDate, '2026-10-24');
    expect((await task('t2'))!.dueDate, '2026-10-25');
    expect(warnings, isEmpty);
    await DriftProbe(db).checkConsistency();
  });

  test('поле id не в белом списке — строку не переименовать', () async {
    await put(EntityTypes.task, 't1', 'id', 'чужой');
    expect(await task('t1'), isNull);
    expect(await task('чужой'), isNull);
  });

  test(
    'неизвестное поле — строка не создаётся, значение в field_versions',
    () async {
      await put(EntityTypes.task, 't1', 'deadline', '2026-11-01');
      expect(await task('t1'), isNull);
      expect(await DriftProbe(db).entity(EntityTypes.task, 't1'), {
        'deadline': '2026-11-01',
      });
    },
  );

  test('неизвестный тип — таблицы сущностей не трогает', () async {
    await put('section', 's1', 'name', 'Покупки');
    expect(await db.select(db.tasks).get(), isEmpty);
    expect(await db.select(db.projects).get(), isEmpty);
  });

  test('каждая колонка tasks и projects (кроме id) пишется каким-то полем', () {
    for (final projector in defaultRegistry(db).all) {
      final written = {
        for (final field in projector.fields) ...projector.columnsOf(field),
      };
      final columns = {
        for (final column in projector.table.$columns) column.name,
      }..remove('id');
      expect(written, columns, reason: projector.entityType);
    }
  });
}
