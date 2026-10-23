import 'package:drift/drift.dart';

import '../app_database.dart';
import 'entity_fields.dart';
import 'projector.dart';

/// Версия набора полей [defaultRegistry]. Увеличивать при каждом изменении
/// полей или колонок проекторов: база переложит `field_versions` заново.
const int projectorVersion = 1;

/// Проекторы задач и проектов текущей версии приложения.
ProjectorRegistry defaultRegistry(
  AppDatabase db, {
  void Function(String message)? warn,
}) => ProjectorRegistry(projectorVersion, [
  taskProjector(db, warn: warn),
  projectProjector(db, warn: warn),
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
    TaskFields.due: _due,
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

/// Срок — объект {date, time?, tz?}; `null` — срока нет.
TasksCompanion _due(String id, Object? value) => switch (value) {
  null => TasksCompanion(
    id: Value(id),
    dueDate: const Value(null),
    dueTime: const Value(null),
    dueTz: const Value(null),
  ),
  final Map<String, Object?> due => TasksCompanion(
    id: Value(id),
    dueDate: Value(textOrNull(due[DueKeys.date])),
    dueTime: Value(textOrNull(due[DueKeys.time])),
    dueTz: Value(textOrNull(due[DueKeys.tz])),
  ),
  _ => throw ProjectionTypeError('объект срока', value),
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
    ProjectFields.deleted: (id, v) =>
        ProjectsCompanion(id: Value(id), deleted: Value(boolOr(v, false))),
  },
);
