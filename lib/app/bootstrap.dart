import 'dart:io';

// DriftRemoteException — единственный способ получить ошибку из фонового
// изолята drift; библиотека помечена экспериментальной, но класс стабилен
// с drift 2.0.
// ignore: experimental_member_use
import 'package:drift/remote.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/clock.dart';
import '../core/ids.dart';
import '../data/db_backup.dart';
import '../data/db_open.dart';
import '../sync/node_identity.dart';
import '../sync/sync_services.dart';

/// Открыть базу и запустить ядро данных — до первого кадра приложения.
///
/// [dataDirectory] и [markerDirectory] — другие папки для теста на настоящей
/// платформе, чтобы не трогать базу пользователя.
///
/// Бросает [SchemaTooNewException], если база создана более новой версией
/// приложения: drift проверяет версию в фоновом изоляте и присылает ошибку
/// обёрнутой в [DriftRemoteException] — здесь она разворачивается.
Future<SyncServices> bootstrap({
  AppClock clock = const SystemClock(),
  String? dataDirectory,
  String? markerDirectory,
}) async {
  final dataDir =
      dataDirectory ?? (await getApplicationSupportDirectory()).path;
  final markerDir = markerDirectory ?? await nodeMarkerDirectory(dataDir);
  final db = await openAppDatabase(clock: clock, directory: dataDir);
  try {
    return await startSync(
      db,
      clock: clock,
      ids: IdGenerator(),
      marker: FileNodeMarker(p.join(markerDir, 'node_id.txt')),
    );
  } catch (error) {
    try {
      await db.close();
    } on Object {
      // База и так не открылась — важнее исходная ошибка.
    }
    if (error case DriftRemoteException(
      remoteCause: final SchemaTooNewException cause,
    )) {
      throw cause;
    }
    rethrow;
  }
}

/// Папка метки узла — там, куда копия базы не попадает вместе с ней.
///
/// Windows: Local AppData (база лежит в Roaming, которую переносят и копируют
/// целиком). Android: `no_backup` рядом с `files` — `Context.getNoBackupFilesDir()`,
/// её система не включает в резервные копии. Остальные платформы — папка базы
/// (опознания копий нет).
Future<String> nodeMarkerDirectory(String dataDirectory) async {
  if (Platform.isWindows) return (await getApplicationCacheDirectory()).path;
  if (Platform.isAndroid) return p.join(p.dirname(dataDirectory), 'no_backup');
  return dataDirectory;
}
