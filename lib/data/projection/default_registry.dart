import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:logger/logger.dart';

import '../app_database.dart';
import 'due_rule.dart';
import 'entity_fields.dart';
import 'projector.dart';

/// Версия набора полей [defaultRegistry]. Увеличивать при каждом изменении
/// полей или колонок проекторов: база переложит `field_versions` заново.
const int projectorVersion = 6;

final Logger _logger = Logger();

/// Проекторы сущностей текущей версии приложения.
ProjectorRegistry defaultRegistry(
  AppDatabase db, {
  void Function(String message)? warn,
}) => ProjectorRegistry(projectorVersion, [
  taskProjector(db, warn: warn),
  projectProjector(db, warn: warn),
  sectionProjector(db, warn: warn),
  labelProjector(db, warn: warn),
  filterProjector(db, warn: warn),
  taskLabelProjector(db, warn: warn),
  completionProjector(db, warn: warn),
  viewOptionsProjector(db, warn: warn),
]);

/// Задачи: поле op → колонки `tasks`.
TableProjector<$TasksTable, TaskRow> taskProjector(
  AppDatabase db, {
  void Function(String message)? warn,
}) => TableProjector(
  db: db,
  entityType: EntityTypes.task,
  table: db.tasks,
  warn: warn,
  writers: {
    TaskFields.content: (id, v) =>
        TasksCompanion(id: Value(id), content: Value(textOr(v, ''))),
    TaskFields.description: (id, v) =>
        TasksCompanion(id: Value(id), description: Value(textOr(v, ''))),
    TaskFields.projectId: (id, v) =>
        TasksCompanion(id: Value(id), projectId: Value(textOrNull(v))),
    TaskFields.sectionId: (id, v) =>
        TasksCompanion(id: Value(id), sectionId: Value(textOrNull(v))),
    TaskFields.parentId: (id, v) =>
        TasksCompanion(id: Value(id), parentId: Value(textOrNull(v))),
    TaskFields.orderKey: (id, v) =>
        TasksCompanion(id: Value(id), orderKey: Value(textOr(v, ''))),
    TaskFields.dayOrderKey: (id, v) =>
        TasksCompanion(id: Value(id), dayOrderKey: Value(textOr(v, ''))),
    TaskFields.priority: (id, v) =>
        TasksCompanion(id: Value(id), priority: Value(intOr(v, 4))),
    TaskFields.due: (id, v) => _due(id, v, warn ?? _logger.w),
    TaskFields.deadline: _deadline,
    TaskFields.duration: _duration,
    TaskFields.isCollapsed: (id, v) =>
        TasksCompanion(id: Value(id), isCollapsed: Value(boolOr(v, false))),
    TaskFields.isCompleted: (id, v) =>
        TasksCompanion(id: Value(id), isCompleted: Value(boolOr(v, false))),
    TaskFields.completedLabelNames: _completedLabelNames,
    TaskFields.completedAt: (id, v) =>
        TasksCompanion(id: Value(id), completedAt: Value(textOrNull(v))),
    TaskFields.addedAt: (id, v) =>
        TasksCompanion(id: Value(id), addedAt: Value(textOrNull(v))),
    TaskFields.deleted: (id, v) =>
        TasksCompanion(id: Value(id), deleted: Value(boolOr(v, false))),
  },
);

/// Срок — объект {date, time?, tz?, string?, lang?, rule?, series_time?};
/// `null` — срока нет. Неразобранные правило, текст, язык или время серии не
/// отменяют дату: срок остаётся, без них, и [warn] сообщает об этом; само
/// значение остаётся в `field_versions`. Повтор — только у срока с датой.
TasksCompanion _due(
  String id,
  Object? value,
  void Function(String message) warn,
) {
  switch (value) {
    case null:
      return TasksCompanion(
        id: Value(id),
        dueDate: const Value(null),
        dueTime: const Value(null),
        dueTz: const Value(null),
        dueString: const Value(null),
        dueLang: const Value(null),
        dueRule: const Value(null),
        dueIsRecurring: const Value(false),
        dueSeriesTime: const Value(null),
      );
    case final Map<String, Object?> due:
      final date = textOrNull(due[DueKeys.date]);
      final raw = due[DueKeys.rule];
      final parsed = recurrenceRuleOf(raw);
      if (raw != null && parsed == null) {
        warn('task/$id.due: правило повторения не разобрано: $raw');
      }
      final rule = date == null ? null : parsed;
      String? optionalText(String key) {
        final value = due[key];
        if (value == null || value is String) return value as String?;
        warn('task/$id.due.$key: ожидалась строка, пришло $value');
        return null;
      }

      return TasksCompanion(
        id: Value(id),
        dueDate: Value(date),
        dueTime: Value(textOrNull(due[DueKeys.time])),
        dueTz: Value(textOrNull(due[DueKeys.tz])),
        dueString: Value(optionalText(DueKeys.string)),
        dueLang: Value(optionalText(DueKeys.lang)),
        dueRule: Value(
          rule == null
              ? null
              : jsonEncode({
                  RuleKeys.rrule: rule.rrule,
                  RuleKeys.fromCompletion: rule.fromCompletion,
                }),
        ),
        dueIsRecurring: Value(rule != null),
        // Время серии — только у повторяющегося срока и только `HH:MM` или
        // пустая строка: испорченное значение подвесило бы выполнение.
        dueSeriesTime: Value(rule == null ? null : _seriesTime(id, due, warn)),
      );
    default:
      throw ProjectionTypeError('объект срока', value);
  }
}

final RegExp _hhmm = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');

/// Время серии срока [due]: `HH:MM`, пустая строка (серия без времени) или
/// `null` — ключа нет или значение испорчено ([warn] сообщает).
String? _seriesTime(
  String id,
  Map<String, Object?> due,
  void Function(String message) warn,
) {
  final value = due[DueKeys.seriesTime];
  if (value == null) return null;
  if (value is String && (value.isEmpty || _hhmm.hasMatch(value))) {
    return value;
  }
  warn('task/$id.due.series_time: ожидалось HH:MM, пришло $value');
  return null;
}

/// Дедлайн — объект {date}; `null` — дедлайна нет.
TasksCompanion _deadline(String id, Object? value) => switch (value) {
  null => TasksCompanion(id: Value(id), deadlineDate: const Value(null)),
  final Map<String, Object?> deadline => TasksCompanion(
    id: Value(id),
    deadlineDate: Value(textOrNull(deadline[DeadlineKeys.date])),
  ),
  _ => throw ProjectionTypeError('объект дедлайна', value),
};

/// Длительность — объект {amount, unit}; `null` — длительности нет.
TasksCompanion _duration(String id, Object? value) => switch (value) {
  null => TasksCompanion(
    id: Value(id),
    durationAmount: const Value(null),
    durationUnit: const Value(null),
  ),
  final Map<String, Object?> duration => TasksCompanion(
    id: Value(id),
    durationAmount: Value(intOrNull(duration[DurationKeys.amount])),
    durationUnit: Value(textOrNull(duration[DurationKeys.unit])),
  ),
  _ => throw ProjectionTypeError('объект длительности', value),
};

/// Имена меток на момент завершения — объект {id метки: имя}; `null` —
/// снимка нет. Объект, в котором хоть одно имя не строка, — не того типа.
TasksCompanion _completedLabelNames(String id, Object? value) =>
    switch (value) {
      null => TasksCompanion(
        id: Value(id),
        completedLabelNames: const Value(null),
      ),
      final Map<String, Object?> names
          when names.values.every((name) => name is String) =>
        TasksCompanion(
          id: Value(id),
          completedLabelNames: Value(jsonEncode(names)),
        ),
      _ => throw ProjectionTypeError('объект имён меток', value),
    };

/// Проекты: поле op → колонки `projects`.
TableProjector<$ProjectsTable, ProjectRow> projectProjector(
  AppDatabase db, {
  void Function(String message)? warn,
}) => TableProjector(
  db: db,
  entityType: EntityTypes.project,
  table: db.projects,
  warn: warn,
  writers: {
    ProjectFields.name: (id, v) =>
        ProjectsCompanion(id: Value(id), name: Value(textOr(v, ''))),
    ProjectFields.description: (id, v) =>
        ProjectsCompanion(id: Value(id), description: Value(textOr(v, ''))),
    ProjectFields.color: (id, v) =>
        ProjectsCompanion(id: Value(id), color: Value(textOr(v, 'charcoal'))),
    ProjectFields.parentId: (id, v) =>
        ProjectsCompanion(id: Value(id), parentId: Value(textOrNull(v))),
    ProjectFields.orderKey: (id, v) =>
        ProjectsCompanion(id: Value(id), orderKey: Value(textOr(v, ''))),
    ProjectFields.isFavorite: (id, v) =>
        ProjectsCompanion(id: Value(id), isFavorite: Value(boolOr(v, false))),
    ProjectFields.isArchived: (id, v) =>
        ProjectsCompanion(id: Value(id), isArchived: Value(boolOr(v, false))),
    ProjectFields.isInbox: (id, v) =>
        ProjectsCompanion(id: Value(id), isInbox: Value(boolOr(v, false))),
    ProjectFields.viewStyle: (id, v) =>
        ProjectsCompanion(id: Value(id), viewStyle: Value(textOr(v, 'list'))),
    ProjectFields.isCollapsed: (id, v) =>
        ProjectsCompanion(id: Value(id), isCollapsed: Value(boolOr(v, false))),
    ProjectFields.deleted: (id, v) =>
        ProjectsCompanion(id: Value(id), deleted: Value(boolOr(v, false))),
  },
);

/// Разделы: поле op → колонки `sections`.
TableProjector<$SectionsTable, SectionRow> sectionProjector(
  AppDatabase db, {
  void Function(String message)? warn,
}) => TableProjector(
  db: db,
  entityType: EntityTypes.section,
  table: db.sections,
  warn: warn,
  writers: {
    SectionFields.name: (id, v) =>
        SectionsCompanion(id: Value(id), name: Value(textOr(v, ''))),
    SectionFields.projectId: (id, v) =>
        SectionsCompanion(id: Value(id), projectId: Value(textOrNull(v))),
    SectionFields.orderKey: (id, v) =>
        SectionsCompanion(id: Value(id), orderKey: Value(textOr(v, ''))),
    SectionFields.isCollapsed: (id, v) =>
        SectionsCompanion(id: Value(id), isCollapsed: Value(boolOr(v, false))),
    SectionFields.isArchived: (id, v) =>
        SectionsCompanion(id: Value(id), isArchived: Value(boolOr(v, false))),
    SectionFields.deleted: (id, v) =>
        SectionsCompanion(id: Value(id), deleted: Value(boolOr(v, false))),
  },
);

/// Метки: поле op → колонки `labels`.
TableProjector<$LabelsTable, LabelRow> labelProjector(
  AppDatabase db, {
  void Function(String message)? warn,
}) => TableProjector(
  db: db,
  entityType: EntityTypes.label,
  table: db.labels,
  warn: warn,
  writers: {
    LabelFields.name: (id, v) =>
        LabelsCompanion(id: Value(id), name: Value(textOr(v, ''))),
    LabelFields.color: (id, v) =>
        LabelsCompanion(id: Value(id), color: Value(textOr(v, 'charcoal'))),
    LabelFields.orderKey: (id, v) =>
        LabelsCompanion(id: Value(id), orderKey: Value(textOr(v, ''))),
    LabelFields.isFavorite: (id, v) =>
        LabelsCompanion(id: Value(id), isFavorite: Value(boolOr(v, false))),
    LabelFields.deleted: (id, v) =>
        LabelsCompanion(id: Value(id), deleted: Value(boolOr(v, false))),
  },
);

/// Сохранённые фильтры: поле op → колонки `filters`.
TableProjector<$FiltersTable, FilterRow> filterProjector(
  AppDatabase db, {
  void Function(String message)? warn,
}) => TableProjector(
  db: db,
  entityType: EntityTypes.filter,
  table: db.filters,
  warn: warn,
  writers: {
    FilterFields.name: (id, v) =>
        FiltersCompanion(id: Value(id), name: Value(textOr(v, ''))),
    FilterFields.query: (id, v) =>
        FiltersCompanion(id: Value(id), query: Value(textOr(v, ''))),
    FilterFields.description: (id, v) =>
        FiltersCompanion(id: Value(id), description: Value(textOr(v, ''))),
    FilterFields.color: (id, v) =>
        FiltersCompanion(id: Value(id), color: Value(textOr(v, 'charcoal'))),
    FilterFields.orderKey: (id, v) =>
        FiltersCompanion(id: Value(id), orderKey: Value(textOr(v, ''))),
    FilterFields.isFavorite: (id, v) =>
        FiltersCompanion(id: Value(id), isFavorite: Value(boolOr(v, false))),
    FilterFields.deleted: (id, v) =>
        FiltersCompanion(id: Value(id), deleted: Value(boolOr(v, false))),
  },
);

/// Метки задач: поле op → колонки `task_labels`.
TableProjector<$TaskLabelsTable, TaskLabelRow> taskLabelProjector(
  AppDatabase db, {
  void Function(String message)? warn,
}) => TableProjector(
  db: db,
  entityType: EntityTypes.taskLabel,
  table: db.taskLabels,
  warn: warn,
  writers: {
    TaskLabelFields.taskId: (id, v) =>
        TaskLabelsCompanion(id: Value(id), taskId: Value(textOrNull(v))),
    TaskLabelFields.labelId: (id, v) =>
        TaskLabelsCompanion(id: Value(id), labelId: Value(textOrNull(v))),
    TaskLabelFields.deleted: (id, v) =>
        TaskLabelsCompanion(id: Value(id), deleted: Value(boolOr(v, false))),
  },
);

/// Выполненные вхождения: поле op → колонки `completions`.
TableProjector<$CompletionsTable, CompletionRow> completionProjector(
  AppDatabase db, {
  void Function(String message)? warn,
}) => TableProjector(
  db: db,
  entityType: EntityTypes.completion,
  table: db.completions,
  warn: warn,
  writers: {
    CompletionFields.taskId: (id, v) =>
        CompletionsCompanion(id: Value(id), taskId: Value(textOrNull(v))),
    CompletionFields.dueWas: (id, v) =>
        CompletionsCompanion(id: Value(id), dueWas: Value(textOrNull(v))),
    CompletionFields.completedAt: (id, v) =>
        CompletionsCompanion(id: Value(id), completedAt: Value(textOrNull(v))),
    CompletionFields.deleted: (id, v) =>
        CompletionsCompanion(id: Value(id), deleted: Value(boolOr(v, false))),
  },
);

/// Настройки вида: поле op → колонки `view_options`. Незнакомое значение
/// (группировка `assignee`) ложится как есть — домен читает его как значение
/// по умолчанию.
TableProjector<$ViewOptionsTable, ViewOptionsRow> viewOptionsProjector(
  AppDatabase db, {
  void Function(String message)? warn,
}) => TableProjector(
  db: db,
  entityType: EntityTypes.viewOptions,
  table: db.viewOptions,
  warn: warn,
  writers: {
    ViewOptionsFields.viewType: (id, v) =>
        ViewOptionsCompanion(id: Value(id), viewType: Value(textOrNull(v))),
    ViewOptionsFields.objectId: (id, v) =>
        ViewOptionsCompanion(id: Value(id), objectId: Value(textOrNull(v))),
    ViewOptionsFields.groupedBy: (id, v) =>
        ViewOptionsCompanion(id: Value(id), groupedBy: Value(textOrNull(v))),
    ViewOptionsFields.sortedBy: (id, v) =>
        ViewOptionsCompanion(id: Value(id), sortedBy: Value(textOrNull(v))),
    ViewOptionsFields.sortOrder: (id, v) =>
        ViewOptionsCompanion(id: Value(id), sortOrder: Value(textOrNull(v))),
    ViewOptionsFields.showCompletedTasks: (id, v) => ViewOptionsCompanion(
      id: Value(id),
      showCompletedTasks: Value(boolOr(v, false)),
    ),
    ViewOptionsFields.filteredBy: (id, v) =>
        ViewOptionsCompanion(id: Value(id), filteredBy: Value(textOrNull(v))),
    ViewOptionsFields.deleted: (id, v) =>
        ViewOptionsCompanion(id: Value(id), deleted: Value(boolOr(v, false))),
  },
);
