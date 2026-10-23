import 'package:oplog_sync/oplog_sync.dart';

import '../data/local_meta_dao.dart';
import 'sync_lease.dart';

/// Один проход синхронизации с папкой под арендой [SyncLease].
///
/// Таймер, выбор папки и показ результата — в M2 (экран настроек).
final class FolderSync {
  FolderSync({
    required this._transport,
    required this._lease,
    required this._meta,
  });

  final FolderTransport _transport;
  final SyncLease _lease;
  final LocalMetaDao _meta;

  /// Синхронизировать сейчас. `null` — синхронизацию этой базы уже ведёт
  /// другой процесс или изолят: пропускаем цикл, а не ждём.
  ///
  /// Ошибки транспорта (папка новее приложения, сбой записи) пробрасываются;
  /// аренда отпускается в любом случае.
  Future<FolderSyncReport?> syncOnce() async {
    if (!await _lease.tryAcquire()) return null;
    try {
      return await _transport.sync();
    } finally {
      try {
        // Приём чужих ops сдвигает часы движка вперёд: сохраняем, чтобы правка
        // после перезапуска была позже уже принятых.
        await _meta.setHlc(_transport.engine.clock);
      } finally {
        await _lease.release();
      }
    }
  }
}
