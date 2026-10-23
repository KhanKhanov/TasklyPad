import 'package:drift_flutter/drift_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/clock.dart';
import 'app_database.dart';
import 'db_backup.dart';

/// Открыть базу приложения.
///
/// Файл лежит в папке данных приложения (на Windows — AppData), а не в
/// «Документах», как по умолчанию у drift_flutter: «Документы» часто
/// синхронизирует OneDrive, а живой файл SQLite под облачным клиентом может
/// испортиться. Копии перед миграцией — в подпапке `backups`.
Future<AppDatabase> openAppDatabase({
  AppClock clock = const SystemClock(),
}) async {
  final directory = (await getApplicationSupportDirectory()).path;
  return AppDatabase(
    driftDatabase(
      name: 'planner',
      native: DriftNativeOptions(
        databaseDirectory: () async => directory,
        setup: backupBeforeMigration(
          backupsDirectory: p.join(directory, 'backups'),
          targetVersion: AppDatabase.currentSchemaVersion,
          nowUtc: clock.nowUtc(),
        ),
      ),
    ),
  );
}
