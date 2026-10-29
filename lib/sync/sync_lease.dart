import 'dart:convert';

import 'package:drift/drift.dart';

import '../core/clock.dart';
import '../data/app_database.dart';
import '../data/local_meta_dao.dart';

/// Аренда (lease) права синхронизировать базу: два синхронизатора одной базы
/// (два экземпляра `FolderSync`, процесса или изолята) не пишут в папку
/// одновременно.
///
/// Запись аренда не защищает: два движка на одной базе (два экземпляра
/// приложения, UI и фоновая задача со своим `MergeEngine`) ведут раздельные
/// часы одного узла и ломают водяной знак выгрузки. Поэтому во всей системе
/// на базу — один `SyncServices`: на Windows — запуск в одном экземпляре (M2),
/// на Android фоновая задача работает через тот же движок (M6).
///
/// Запись `sync.lease` в `local_meta` — `{owner, until_ms}`. Захват — одна
/// SQL-команда «вставить или перехватить, если аренда моя или истекла»:
/// SQLite выполняет её атомарно для всех соединений к файлу. Упавший
/// владелец не держит аренду дольше [duration], а аренду прежнего запуска
/// снимает `startSync`.
///
/// Альтернатива — lock-файл (`RandomAccessFile.lock`): на Android это
/// блокировка `fcntl`, она действует только между процессами, а фоновая
/// задача может работать в изоляте того же процесса, что и UI.
final class SyncLease {
  SyncLease(
    this._db, {
    required this.owner,
    required this._clock,
    this.duration = const Duration(minutes: 10),
  });

  final AppDatabase _db;
  final AppClock _clock;

  /// Кто держит аренду: свой id у каждого запуска движка.
  final String owner;

  /// Срок аренды: дольше любой разумной синхронизации.
  final Duration duration;

  /// Захватить или продлить аренду; `false` — её держит другой владелец.
  Future<bool> tryAcquire() async {
    final now = _clock.nowMs();
    final value = jsonEncode({
      'owner': owner,
      'until_ms': now + duration.inMilliseconds,
    });
    // Битое значение (не JSON) считается свободной арендой: CASE вычисляет
    // json_extract только для корректного JSON. Нет ключа — тоже свободна:
    // без COALESCE сравнение с NULL дало бы NULL, и аренда не освободилась бы
    // никогда.
    final changed = await _db.customUpdate(
      'INSERT INTO local_meta (key, value) VALUES (?1, ?2) '
      'ON CONFLICT (key) DO UPDATE SET value = excluded.value '
      'WHERE CASE WHEN json_valid(local_meta.value) '
      "THEN COALESCE(json_extract(local_meta.value, '\$.owner') = ?3, 0) "
      "OR COALESCE(json_extract(local_meta.value, '\$.until_ms'), 0) <= ?4 "
      'ELSE 1 END',
      variables: [
        Variable.withString(LocalMetaDao.syncLeaseKey),
        Variable.withString(value),
        Variable.withString(owner),
        Variable.withInt(now),
      ],
      updates: {_db.localMeta},
      updateKind: UpdateKind.update,
    );
    return changed > 0;
  }

  /// Отдать аренду, если она наша.
  Future<void> release() => _db.customUpdate(
    'DELETE FROM local_meta WHERE key = ?1 AND '
    'CASE WHEN json_valid(value) '
    "THEN json_extract(value, '\$.owner') = ?2 ELSE 0 END",
    variables: [
      Variable.withString(LocalMetaDao.syncLeaseKey),
      Variable.withString(owner),
    ],
    updates: {_db.localMeta},
    updateKind: UpdateKind.delete,
  );
}
