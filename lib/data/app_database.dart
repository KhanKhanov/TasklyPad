import 'package:drift/drift.dart';
import 'package:drift/internal/versioned_schema.dart';
import 'package:meta/meta.dart' show visibleForTesting;

import 'app_database.steps.dart';
import 'tables/entity_tables.dart';
import 'tables/sync_tables.dart';

part 'app_database.g.dart';

/// База приложения: журнал ops, его проекции и локальное состояние синхронизации.
///
/// Открывается через `openAppDatabase` (lib/data/db_open.dart); в тестах —
/// `AppDatabase(NativeDatabase.memory())`.
@DriftDatabase(
  tables: [
    Ops,
    FieldVersions,
    Conflicts,
    SyncCursors,
    LocalMeta,
    Projects,
    Tasks,
    Sections,
    Labels,
    TaskLabels,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// [migrationSteps] — подмена шагов миграции в тесте (например, шаг с
  /// ошибкой посередине, чтобы проверить откат).
  AppDatabase(
    super.executor, {
    @visibleForTesting MigrationStepWithVersion? migrationSteps,
  }) : _migrationSteps = migrationSteps ?? _steps;

  final MigrationStepWithVersion _migrationSteps;

  /// Версия схемы. При изменении таблиц: увеличить, выполнить
  /// `dart run drift_dev make-migrations` и описать шаг в [migration].
  static const int currentSchemaVersion = 2;

  @override
  int get schemaVersion => currentSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    // Шаги по версиям: каждый работает со снимком своей схемы (drift_schemas/),
    // а не с текущими классами таблиц, поэтому не ломается от будущих правок.
    // Перед любой миграцией база уже скопирована (lib/data/db_backup.dart).
    //
    // drift сам транзакцию не открывает и пишет версию схемы уже после шагов:
    // оборванная посередине миграция оставила бы версию 1 с частью колонок, и
    // повтор упал бы на «duplicate column». Поэтому шаги и `user_version` — в
    // одной транзакции (версия в заголовке SQLite меняется транзакционно):
    // база либо целиком в старой схеме, либо целиком в новой.
    onUpgrade: (m, from, to) => transaction(() async {
      await VersionedSchema.runMigrationSteps(
        migrator: m,
        from: from,
        to: to,
        steps: _migrationSteps,
      );
      await customStatement('PRAGMA user_version = $to');
    }),
  );

  static final MigrationStepWithVersion _steps = migrationSteps(
    // M2: разделы, метки, метки задач; дедлайн, длительность, свёрнутость.
    from1To2: (m, schema) async {
      await m.addColumn(schema.projects, schema.projects.isCollapsed);
      await m.addColumn(schema.tasks, schema.tasks.deadlineDate);
      await m.addColumn(schema.tasks, schema.tasks.durationAmount);
      await m.addColumn(schema.tasks, schema.tasks.durationUnit);
      await m.addColumn(schema.tasks, schema.tasks.isCollapsed);
      await m.createIndex(schema.tasksByParent);
      await m.createTable(schema.sections);
      await m.createIndex(schema.sectionsByProject);
      await m.createTable(schema.labels);
      await m.createTable(schema.taskLabels);
      await m.createIndex(schema.taskLabelsByTask);
      await m.createIndex(schema.taskLabelsByLabel);
    },
  );
}
