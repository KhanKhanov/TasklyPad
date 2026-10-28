import 'dart:convert';

import 'package:logger/logger.dart';
import 'package:oplog_sync/oplog_sync.dart';

import 'app_database.dart';

/// Типизированный доступ к `local_meta` — локальным настройкам устройства.
///
/// Ничего отсюда не синхронизируется: у каждого устройства свой id узла,
/// свои часы и своё состояние папки синхронизации.
final class LocalMetaDao {
  LocalMetaDao(this._db);

  final AppDatabase _db;

  static final Logger _log = Logger();

  static const String nodeIdKey = 'node_id';
  static const String hlcKey = 'hlc';
  static const String projectorVersionKey = 'projector_version';
  static const String folderIdKey = 'sync.folder_id';
  static const String uploadedUpToKey = 'sync.uploaded_up_to';
  static const String syncLeaseKey = 'sync.lease';
  static const String folderPathKey = 'sync.folder_path';
  static const String lastSyncKey = 'sync.last_ok_ms';
  static const String previousNodeIdsKey = 'node.previous_ids';
  static const String notifiedConflictsKey = 'conflicts.notified';

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

  /// Id этого устройства в журнале (заполняется при первом запуске).
  Future<String?> nodeId() => read(nodeIdKey);

  Future<void> setNodeId(String value) => write(nodeIdKey, value);

  /// Прежние id этого устройства: база была скопирована, и узел получал новый
  /// id (`startSync`). Копия копии хранит и id всех предков.
  ///
  /// Битое значение — пустое множество и предупреждение в журнале: ключ нужен
  /// только для подписи в списке устройств, и из-за него не должен падать
  /// запуск приложения; [addPreviousNodeId] перезапишет его заново.
  Future<Set<String>> previousNodeIds() async {
    final json = await read(previousNodeIdsKey);
    if (json == null) return const {};
    try {
      return {...(jsonDecode(json) as List<Object?>).cast<String>()};
    } on Object catch (error) {
      _log.w('Прежние id узла не разобраны: $json', error: error);
      return const {};
    }
  }

  Future<void> addPreviousNodeId(String id) async =>
      write(previousNodeIdsKey, jsonEncode([...await previousNodeIds(), id]));

  /// Открытые конфликты, о которых это устройство уже уведомило
  /// (`ConflictRepository.takeUnnotified`). Битое значение — пустое
  /// множество: в худшем случае одно повторное уведомление.
  Future<Set<String>> notifiedConflicts() async {
    final json = await read(notifiedConflictsKey);
    if (json == null) return const {};
    try {
      return {...(jsonDecode(json) as List<Object?>).cast<String>()};
    } on Object catch (error) {
      _log.w('Уведомлённые конфликты не разобраны: $json', error: error);
      return const {};
    }
  }

  Future<void> setNotifiedConflicts(Set<String> ids) =>
      write(notifiedConflictsKey, jsonEncode([...ids]..sort()));

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

  Future<void> removeFolderId() => remove(folderIdKey);

  /// Путь к выбранной пользователем общей папке (внутри неё — `planner-sync`).
  /// Локальный: на каждом устройстве своя папка облака (SYNC_DESIGN «Специальные
  /// случаи»).
  Future<String?> folderPath() => read(folderPathKey);

  Future<void> setFolderPath(String value) => write(folderPathKey, value);

  /// Время последней удачной синхронизации (мс UTC) — статус в настройках.
  Future<int?> lastSyncMs() async =>
      int.tryParse(await read(lastSyncKey) ?? '');

  Future<void> setLastSyncMs(int value) => write(lastSyncKey, value.toString());

  Future<Hlc?> uploadedUpTo() async => _parseHlc(await read(uploadedUpToKey));

  Future<void> setUploadedUpTo(Hlc value) =>
      write(uploadedUpToKey, value.toString());

  Future<void> removeUploadedUpTo() => remove(uploadedUpToKey);

  static Hlc? _parseHlc(String? text) => text == null ? null : Hlc.parse(text);
}
