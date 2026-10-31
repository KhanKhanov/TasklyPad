import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:logger/logger.dart';

import '../app_database.dart';
import 'due_rule.dart';
import 'entity_fields.dart';
import 'projector.dart';

/// Версия набора полей [defaultRegistry]. Увеличивать при каждом изменении
/// полей или колонок проекторов: база переложит `field_versions` заново.
const int projectorVersion = 3;

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
  taskLabelProjector(db, warn: warn),
  completionProjector(db, warn: warn),
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
    TaskFields.priority: (id, v) =>
        TasksCompanion(id: Value(id), priority: Value(intOr(v, 4))),
    TaskFields.due: (id, v) => _due(id, v, warn ?? _logger.w),
    TaskFields.deadline: _deadline,
    TaskFields.duration: _duration,
    TaskFields.isCollapsed: (id, v) =>
        TasksCompanion(id: Value(id), isCollapsed: Value(boolOr(v, false))),
    TaskFields.isCompleted: (id, v) =>
        TasksCompanion(id: Value(id), isCompleted: Value(boolOr(v, false))),
    TaskFields.completedAt: (id, v) =>
        TasksCompanion(id: Value(id), completedAt: Value(textOrNull(v))),
    TaskFields.addedAt: (id, v) =>
        TasksCompanion(id: Value(id), addedAt: Value(textOrNull(v))),
    TaskFields.deleted: (id, v) =>
        TasksCompanion(id: Value(id), deleted: Value(boolOr(v, false))),
  },
);

/// Срок — объект {date, time?, tz?, string?, lang?, rule?}; `null` — срока
/// нет. Неразобранные правило, текст или язык не отменяют дату: срок
/// остаётся, без них, и [warn] сообщает об этом; само значение остаётся в
/// `field_versions`. Повтор — только у срока с датой.
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
      );
    default:
      throw ProjectionTypeError('объект срока', value);
  }
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
