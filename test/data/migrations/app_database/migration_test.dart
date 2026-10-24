import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oplog_sync/oplog_sync.dart';
import 'package:planner/data/app_database.dart';
import 'package:planner/data/app_database.steps.dart';
import 'package:planner/sync/drift_op_store.dart';

import 'generated/schema.dart';
import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;

// Снимки схем — drift_schemas/, классы generated/ — из
// `dart run drift_dev make-migrations`. При новой версии схемы: снимок,
// шаг в AppDatabase и проверка данных здесь.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  group('схема после миграции совпадает со снимком', () {
    const versions = GeneratedHelper.versions;
    for (final (i, from) in versions.indexed) {
      for (final to in versions.skip(i + 1)) {
        test('v$from → v$to', () async {
          final schema = await verifier.schemaAt(from);
          final db = AppDatabase(schema.newConnection());
          await verifier.migrateAndValidate(db, to);
          await db.close();
        });
      }
    }
  });

  test(
    'v1 → v2 — строки v1 целы, новые колонки со значениями по умолчанию',
    () {
      const project = v1.ProjectsData(
        id: 'p1',
        name: 'Работа',
        color: 'red',
        orderKey: 'a0',
        isFavorite: 1,
        isArchived: 0,
        isInbox: 0,
        viewStyle: 'board',
        deleted: 0,
      );
      const task = v1.TasksData(
        id: 't1',
        content: 'Отчёт',
        description: 'до пятницы',
        projectId: 'p1',
        orderKey: 'a0',
        priority: 2,
        dueDate: '2026-10-30',
        dueTime: '10:00',
        dueTz: 'Europe/Moscow',
        isCompleted: 0,
        addedAt: '2026-10-24T09:00:00.000Z',
        deleted: 0,
      );
      const op = v1.OpsData(
        opId: 'o1',
        nodeId: 'a',
        hlc: '0001761300000000-0000-a',
        entityType: 'task',
        entityId: 't1',
        field: 'content',
        valueJson: '"Отчёт"',
      );
      return verifier.testWithDataIntegrity(
        oldVersion: 1,
        newVersion: 2,
        createOld: v1.DatabaseAtV1.new,
        createNew: v2.DatabaseAtV2.new,
        openTestedDatabase: AppDatabase.new,
        createItems: (batch, oldDb) {
          batch.insert(oldDb.projects, project);
          batch.insert(oldDb.tasks, task);
          batch.insert(oldDb.ops, op);
        },
        validateItems: (newDb) async {
          expect(await newDb.select(newDb.projects).get(), [
            const v2.ProjectsData(
              id: 'p1',
              name: 'Работа',
              color: 'red',
              orderKey: 'a0',
              isFavorite: 1,
              isArchived: 0,
              isInbox: 0,
              viewStyle: 'board',
              isCollapsed: 0,
              deleted: 0,
            ),
          ]);
          expect(await newDb.select(newDb.tasks).get(), [
            const v2.TasksData(
              id: 't1',
              content: 'Отчёт',
              description: 'до пятницы',
              projectId: 'p1',
              orderKey: 'a0',
              priority: 2,
              dueDate: '2026-10-30',
              dueTime: '10:00',
              dueTz: 'Europe/Moscow',
              isCollapsed: 0,
              isCompleted: 0,
              addedAt: '2026-10-24T09:00:00.000Z',
              deleted: 0,
            ),
          ]);
          expect(await newDb.select(newDb.ops).get(), [
            const v2.OpsData(
              opId: 'o1',
              nodeId: 'a',
              hlc: '0001761300000000-0000-a',
              entityType: 'task',
              entityId: 't1',
              field: 'content',
              valueJson: '"Отчёт"',
            ),
          ]);
          expect(await newDb.select(newDb.sections).get(), isEmpty);
          expect(await newDb.select(newDb.labels).get(), isEmpty);
          expect(await newDb.select(newDb.taskLabels).get(), isEmpty);
        },
      );
    },
  );

  test('v1 → v2 — разделы и метки, пришедшие до обновления, после reproject '
      'попадают в новые таблицы', () async {
    // Старое приложение уже приняло ops нового устройства: они лежат в
    // field_versions, а таблиц для них ещё не было.
    final hlc = const Hlc(wallMs: 1761300000000, counter: 0, nodeId: 'b');
    final schema = await verifier.schemaAt(1);
    final old = v1.DatabaseAtV1(schema.newConnection());
    await old.batch((batch) {
      batch.insertAll(old.fieldVersions, [
        v1.FieldVersionsData(
          entityType: 'section',
          entityId: 's1',
          field: 'name',
          hlc: '$hlc',
          valueJson: '"Вечер"',
        ),
        v1.FieldVersionsData(
          entityType: 'label',
          entityId: 'l1',
          field: 'name',
          hlc: '$hlc',
          valueJson: '"дом"',
        ),
      ]);
      batch.insert(
        old.localMeta,
        const v1.LocalMetaData(key: 'projector_version', value: '1'),
      );
    });
    await old.close();

    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    final store = DriftOpStore(db);
    expect(await store.needsReproject(), isTrue);
    await store.reproject();

    final section = await db.select(db.sections).getSingle();
    expect((section.id, section.name), ('s1', 'Вечер'));
    final label = await db.select(db.labels).getSingle();
    expect((label.id, label.name), ('l1', 'дом'));
  });

  test('v1 → v2 — сбой посередине откатывает миграцию целиком, повтор '
      'проходит', () async {
    final schema = await verifier.schemaAt(1);
    final failing = AppDatabase(
      schema.newConnection(),
      migrationSteps: migrationSteps(
        from1To2: (m, s) async {
          await m.addColumn(s.tasks, s.tasks.deadlineDate);
          throw StateError('сбой посреди миграции');
        },
      ),
    );
    await expectLater(
      failing.customSelect('SELECT 1').get(),
      throwsA(isA<StateError>()),
    );
    await failing.close();

    final raw = schema.rawDatabase;
    expect(raw.select('PRAGMA user_version').single.values.single, 1);
    final columns = raw
        .select('PRAGMA table_info(tasks)')
        .map((row) => row['name'])
        .toList();
    expect(columns, isNot(contains('deadline_date')));

    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 2);
    await db.close();
  });
}
