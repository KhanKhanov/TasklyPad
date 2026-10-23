import 'package:drift/drift.dart';

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
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// Версия схемы. При изменении таблиц: увеличить, выполнить
  /// `dart run drift_dev make-migrations` и описать шаг в [migration].
  static const int currentSchemaVersion = 1;

  @override
  int get schemaVersion => currentSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // Шаги появятся с версией 2 (stepByStep из make-migrations). Перед любой
      // миграцией база уже скопирована (lib/data/db_backup.dart).
      throw StateError('Нет шага миграции схемы $from → $to');
    },
  );
}
