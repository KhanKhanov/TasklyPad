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

  /// Подпроекты свёрнуты в сайдбаре.
  BoolColumn get isCollapsed => boolean().withDefault(const Constant(false))();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Задачи.
@DataClassName('TaskRow')
@TableIndex(name: 'tasks_by_project', columns: {#projectId, #orderKey})
@TableIndex(name: 'tasks_by_due', columns: {#dueDate})
@TableIndex(name: 'tasks_by_parent', columns: {#parentId})
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

  /// Срок текстом, как его ввёл пользователь, и язык разбора (`ru`, `en`).
  TextColumn get dueString => text().nullable()();
  TextColumn get dueLang => text().nullable()();

  /// Правило повторения — JSON `{"rrule": [...], "from_completion": bool}`;
  /// `null` — срок не повторяется или правило не разобрано.
  TextColumn get dueRule => text().nullable()();

  /// Есть правило [dueRule] — значок повтора и фильтр `recurring` (M5) без
  /// разбора JSON.
  BoolColumn get dueIsRecurring =>
      boolean().withDefault(const Constant(false))();

  /// Дедлайн — отдельная от срока дата `YYYY-MM-DD`, без времени.
  TextColumn get deadlineDate => text().nullable()();

  /// Длительность: число и единица `minute` или `day`, как в Todoist API.
  IntColumn get durationAmount => integer().nullable()();
  TextColumn get durationUnit => text().nullable()();

  /// Подзадачи свёрнуты в списке.
  BoolColumn get isCollapsed => boolean().withDefault(const Constant(false))();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();

  /// Моменты времени — UTC ISO-8601.
  TextColumn get completedAt => text().nullable()();
  TextColumn get addedAt => text().nullable()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Разделы проекта.
@DataClassName('SectionRow')
@TableIndex(name: 'sections_by_project', columns: {#projectId, #orderKey})
class Sections extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withDefault(const Constant(''))();
  TextColumn get projectId => text().nullable()();
  TextColumn get orderKey => text().withDefault(const Constant(''))();
  BoolColumn get isCollapsed => boolean().withDefault(const Constant(false))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Метки.
@DataClassName('LabelRow')
class Labels extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withDefault(const Constant(''))();

  /// Имя цвета палитры Todoist.
  TextColumn get color => text().withDefault(const Constant('charcoal'))();
  TextColumn get orderKey => text().withDefault(const Constant(''))();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Выполненные вхождения повторяющихся задач — история для «Завершённых»
/// (M8) и кармы (M10). Id детерминированный (`completionId`): одно
/// вхождение, отмеченное на двух устройствах, — одна строка; «Отменить» —
/// строка с `deleted = true`.
@DataClassName('CompletionRow')
@TableIndex(name: 'completions_by_task', columns: {#taskId})
class Completions extends Table {
  TextColumn get id => text()();
  TextColumn get taskId => text().nullable()();

  /// Срок вхождения: `YYYY-MM-DD` или `YYYY-MM-DDTHH:MM`.
  TextColumn get dueWas => text().nullable()();

  /// UTC ISO-8601.
  TextColumn get completedAt => text().nullable()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Метки задач (многие ко многим). Id связи детерминированный: одна и та же
/// метка, поставленная задаче на двух устройствах, даёт одну строку; снятая
/// метка — строка с `deleted = true`.
@DataClassName('TaskLabelRow')
@TableIndex(name: 'task_labels_by_task', columns: {#taskId})
@TableIndex(name: 'task_labels_by_label', columns: {#labelId})
class TaskLabels extends Table {
  TextColumn get id => text()();
  TextColumn get taskId => text().nullable()();
  TextColumn get labelId => text().nullable()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
