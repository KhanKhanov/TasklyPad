import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oplog_sync/oplog_sync.dart';
import 'package:oplog_sync/testing.dart';
import 'package:planner/data/app_database.dart';
import 'package:planner/data/projection/projector.dart';
import 'package:planner/sync/drift_op_store.dart';

/// База в памяти, закрывается после теста.
AppDatabase memoryDatabase() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  return db;
}

/// [OpStoreProbe] над [DriftOpStore]: сущности читаются из `field_versions`,
/// где лежат и поля, которых приложение не знает.
final class DriftProbe implements OpStoreProbe {
  DriftProbe(this.db, {ProjectorRegistry? registry})
    : store = DriftOpStore(db, registry: registry);

  final AppDatabase db;

  @override
  final DriftOpStore store;

  @override
  Future<Map<String, Object?>?> entity(
    String entityType,
    String entityId,
  ) async {
    final rows =
        await (db.select(db.fieldVersions)..where(
              (t) =>
                  t.entityType.equals(entityType) & t.entityId.equals(entityId),
            ))
            .get();
    if (rows.isEmpty) return null;
    return {for (final row in rows) row.field: jsonDecode(row.valueJson)};
  }

  @override
  Future<Map<String, Map<String, Object?>>> alive(String entityType) async {
    final rows = await (db.select(
      db.fieldVersions,
    )..where((t) => t.entityType.equals(entityType))).get();
    final entities = <String, Map<String, Object?>>{};
    for (final row in rows) {
      entities.putIfAbsent(row.entityId, () => {})[row.field] = jsonDecode(
        row.valueJson,
      );
    }
    entities.removeWhere((_, fields) => fields[Op.deletedField] == true);
    return entities;
  }

  /// Таблицы сущностей совпадают с тем, что даёт перекладка `field_versions`
  /// реестром: инкрементальная запись полей ничего не потеряла и не добавила.
  @override
  Future<void> checkConsistency() async {
    final before = await dumpEntityTables(db);
    await store.reproject();
    check(await dumpEntityTables(db), before, 'таблицы сущностей == reproject');
  }
}

/// Фабрика хранилищ на базе в памяти.
Future<OpStoreProbe> driftProbeFactory() async => DriftProbe(memoryDatabase());

/// Таблицы сущностей: имя → строки, упорядоченные по id.
Future<Map<String, Object?>> dumpEntityTables(AppDatabase db) =>
    _dump(db, const ['tasks', 'projects']);

/// Все таблицы, которые пересобирает `rebuild`, и журнал.
Future<Map<String, Object?>> dumpSyncedState(AppDatabase db) => _dump(
  db,
  const ['ops', 'field_versions', 'conflicts', 'tasks', 'projects'],
);

Future<Map<String, Object?>> _dump(AppDatabase db, List<String> tables) async {
  // Имена таблиц — константы теста, не данные.
  return {
    for (final table in tables)
      table: [
        for (final row
            in await db
                .customSelect('SELECT * FROM $table ORDER BY 1, 2, 3')
                .get())
          row.data,
      ],
  };
}
