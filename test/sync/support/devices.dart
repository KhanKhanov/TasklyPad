import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:oplog_sync/oplog_sync.dart';
import 'package:planner/core/clock.dart';
import 'package:planner/core/ids.dart';
import 'package:planner/data/app_database.dart';
import 'package:planner/sync/folder_sync.dart';
import 'package:planner/sync/node_identity.dart';
import 'package:planner/sync/sync_services.dart';

import '../../data/support/drift_probe.dart';

/// Время старта часов устройств в тестах.
final DateTime testStart = DateTime.utc(2026, 10, 23, 9);

/// Временная папка на диске, удаляется после теста.
Directory tempDir(String prefix) {
  final dir = Directory.systemTemp.createTempSync(prefix);
  addTearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });
  return dir;
}

/// Устройство в тесте: своя база в памяти, свои часы, метка узла и ядро
/// данных, собранное тем же `startSync`, что и в приложении.
final class TestDevice {
  TestDevice._(this.db, this.clock, this.marker, this._seed, this.services);

  /// Запустить устройство. [db] и [marker] — от прежнего запуска (перезапуск)
  /// или подготовленные тестом (копия базы).
  static Future<TestDevice> start({
    AppDatabase? db,
    FixedClock? clock,
    MemoryNodeMarker? marker,
    int seed = 1,
  }) async {
    final database = db ?? memoryDatabase();
    final fixed = clock ?? FixedClock(testStart);
    final mark = marker ?? MemoryNodeMarker();
    final services = await startSync(
      database,
      clock: fixed,
      ids: IdGenerator(random: Random(seed)),
      marker: mark,
    );
    return TestDevice._(database, fixed, mark, seed, services);
  }

  final AppDatabase db;
  final FixedClock clock;
  final MemoryNodeMarker marker;
  final int _seed;
  final SyncServices services;

  String get nodeId => services.nodeId;

  /// Новый запуск приложения на той же базе: движок и часы собираются заново.
  Future<TestDevice> restart() =>
      start(db: db, clock: clock, marker: marker, seed: _seed + 1000);

  FolderSync folder(SyncFs fs) =>
      services.folderSync(fs, deviceInfo: {'name': 'Устройство $nodeId'});

  void advance(Duration delta) => clock.advance(delta);

  /// Все поля сущности из `field_versions` (включая незнакомые) или `null`.
  Future<Map<String, Object?>?> entity(String type, String id) async {
    final rows = await (db.select(
      db.fieldVersions,
    )..where((t) => t.entityType.equals(type) & t.entityId.equals(id))).get();
    if (rows.isEmpty) return null;
    return {for (final row in rows) row.field: jsonDecode(row.valueJson)};
  }

  /// Строка задачи в типизированной таблице.
  Future<TaskRow?> taskRow(String id) =>
      (db.select(db.tasks)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Живые (не удалённые) задачи: id → содержимое.
  Future<Map<String, String>> aliveTasks() async => {
    for (final row in await (db.select(
      db.tasks,
    )..where((t) => t.deleted.equals(false))).get())
      row.id: row.content,
  };

  Future<List<Conflict>> conflicts() => services.store.conflicts();

  /// Ops этого узла в журнале, по возрастанию HLC.
  Future<List<Op>> ownOps() => services.store.opsOfNodeAfter(nodeId, null);
}
