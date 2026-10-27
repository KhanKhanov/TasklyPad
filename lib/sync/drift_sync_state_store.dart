import 'package:oplog_sync/oplog_sync.dart';

import '../data/app_database.dart';
import '../data/local_meta_dao.dart';

/// [SyncStateStore] поверх базы: курсоры чанков — в `sync_cursors`, папка и
/// водяной знак выгрузки — в `local_meta`.
///
/// Транзакцию с применением ops не делит (см. [SyncStateStore]): после сбоя
/// чанк перечитается, а дубликаты отбросит идемпотентность движка.
final class DriftSyncStateStore implements SyncStateStore {
  DriftSyncStateStore(this._db) : _meta = LocalMetaDao(_db);

  final AppDatabase _db;
  final LocalMetaDao _meta;

  @override
  Future<String?> folderId() => _meta.folderId();

  @override
  Future<void> resetForFolder(String folderId) => _db.transaction(() async {
    await _db.delete(_db.syncCursors).go();
    await _meta.removeUploadedUpTo();
    await _meta.setFolderId(folderId);
  });

  @override
  Future<void> forgetFolder() => _db.transaction(() async {
    await _db.delete(_db.syncCursors).go();
    await _meta.removeUploadedUpTo();
    await _meta.removeFolderId();
  });

  @override
  Future<int> chunkCursor(String nodeId) async {
    final row = await (_db.select(
      _db.syncCursors,
    )..where((t) => t.nodeId.equals(nodeId))).getSingleOrNull();
    return row?.seq ?? 0;
  }

  @override
  Future<void> setChunkCursor(String nodeId, int seq) => _db
      .into(_db.syncCursors)
      .insertOnConflictUpdate(
        SyncCursorsCompanion.insert(nodeId: nodeId, seq: seq),
      );

  @override
  Future<Hlc?> uploadedUpTo() => _meta.uploadedUpTo();

  @override
  Future<void> setUploadedUpTo(Hlc hlc) => _meta.setUploadedUpTo(hlc);
}
