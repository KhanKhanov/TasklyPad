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
import 'generated/schema_v3.dart' as v3;
import 'generated/schema_v4.dart' as v4;
import 'generated/schema_v5.dart' as v5;

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
        from2To3: (m, s) async {},
        from3To4: (m, s) async {},
        from4To5: (m, s) async {},
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

  test('v2 → v3 — строки v2 целы, колонки правила пустые, записей выполнения '
      'нет', () {
    const task = v2.TasksData(
      id: 't1',
      content: 'Зарядка',
      description: '',
      projectId: 'p1',
      orderKey: 'a0',
      priority: 4,
      dueDate: '2026-10-30',
      dueTime: '07:00',
      dueTz: 'Europe/Moscow',
      deadlineDate: '2026-11-01',
      durationAmount: 30,
      durationUnit: 'minute',
      isCollapsed: 0,
      isCompleted: 0,
      addedAt: '2026-10-24T09:00:00.000Z',
      deleted: 0,
    );
    const op = v2.OpsData(
      opId: 'o1',
      nodeId: 'a',
      hlc: '0001761300000000-0000-a',
      entityType: 'task',
      entityId: 't1',
      field: 'content',
      valueJson: '"Зарядка"',
    );
    return verifier.testWithDataIntegrity(
      oldVersion: 2,
      newVersion: 3,
      createOld: v2.DatabaseAtV2.new,
      createNew: v3.DatabaseAtV3.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, oldDb) {
        batch.insert(oldDb.tasks, task);
        batch.insert(oldDb.ops, op);
      },
      validateItems: (newDb) async {
        expect(await newDb.select(newDb.tasks).get(), [
          const v3.TasksData(
            id: 't1',
            content: 'Зарядка',
            description: '',
            projectId: 'p1',
            orderKey: 'a0',
            priority: 4,
            dueDate: '2026-10-30',
            dueTime: '07:00',
            dueTz: 'Europe/Moscow',
            dueIsRecurring: 0,
            deadlineDate: '2026-11-01',
            durationAmount: 30,
            durationUnit: 'minute',
            isCollapsed: 0,
            isCompleted: 0,
            addedAt: '2026-10-24T09:00:00.000Z',
            deleted: 0,
          ),
        ]);
        expect(await newDb.select(newDb.ops).get(), [
          const v3.OpsData(
            opId: 'o1',
            nodeId: 'a',
            hlc: '0001761300000000-0000-a',
            entityType: 'task',
            entityId: 't1',
            field: 'content',
            valueJson: '"Зарядка"',
          ),
        ]);
        expect(await newDb.select(newDb.completions).get(), isEmpty);
      },
    );
  });

  test('v2 → v3 — правило в сроке и выполнения, пришедшие до обновления, '
      'после reproject в новых колонках и таблице', () async {
    // Сборка M2 уже приняла ops сборки M3: правило лежит незнакомым ключом
    // срока, выполнение — сущностью без таблицы, обе — в field_versions.
    final hlc = const Hlc(wallMs: 1761300000000, counter: 0, nodeId: 'b');
    final schema = await verifier.schemaAt(2);
    final old = v2.DatabaseAtV2(schema.newConnection());
    await old.batch((batch) {
      batch.insertAll(old.fieldVersions, [
        v2.FieldVersionsData(
          entityType: 'task',
          entityId: 't1',
          field: 'due',
          hlc: '$hlc',
          valueJson:
              '{"date":"2026-10-30","string":"каждый день","lang":"ru",'
              '"rule":{"rrule":["FREQ=DAILY"],"from_completion":false}}',
        ),
        v2.FieldVersionsData(
          entityType: 'completion',
          entityId: 'c1',
          field: 'task_id',
          hlc: '$hlc',
          valueJson: '"t1"',
        ),
      ]);
      batch.insert(
        old.localMeta,
        const v2.LocalMetaData(key: 'projector_version', value: '2'),
      );
    });
    await old.close();

    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    final store = DriftOpStore(db);
    expect(await store.needsReproject(), isTrue);
    await store.reproject();

    final task = await db.select(db.tasks).getSingle();
    expect(
      (task.dueDate, task.dueString, task.dueLang),
      ('2026-10-30', 'каждый день', 'ru'),
    );
    expect(task.dueIsRecurring, isTrue);
    final completion = await db.select(db.completions).getSingle();
    expect((completion.id, completion.taskId), ('c1', 't1'));
  });

  test('v2 → v3 — сбой посередине откатывает миграцию целиком, повтор '
      'проходит', () async {
    final schema = await verifier.schemaAt(2);
    final failing = AppDatabase(
      schema.newConnection(),
      migrationSteps: migrationSteps(
        from1To2: (m, s) async {},
        from2To3: (m, s) async {
          await m.addColumn(s.tasks, s.tasks.dueString);
          await m.createTable(s.completions);
          throw StateError('сбой посреди миграции');
        },
        from3To4: (m, s) async {},
        from4To5: (m, s) async {},
      ),
    );
    await expectLater(
      failing.customSelect('SELECT 1').get(),
      throwsA(isA<StateError>()),
    );
    await failing.close();

    final raw = schema.rawDatabase;
    expect(raw.select('PRAGMA user_version').single.values.single, 2);
    final columns = raw
        .select('PRAGMA table_info(tasks)')
        .map((row) => row['name'])
        .toList();
    expect(columns, isNot(contains('due_string')));
    final tables = raw
        .select("SELECT name FROM sqlite_master WHERE type = 'table'")
        .map((row) => row['name'])
        .toList();
    expect(tables, isNot(contains('completions')));

    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 3);
    await db.close();
  });

  test('v3 → v4 — строки v3 целы, время серии пустое', () {
    const task = v3.TasksData(
      id: 't1',
      content: 'Зарядка',
      description: '',
      projectId: 'p1',
      orderKey: 'a0',
      priority: 4,
      dueDate: '2026-10-30',
      dueTime: '07:00',
      dueString: 'каждый день в 7',
      dueLang: 'ru',
      dueRule: '{"rrule":["FREQ=DAILY"],"from_completion":false}',
      dueIsRecurring: 1,
      isCollapsed: 0,
      isCompleted: 0,
      addedAt: '2026-10-24T09:00:00.000Z',
      deleted: 0,
    );
    return verifier.testWithDataIntegrity(
      oldVersion: 3,
      newVersion: 4,
      createOld: v3.DatabaseAtV3.new,
      createNew: v4.DatabaseAtV4.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, oldDb) => batch.insert(oldDb.tasks, task),
      validateItems: (newDb) async {
        expect(await newDb.select(newDb.tasks).get(), [
          const v4.TasksData(
            id: 't1',
            content: 'Зарядка',
            description: '',
            projectId: 'p1',
            orderKey: 'a0',
            priority: 4,
            dueDate: '2026-10-30',
            dueTime: '07:00',
            dueString: 'каждый день в 7',
            dueLang: 'ru',
            dueRule: '{"rrule":["FREQ=DAILY"],"from_completion":false}',
            dueIsRecurring: 1,
            isCollapsed: 0,
            isCompleted: 0,
            addedAt: '2026-10-24T09:00:00.000Z',
            deleted: 0,
          ),
        ]);
      },
    );
  });

  test('v3 → v4 — время серии, пришедшее до обновления, после reproject в '
      'новой колонке', () async {
    // Сборка до О-65 уже приняла срок сборки после: `series_time` лежит
    // незнакомым ключом срока в field_versions.
    final hlc = const Hlc(wallMs: 1761300000000, counter: 0, nodeId: 'b');
    final schema = await verifier.schemaAt(3);
    final old = v3.DatabaseAtV3(schema.newConnection());
    await old.batch((batch) {
      batch.insert(
        old.fieldVersions,
        v3.FieldVersionsData(
          entityType: 'task',
          entityId: 't1',
          field: 'due',
          hlc: '$hlc',
          valueJson:
              '{"date":"2026-10-30","time":"10:00","series_time":"07:00",'
              '"rule":{"rrule":["FREQ=DAILY"],"from_completion":false}}',
        ),
      );
      batch.insert(
        old.localMeta,
        const v3.LocalMetaData(key: 'projector_version', value: '3'),
      );
    });
    await old.close();

    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    final store = DriftOpStore(db);
    expect(await store.needsReproject(), isTrue);
    await store.reproject();

    final task = await db.select(db.tasks).getSingle();
    expect((task.dueTime, task.dueSeriesTime), ('10:00', '07:00'));
  });

  test('v3 → v4 — сбой посередине откатывает миграцию целиком, повтор '
      'проходит', () async {
    final schema = await verifier.schemaAt(3);
    final failing = AppDatabase(
      schema.newConnection(),
      migrationSteps: migrationSteps(
        from1To2: (m, s) async {},
        from2To3: (m, s) async {},
        from3To4: (m, s) async {
          await m.addColumn(s.tasks, s.tasks.dueSeriesTime);
          throw StateError('сбой посреди миграции');
        },
        from4To5: (m, s) async {},
      ),
    );
    await expectLater(
      failing.customSelect('SELECT 1').get(),
      throwsA(isA<StateError>()),
    );
    await failing.close();

    final raw = schema.rawDatabase;
    expect(raw.select('PRAGMA user_version').single.values.single, 3);
    final columns = raw
        .select('PRAGMA table_info(tasks)')
        .map((row) => row['name'])
        .toList();
    expect(columns, isNot(contains('due_series_time')));

    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 4);
    await db.close();
  });

  test('v4 → v5 — строки v4 целы, описание и порядок дня пустые, снимка '
      'меток и настроек вида нет', () {
    const project = v4.ProjectsData(
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
    );
    const task = v4.TasksData(
      id: 't1',
      content: 'Зарядка',
      description: 'утром',
      projectId: 'p1',
      orderKey: 'a0',
      priority: 2,
      dueDate: '2026-10-30',
      dueTime: '10:00',
      dueString: 'каждый день в 7',
      dueLang: 'ru',
      dueRule: '{"rrule":["FREQ=DAILY"],"from_completion":false}',
      dueIsRecurring: 1,
      dueSeriesTime: '07:00',
      isCollapsed: 0,
      isCompleted: 0,
      addedAt: '2026-10-24T09:00:00.000Z',
      deleted: 0,
    );
    const label = v4.LabelsData(
      id: 'l1',
      name: 'дом',
      color: 'blue',
      orderKey: 'a0',
      isFavorite: 0,
      deleted: 0,
    );
    const link = v4.TaskLabelsData(
      id: 'tl1',
      taskId: 't1',
      labelId: 'l1',
      deleted: 0,
    );
    return verifier.testWithDataIntegrity(
      oldVersion: 4,
      newVersion: 5,
      createOld: v4.DatabaseAtV4.new,
      createNew: v5.DatabaseAtV5.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, oldDb) {
        batch.insert(oldDb.projects, project);
        batch.insert(oldDb.tasks, task);
        batch.insert(oldDb.labels, label);
        batch.insert(oldDb.taskLabels, link);
      },
      validateItems: (newDb) async {
        expect(await newDb.select(newDb.projects).get(), [
          const v5.ProjectsData(
            id: 'p1',
            name: 'Работа',
            description: '',
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
          const v5.TasksData(
            id: 't1',
            content: 'Зарядка',
            description: 'утром',
            projectId: 'p1',
            orderKey: 'a0',
            dayOrderKey: '',
            priority: 2,
            dueDate: '2026-10-30',
            dueTime: '10:00',
            dueString: 'каждый день в 7',
            dueLang: 'ru',
            dueRule: '{"rrule":["FREQ=DAILY"],"from_completion":false}',
            dueIsRecurring: 1,
            dueSeriesTime: '07:00',
            isCollapsed: 0,
            isCompleted: 0,
            addedAt: '2026-10-24T09:00:00.000Z',
            deleted: 0,
          ),
        ]);
        expect(await newDb.select(newDb.labels).get(), [
          const v5.LabelsData(
            id: 'l1',
            name: 'дом',
            color: 'blue',
            orderKey: 'a0',
            isFavorite: 0,
            deleted: 0,
          ),
        ]);
        expect(await newDb.select(newDb.taskLabels).get(), [
          const v5.TaskLabelsData(
            id: 'tl1',
            taskId: 't1',
            labelId: 'l1',
            deleted: 0,
          ),
        ]);
        expect(await newDb.select(newDb.viewOptions).get(), isEmpty);
      },
    );
  });

  test(
    'v4 → v5 — описание, порядок дня, снимок меток и настройки вида, '
    'пришедшие до обновления, после reproject в новых колонках и таблице',
    () async {
      // Сборка M3 уже приняла ops сборки M4: новые поля и сущность лежат в
      // field_versions, колонок и таблицы для них ещё не было.
      final hlc = const Hlc(wallMs: 1761300000000, counter: 0, nodeId: 'b');
      final schema = await verifier.schemaAt(4);
      final old = v4.DatabaseAtV4(schema.newConnection());
      v4.FieldVersionsData version(
        String type,
        String id,
        String field,
        String json,
      ) => v4.FieldVersionsData(
        entityType: type,
        entityId: id,
        field: field,
        hlc: '$hlc',
        valueJson: json,
      );
      await old.batch((batch) {
        batch.insertAll(old.fieldVersions, [
          version('project', 'p1', 'description', '"Квартальный план"'),
          version('task', 't1', 'day_order_key', '"a1"'),
          version('task', 't1', 'completed_label_names', '{"l1":"дом"}'),
          version('view_options', 'v1', 'view_type', '"project"'),
          version('view_options', 'v1', 'object_id', '"p1"'),
          version('view_options', 'v1', 'grouped_by', '"priority"'),
        ]);
        batch.insert(
          old.localMeta,
          const v4.LocalMetaData(key: 'projector_version', value: '4'),
        );
      });
      await old.close();

      final db = AppDatabase(schema.newConnection());
      addTearDown(db.close);
      final store = DriftOpStore(db);
      expect(await store.needsReproject(), isTrue);
      await store.reproject();

      final project = await db.select(db.projects).getSingle();
      expect(project.description, 'Квартальный план');
      final task = await db.select(db.tasks).getSingle();
      expect(
        (task.dayOrderKey, task.completedLabelNames),
        ('a1', '{"l1":"дом"}'),
      );
      final view = await db.select(db.viewOptions).getSingle();
      expect(
        (view.id, view.viewType, view.objectId, view.groupedBy),
        ('v1', 'project', 'p1', 'priority'),
      );
    },
  );

  test('v4 → v5 — сбой посередине откатывает миграцию целиком, повтор '
      'проходит', () async {
    final schema = await verifier.schemaAt(4);
    final failing = AppDatabase(
      schema.newConnection(),
      migrationSteps: migrationSteps(
        from1To2: (m, s) async {},
        from2To3: (m, s) async {},
        from3To4: (m, s) async {},
        from4To5: (m, s) async {
          await m.addColumn(s.projects, s.projects.description);
          await m.createTable(s.viewOptions);
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
    expect(raw.select('PRAGMA user_version').single.values.single, 4);
    final columns = raw
        .select('PRAGMA table_info(projects)')
        .map((row) => row['name'])
        .toList();
    expect(columns, isNot(contains('description')));
    final tables = raw
        .select("SELECT name FROM sqlite_master WHERE type = 'table'")
        .map((row) => row['name'])
        .toList();
    expect(tables, isNot(contains('view_options')));

    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 5);
    await db.close();
  });
}
