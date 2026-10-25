import '../../domain/models.dart';
import '../../domain/workspace.dart';
import '../app_database.dart';

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
          : Due(date: dueDate, time: r.dueTime, tz: r.dueTz),
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
