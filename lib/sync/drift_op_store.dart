import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:oplog_sync/oplog_sync.dart';

import '../data/app_database.dart';
import '../data/local_meta_dao.dart';
import '../data/projection/default_registry.dart';
import '../data/projection/projector.dart';

/// [OpStore] поверх базы drift: журнал `ops`, версии полей `field_versions`,
/// таблицы сущностей через [ProjectorRegistry] и производные `conflicts`.
///
/// Логики слияния здесь нет — её ведёт `MergeEngine`; адаптер только хранит.
/// Поведение сверяется с `MemoryOpStore` контрактными сценариями
/// (`package:oplog_sync/testing.dart`).
final class DriftOpStore implements OpStore {
  DriftOpStore(this._db, {ProjectorRegistry? registry})
    : registry = registry ?? defaultRegistry(_db),
      _meta = LocalMetaDao(_db);

  final AppDatabase _db;
  final LocalMetaDao _meta;

  final ProjectorRegistry registry;

  @override
  Future<bool> containsOp(String opId) async {
    final query = _db.selectOnly(_db.ops)
      ..addColumns([_db.ops.opId])
      ..where(_db.ops.opId.equals(opId))
      ..limit(1);
    return await query.getSingleOrNull() != null;
  }

  @override
  Future<void> appendOp(Op op) async {
    // jsonEncode до записи: не-JSON значение — ошибка, а не порча журнала.
    final valueJson = jsonEncode(op.value);
    await _db
        .into(_db.ops)
        .insert(
          OpsCompanion.insert(
            opId: op.opId,
            nodeId: op.nodeId,
            hlc: op.hlc.toString(),
            base: Value(op.base?.toString()),
            entityType: op.entityType,
            entityId: op.entityId,
            field: op.field,
            valueJson: valueJson,
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  @override
  Future<Hlc?> fieldHlc(
    String entityType,
    String entityId,
    String field,
  ) async {
    final row = await _fieldVersion(entityType, entityId, field);
    return row == null ? null : Hlc.parse(row.hlc);
  }

  /// Записать версию поля и, если тип и поле известны реестру, колонку
  /// проекции. HLC не сравнивает — это делает движок.
  ///
  /// Проектор получает значение после JSON — то же, что прочитает
  /// [reproject]: `Map<dynamic, dynamic>` или объект с `toJson()` от
  /// вызывающего кода иначе разложились бы по-разному.
  @override
  Future<void> writeField(Op op) async {
    final valueJson = jsonEncode(op.value);
    final value = jsonDecode(valueJson);
    await _db.transaction(() async {
      await _db
          .into(_db.fieldVersions)
          .insertOnConflictUpdate(
            FieldVersionsCompanion.insert(
              entityType: op.entityType,
              entityId: op.entityId,
              field: op.field,
              hlc: op.hlc.toString(),
              valueJson: valueJson,
            ),
          );
      await registry[op.entityType]?.write(op.entityId, op.field, value);
    });
  }

  @override
  Future<List<Op>> allOps() async => [
    for (final row in await _db.select(_db.ops).get()) _toOp(row),
  ];

  @override
  Future<List<Op>> opsForEntity(String entityType, String entityId) async {
    final query = _db.select(_db.ops)
      ..where(
        (t) => t.entityType.equals(entityType) & t.entityId.equals(entityId),
      );
    return [for (final row in await query.get()) _toOp(row)];
  }

  /// Строки HLC одного узла сравниваются как числа: ширина полей фиксирована,
  /// а узел у всех строк запроса один и тот же.
  @override
  Future<List<Op>> opsOfNodeAfter(String nodeId, Hlc? after) async {
    final query = _db.select(_db.ops)
      ..where((t) {
        final ofNode = t.nodeId.equals(nodeId);
        return after == null
            ? ofNode
            : ofNode & t.hlc.isBiggerThanValue(after.toString());
      })
      ..orderBy([
        (t) => OrderingTerm.asc(t.hlc),
        (t) => OrderingTerm.asc(t.opId),
      ]);
    return [for (final row in await query.get()) _toOp(row)];
  }

  @override
  Future<bool> putConflict(Conflict conflict) => _db.transaction(() async {
    final existing = await (_db.select(
      _db.conflicts,
    )..where((t) => t.id.equals(conflict.id))).getSingleOrNull();
    if (existing != null) return false;
    await _db
        .into(_db.conflicts)
        .insert(
          ConflictsCompanion.insert(
            id: conflict.id,
            kind: conflict.kind.name,
            entityType: conflict.entityType,
            entityId: conflict.entityId,
            field: conflict.field,
            olderOpId: conflict.olderOpId,
            newerOpId: conflict.newerOpId,
          ),
        );
    return true;
  });

  /// `resolved` — из версии поля сущности `conflict`, поэтому не важно, что
  /// пришло раньше: выбор пользователя или сама пара правок.
  @override
  Future<List<Conflict>> conflicts() async {
    final resolvedRows =
        await (_db.select(_db.fieldVersions)..where(
              (t) =>
                  t.entityType.equals(conflictEntityType) &
                  t.field.equals(conflictResolvedField),
            ))
            .get();
    final resolved = {
      for (final row in resolvedRows)
        if (jsonDecode(row.valueJson) == true) row.entityId,
    };
    // Порядок по id — детерминированный; экран «Конфликты» сортирует сам.
    final rows = await (_db.select(
      _db.conflicts,
    )..orderBy([(t) => OrderingTerm.asc(t.id)])).get();
    return [
      for (final row in rows)
        Conflict(
          id: row.id,
          kind: ConflictKind.values.byName(row.kind),
          entityType: row.entityType,
          entityId: row.entityId,
          field: row.field,
          olderOpId: row.olderOpId,
          newerOpId: row.newerOpId,
          resolved: resolved.contains(row.id),
        ),
    ];
  }

  /// Единственное место, где таблицы сущностей очищаются напрямую: перед
  /// пересборкой из журнала (`MergeEngine.rebuild`). Журнал и локальное
  /// состояние не трогаются.
  @override
  Future<void> clearProjections() => _db.transaction(() async {
    for (final projector in registry.all) {
      await projector.clear();
    }
    await _db.delete(_db.fieldVersions).go();
    await _db.delete(_db.conflicts).go();
  });

  /// Вложенный вызов — точка сохранения (savepoint): исключение откатывает
  /// только её, внешняя транзакция может продолжиться.
  @override
  Future<T> transaction<T>(Future<T> Function() action) =>
      _db.transaction(action);

  /// Таблицы сущностей разложены другой версией реестра (приложение
  /// обновилось или база новая) — нужен [reproject].
  Future<bool> needsReproject() async =>
      await _meta.projectorVersion() != registry.version;

  /// Заново разложить `field_versions` по таблицам сущностей текущим реестром.
  ///
  /// Так поля, пришедшие от более новой версии приложения до обновления этой,
  /// попадают в свои колонки. LWW и конфликты не пересчитываются: победитель
  /// каждого поля уже записан в `field_versions`.
  Future<void> reproject() => _db.transaction(() async {
    for (final projector in registry.all) {
      await projector.clear();
    }
    final rows = await (_db.select(
      _db.fieldVersions,
    )..where((t) => t.entityType.isIn(registry.entityTypes))).get();
    for (final row in rows) {
      await registry[row.entityType]!.write(
        row.entityId,
        row.field,
        jsonDecode(row.valueJson),
      );
    }
    await _meta.setProjectorVersion(registry.version);
  });

  Future<FieldVersionRow?> _fieldVersion(
    String entityType,
    String entityId,
    String field,
  ) =>
      (_db.select(_db.fieldVersions)..where(
            (t) =>
                t.entityType.equals(entityType) &
                t.entityId.equals(entityId) &
                t.field.equals(field),
          ))
          .getSingleOrNull();

  static Op _toOp(OpRow row) => Op(
    opId: row.opId,
    nodeId: row.nodeId,
    hlc: Hlc.parse(row.hlc),
    entityType: row.entityType,
    entityId: row.entityId,
    field: row.field,
    value: jsonDecode(row.valueJson),
    base: row.base == null ? null : Hlc.parse(row.base!),
  );
}
