import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/models.dart';
import '../../domain/workspace.dart';
import '../app_database.dart';
import '../projection/due_rule.dart';
import '../projection/entity_fields.dart';

/// Чтение данных пользователя одним снимком [Workspace].
///
/// Снимок собирается целиком из таблиц-проекций в одной транзакции чтения, а
/// производные (каскад удаления, деревья, порядок) считает чистый Dart в
/// [Workspace]. Для личного списка дел (тысячи задач) это миллисекунды, зато
/// каждое представление — функция от снимка, без SQL на каждый экран.
/// Альтернатива — свой запрос на экран с рекурсивными CTE для каскада:
/// правила «что живо» пришлось бы повторять в каждом запросе.
final class WorkspaceRepository {
  WorkspaceRepository(this._db);

  final AppDatabase _db;

  /// Снимок сейчас и после каждого изменения таблиц сущностей.
  Stream<Workspace> watch() => _db
      .customSelect(
        'SELECT 1',
        readsFrom: {
          _db.projects,
          _db.sections,
          _db.labels,
          _db.tasks,
          _db.taskLabels,
        },
      )
      .watch()
      .asyncMap((_) => load());

  /// Текущий снимок.
  Future<Workspace> load() => _db.transaction(() async {
    final projects = await _db.select(_db.projects).get();
    final sections = await _db.select(_db.sections).get();
    final labels = await _db.select(_db.labels).get();
    final tasks = await _db.select(_db.tasks).get();
    final links = await (_db.select(
      _db.taskLabels,
    )..where((t) => t.deleted.equals(false))).get();
    // Время (HLC) удаления меток и завершения задач с ними — для правила
    // «удалённая метка видна на задаче, выполненной до удаления» (Workspace).
    // Читаются только нужные строки: по первичному ключу, а не все поля всех
    // задач на каждый снимок.
    final deletedLabelIds = {
      for (final l in labels)
        if (l.deleted) l.id,
    };
    final taskIds = {
      for (final link in links)
        if (deletedLabelIds.contains(link.labelId)) ?link.taskId,
    };
    final labelDeletedAt = await _versions(
      EntityTypes.label,
      deletedLabelIds,
      LabelFields.deleted,
    );
    final completedAt = await _versions(
      EntityTypes.task,
      taskIds,
      TaskFields.isCompleted,
    );

    final labelsOf = <String, List<String>>{};
    for (final link in links) {
      final (task, label) = (link.taskId, link.labelId);
      if (task != null && label != null) (labelsOf[task] ??= []).add(label);
    }
    return Workspace(
      projects: [
        for (final p in projects)
          if (!p.deleted) _project(p),
      ],
      sections: [
        for (final s in sections)
          if (!s.deleted) _section(s),
      ],
      labels: [
        for (final l in labels)
          if (!l.deleted) _label(l),
      ],
      deletedLabels: [
        for (final l in labels)
          if (l.deleted) _label(l),
      ],
      completionVersions: completedAt,
      labelDeletionVersions: labelDeletedAt,
      tasks: [
        for (final t in tasks)
          if (!t.deleted) _task(t, labelsOf[t.id] ?? const []),
      ],
      deletedProjectIds: {
        for (final p in projects)
          if (p.deleted) p.id,
      },
      deletedSectionIds: {
        for (final s in sections)
          if (s.deleted) s.id,
      },
      deletedTaskIds: {
        for (final t in tasks)
          if (t.deleted) t.id,
      },
    );
  });

  /// HLC поля [field] сущностей [ids] типа [entityType]: id → HLC.
  Future<Map<String, String>> _versions(
    String entityType,
    Set<String> ids,
    String field,
  ) async {
    if (ids.isEmpty) return const {};
    final rows =
        await (_db.select(_db.fieldVersions)..where(
              (v) =>
                  v.entityType.equals(entityType) &
                  v.entityId.isIn(ids) &
                  v.field.equals(field),
            ))
            .get();
    return {for (final v in rows) v.entityId: v.hlc};
  }

  static Project _project(ProjectRow r) => Project(
    id: r.id,
    name: r.name,
    color: r.color,
    parentId: r.parentId,
    orderKey: r.orderKey,
    isFavorite: r.isFavorite,
    isArchived: r.isArchived,
    isInbox: r.isInbox,
    viewStyle: r.viewStyle,
    isCollapsed: r.isCollapsed,
  );

  static Section _section(SectionRow r) => Section(
    id: r.id,
    name: r.name,
    projectId: r.projectId,
    orderKey: r.orderKey,
    isCollapsed: r.isCollapsed,
    isArchived: r.isArchived,
  );

  static Label _label(LabelRow r) => Label(
    id: r.id,
    name: r.name,
    color: r.color,
    orderKey: r.orderKey,
    isFavorite: r.isFavorite,
  );

  static Task _task(TaskRow r, List<String> labelIds) {
    final (dueDate, amount, unit) = (
      r.dueDate,
      r.durationAmount,
      r.durationUnit,
    );
    return Task(
      id: r.id,
      content: r.content,
      description: r.description,
      projectId: r.projectId,
      sectionId: r.sectionId,
      parentId: r.parentId,
      orderKey: r.orderKey,
      priority: r.priority,
      due: dueDate == null
          ? null
          : Due(
              date: dueDate,
              time: r.dueTime,
              tz: r.dueTz,
              string: r.dueString,
              lang: r.dueLang,
              rule: switch (r.dueRule) {
                // Колонку пишет только проектор — JSON уже проверен.
                final String json => recurrenceRuleOf(jsonDecode(json)),
                null => null,
              },
            ),
      deadline: r.deadlineDate,
      duration: amount == null || unit == null
          ? null
          : TaskDuration(amount: amount, unit: unit),
      isCollapsed: r.isCollapsed,
      isCompleted: r.isCompleted,
      completedAt: r.completedAt,
      addedAt: r.addedAt,
      labelIds: labelIds,
    );
  }
}
