import 'package:drift/drift.dart';

// Проекции сущностей: строятся из `field_versions` реестром проекторов
// (lib/data/projection). Писать в них напрямую нельзя — только через op-log.
//
// Ops приходят в любом порядке (приоритет раньше названия, задача раньше
// проекта), поэтому у колонок нет NOT NULL без значения по умолчанию и нет
// внешних ключей. Удалённая сущность остаётся строкой с `deleted = true`.

/// Проекты.
@DataClassName('ProjectRow')
class Projects extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withDefault(const Constant(''))();

  /// Имя цвета палитры Todoist.
  TextColumn get color => text().withDefault(const Constant('charcoal'))();
  TextColumn get parentId => text().nullable()();
  TextColumn get orderKey => text().withDefault(const Constant(''))();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  BoolColumn get isInbox => boolean().withDefault(const Constant(false))();

  /// `list`, `board` или `calendar`; незнакомое значение UI показывает списком.
  TextColumn get viewStyle => text().withDefault(const Constant('list'))();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Задачи.
@DataClassName('TaskRow')
@TableIndex(name: 'tasks_by_project', columns: {#projectId, #orderKey})
@TableIndex(name: 'tasks_by_due', columns: {#dueDate})
class Tasks extends Table {
  TextColumn get id => text()();
  TextColumn get content => text().withDefault(const Constant(''))();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get projectId => text().nullable()();
  TextColumn get sectionId => text().nullable()();
  TextColumn get parentId => text().nullable()();
  TextColumn get orderKey => text().withDefault(const Constant(''))();

  /// 1 = P1 (высший, красный) … 4 = P4 (по умолчанию), как в интерфейсе.
  /// В API Todoist шкала обратная (4 = P1) — переводится при импорте.
  IntColumn get priority => integer().withDefault(const Constant(4))();

  /// Срок: дата `YYYY-MM-DD`, время `HH:MM` (null — срок без времени),
  /// IANA-таймзона (null — «плавающее» время, по часам устройства).
  TextColumn get dueDate => text().nullable()();
  TextColumn get dueTime => text().nullable()();
  TextColumn get dueTz => text().nullable()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();

  /// Моменты времени — UTC ISO-8601.
  TextColumn get completedAt => text().nullable()();
  TextColumn get addedAt => text().nullable()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
