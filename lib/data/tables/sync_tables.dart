import 'package:drift/drift.dart';

// Таблицы синхронизации. Источник истины — журнал `ops`; `field_versions` и
// `conflicts` производные (пересобираются из журнала), `sync_cursors` и
// `local_meta` — локальное состояние устройства, не синхронизируются.
//
// HLC хранится строкой `Hlc.toString()`: при одинаковом узле порядок строк
// совпадает с порядком меток, поэтому SQL сравнивает HLC только внутри одного
// узла. Значение op — JSON-текст (`null` хранится как `'null'`).

/// Журнал операций (op-log).
@DataClassName('OpRow')
@TableIndex(name: 'ops_by_field', columns: {#entityType, #entityId, #field})
@TableIndex(name: 'ops_by_node_hlc', columns: {#nodeId, #hlc})
class Ops extends Table {
  TextColumn get opId => text()();
  TextColumn get nodeId => text()();
  TextColumn get hlc => text()();
  TextColumn get base => text().nullable()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get field => text()();
  TextColumn get valueJson => text()();

  @override
  Set<Column<Object>> get primaryKey => {opId};
}

/// Текущее значение каждого поля каждой сущности и его HLC (победитель LWW).
///
/// Хранит и поля, которых приложение не знает (от более новой версии на
/// другом устройстве): типизированные таблицы строятся поверх этой.
@DataClassName('FieldVersionRow')
class FieldVersions extends Table {
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get field => text()();
  TextColumn get hlc => text()();
  TextColumn get valueJson => text()();

  @override
  Set<Column<Object>> get primaryKey => {entityType, entityId, field};

  @override
  bool get withoutRowId => true;
}

/// Найденные параллельные правки. `resolved` здесь нет: он приходит op-ом на
/// сущность `conflict` и читается из `field_versions`.
@DataClassName('ConflictRow')
class Conflicts extends Table {
  TextColumn get id => text()();
  TextColumn get kind =>
      text().customConstraint("NOT NULL CHECK (kind IN ('edit', 'delete'))")();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get field => text()();
  TextColumn get olderOpId => text()();
  TextColumn get newerOpId => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Номер последнего полностью применённого чанка каждого узла.
@DataClassName('SyncCursorRow')
class SyncCursors extends Table {
  TextColumn get nodeId => text()();
  IntColumn get seq => integer()();

  @override
  Set<Column<Object>> get primaryKey => {nodeId};
}

/// Локальные настройки движка: id узла, часы, версия проектора, папка.
@DataClassName('LocalMetaRow')
class LocalMeta extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
