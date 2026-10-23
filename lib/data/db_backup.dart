import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/common.dart';

/// Копий перед миграцией хранится столько; старые удаляются.
const int backupsToKeep = 14;

/// Префикс имени копии; за ним — UTC-время, поэтому имена сортируются по дате.
const String backupPrefix = 'pre-migration-';

/// Схема базы новее, чем знает приложение: старая версия не должна её трогать.
final class SchemaTooNewException implements Exception {
  SchemaTooNewException(this.found, this.supported);

  final int found;
  final int supported;

  @override
  String toString() =>
      'SchemaTooNewException: база версии $found, приложение знает до '
      '$supported — обновите приложение';
}

/// Папка с копиями базы. Методы синхронные: вызываются из `setup` drift
/// в фоновом изоляте, до миграций.
abstract interface class BackupStore {
  /// Имена файлов копий (только [backupPrefix]…).
  List<String> list();

  /// Целостная копия открытой базы [db] в файл [name].
  void writeCopy(CommonDatabase db, String name);

  void delete(String name);
}

/// Проверка версии схемы и копия базы перед миграцией.
///
/// Вызывается сразу после открытия файла, до миграций drift:
/// новая база (версия 0) и актуальная — без копии; старая — копия и ротация;
/// новее приложения — [SchemaTooNewException]. Сбой копии пробрасывается, и
/// база не открывается: без копии не мигрируем.
///
/// Ротация оставляет [backupsToKeep] новейших копий и, сверх них, новейшую
/// копию каждой версии схемы: если миграция падает при каждом запуске, копии
/// перед прошлыми миграциями не вытесняются копиями этой.
void prepareForOpen(
  CommonDatabase db, {
  required int targetVersion,
  required BackupStore backups,
  required DateTime nowUtc,
}) {
  final version = db.userVersion;
  if (version > targetVersion) {
    throw SchemaTooNewException(version, targetVersion);
  }
  if (version == 0 || version == targetVersion) return;

  backups.writeCopy(db, '$backupPrefix${_stamp(nowUtc)}-v$version.sqlite');

  final names = backups.list()..sort();
  final keep = names.reversed.take(backupsToKeep).toSet();
  final newestOfVersion = <String, String>{};
  for (final name in names) {
    final v = _versionPattern.firstMatch(name)?.group(1);
    if (v != null) newestOfVersion[v] = name; // имена по возрастанию времени
  }
  keep.addAll(newestOfVersion.values);
  for (final name in names) {
    if (!keep.contains(name)) backups.delete(name);
  }
}

final RegExp _versionPattern = RegExp(r'-v(\d+)\.sqlite$');

/// `20261023T101530123Z` (с миллисекундами) — сортируется как время;
/// `VACUUM INTO` не перезаписывает файл, поэтому имена не должны совпадать
/// даже при двух открытиях подряд.
String _stamp(DateTime t) {
  final u = t.toUtc();
  String pad(int v, [int width = 2]) => v.toString().padLeft(width, '0');
  return '${pad(u.year, 4)}${pad(u.month)}${pad(u.day)}'
      'T${pad(u.hour)}${pad(u.minute)}${pad(u.second)}${pad(u.millisecond, 3)}Z';
}

/// Функция `setup` для drift: [prepareForOpen] с копиями в [backupsDirectory].
///
/// Верхнеуровневая фабрика, а не замыкание внутри `openAppDatabase`:
/// `setup` отправляется в фоновый изолят, и замыкание должно захватывать
/// только строки, числа и время, а не случайно — часы, провайдеры или базу.
void Function(CommonDatabase db) backupBeforeMigration({
  required String backupsDirectory,
  required int targetVersion,
  required DateTime nowUtc,
}) =>
    (db) => prepareForOpen(
      db,
      targetVersion: targetVersion,
      backups: IoBackupStore(backupsDirectory),
      nowUtc: nowUtc,
    );

/// Копии в папке на диске; копия делается `VACUUM INTO`, а не копированием
/// файла: при журнале WAL файл базы без `-wal`/`-shm` может быть несогласован.
final class IoBackupStore implements BackupStore {
  IoBackupStore(this.directory);

  final String directory;

  @override
  List<String> list() {
    final dir = Directory(directory);
    if (!dir.existsSync()) return const [];
    return [
      for (final entity in dir.listSync())
        if (entity is File)
          if (p.basename(entity.path) case final name
              when name.startsWith(backupPrefix) && name.endsWith('.sqlite'))
            name,
    ];
  }

  @override
  void writeCopy(CommonDatabase db, String name) {
    Directory(directory).createSync(recursive: true);
    db.execute('VACUUM INTO ?', [p.join(directory, name)]);
  }

  @override
  void delete(String name) => File(p.join(directory, name)).deleteSync();
}
