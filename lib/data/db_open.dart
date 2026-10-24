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
///
/// [directory] — другая папка (тест на настоящей платформе). Файл открывается
/// при первом запросе, в фоновом изоляте: ошибка проверки версии схемы
/// придёт обёрнутой в `DriftRemoteException` (см. `bootstrap`).
Future<AppDatabase> openAppDatabase({
  AppClock clock = const SystemClock(),
  String? directory,
}) async {
  final dir = directory ?? (await getApplicationSupportDirectory()).path;
  return AppDatabase(
    driftDatabase(
      name: 'planner',
      native: DriftNativeOptions(
        databaseDirectory: () async => dir,
        setup: backupBeforeMigration(
          backupsDirectory: p.join(dir, 'backups'),
          targetVersion: AppDatabase.currentSchemaVersion,
          nowUtc: clock.nowUtc(),
        ),
      ),
    ),
  );
}
