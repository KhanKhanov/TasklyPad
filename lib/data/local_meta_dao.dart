import 'package:oplog_sync/oplog_sync.dart';

import 'app_database.dart';

/// Типизированный доступ к `local_meta` — локальным настройкам устройства.
///
/// Ничего отсюда не синхронизируется: у каждого устройства свой id узла,
/// свои часы и своё состояние папки синхронизации.
final class LocalMetaDao {
  LocalMetaDao(this._db);

  final AppDatabase _db;

  static const String nodeIdKey = 'node_id';
  static const String hlcKey = 'hlc';
  static const String projectorVersionKey = 'projector_version';
  static const String folderIdKey = 'sync.folder_id';
  static const String uploadedUpToKey = 'sync.uploaded_up_to';

  Future<String?> read(String key) async {
    final row = await (_db.select(
      _db.localMeta,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> write(String key, String value) => _db
      .into(_db.localMeta)
      .insertOnConflictUpdate(
        LocalMetaCompanion.insert(key: key, value: value),
      );

  Future<void> remove(String key) =>
      (_db.delete(_db.localMeta)..where((t) => t.key.equals(key))).go();

  /// Id этого устройства в журнале (заполняется при первом запуске, M1.4).
  Future<String?> nodeId() => read(nodeIdKey);

  Future<void> setNodeId(String value) => write(nodeIdKey, value);

  /// Сохранённое состояние часов движка.
  Future<Hlc?> hlc() async => _parseHlc(await read(hlcKey));

  Future<void> setHlc(Hlc value) => write(hlcKey, value.toString());

  /// Версия реестра проекторов, которой разложены таблицы сущностей.
  Future<int?> projectorVersion() async =>
      int.tryParse(await read(projectorVersionKey) ?? '');

  Future<void> setProjectorVersion(int value) =>
      write(projectorVersionKey, value.toString());

  Future<String?> folderId() => read(folderIdKey);

  Future<void> setFolderId(String value) => write(folderIdKey, value);

  Future<Hlc?> uploadedUpTo() async => _parseHlc(await read(uploadedUpToKey));

  Future<void> setUploadedUpTo(Hlc value) =>
      write(uploadedUpToKey, value.toString());

  Future<void> removeUploadedUpTo() => remove(uploadedUpToKey);

  static Hlc? _parseHlc(String? text) => text == null ? null : Hlc.parse(text);
}
