import '../../../core/fractional_index.dart';
import '../../../data/projection/entity_fields.dart';
import '../../../domain/models.dart';
import '../../../domain/rules.dart';
import '../../../domain/workspace.dart';
import '../../../sync/mutator.dart';
import '../../tasks/logic/task_commands.dart';

/// Действия пользователя над проектами — всё через [Mutator].
///
/// «Входящие» защищены: их нельзя удалить, архивировать, переименовать,
/// перекрасить, вложить или сделать родителем ([RejectReason.inboxProtected]).
/// Вид («список», «доска») и свёрнутость менять можно.
final class ProjectCommands {
  ProjectCommands({
    required this._mutator,
    required this._read,
    required this._tasks,
  });

  final Mutator _mutator;
  final Future<Workspace> Function() _read;
  final TaskCommands _tasks;

  /// Создать проект в конце уровня [parentId]. Возвращает id.
  Future<String> add({
    required String name,
    String color = 'charcoal',
    String? parentId,
    bool isFavorite = false,
    String viewStyle = 'list',
  }) async {
    final text = _name(name);
    final ws = await _read();
    if (parentId != null) _checkParent(ws, parentId, height: 1);
    return _mutator.create(EntityTypes.project, {
      ProjectFields.name: text,
      ProjectFields.color: color,
      ProjectFields.parentId: ?parentId,
      ProjectFields.orderKey: keyAtEnd([
        for (final p in ws.childProjects(parentId)) p.orderKey,
      ]),
      ProjectFields.isFavorite: isFavorite,
      ProjectFields.viewStyle: viewStyle,
    });
  }

  Future<void> rename(String id, String name) async {
    final text = _name(name);
    await _update(id, {ProjectFields.name: text}, protectInbox: true);
  }

  Future<void> setColor(String id, String color) =>
      _update(id, {ProjectFields.color: color}, protectInbox: true);

  Future<void> setFavorite(String id, bool favorite) =>
      _update(id, {ProjectFields.isFavorite: favorite}, protectInbox: true);

  /// `list`, `board` или `calendar`.
  Future<void> setViewStyle(String id, String viewStyle) =>
      _update(id, {ProjectFields.viewStyle: viewStyle});

  /// Свернуть или развернуть подпроекты в сайдбаре.
  Future<void> setCollapsed(String id, bool collapsed) =>
      _update(id, {ProjectFields.isCollapsed: collapsed});

  /// Перенести проект с подпроектами под [parentId] (`null` — верхний
  /// уровень), в конец уровня.
  Future<Undo> move(String id, {String? parentId}) async {
    final ws = await _read();
    _alive(ws, id, protectInbox: true);
    if (parentId != null) {
      if (ws.projectSubtree(id).contains(parentId)) {
        throw const CommandRejected(RejectReason.cycle);
      }
      _checkParent(ws, parentId, height: ws.projectHeight(id));
    }
    final siblings = [
      for (final p in ws.childProjects(parentId))
        if (p.id != id) p,
    ];
    final undo = await _mutator.capture([
      (
        entityType: EntityTypes.project,
        entityId: id,
        fields: {ProjectFields.parentId, ProjectFields.orderKey},
      ),
    ]);
    await _mutator.update(EntityTypes.project, id, {
      ProjectFields.parentId: parentId,
      ProjectFields.orderKey: keyAtEnd([for (final p in siblings) p.orderKey]),
    });
    return undo;
  }

  /// Архивировать — подпроекты уходят в архив вместе с ним.
  Future<void> archive(String id) =>
      _update(id, {ProjectFields.isArchived: true}, protectInbox: true);

  Future<void> unarchive(String id) =>
      _update(id, {ProjectFields.isArchived: false}, protectInbox: true);

  /// Удалить (tombstone): подпроекты, разделы и задачи скрываются с ним.
  Future<void> delete(String id) async {
    _alive(await _read(), id, protectInbox: true);
    await _mutator.delete(EntityTypes.project, id);
  }

  /// Дубликат сразу после проекта: поля, кроме избранного, активные разделы,
  /// незавершённые задачи с подзадачами. Подпроекты не копируются (в Todoist
  /// их дублируют по одному). [name] — имя копии из интерфейса («Копия …»).
  Future<String> duplicate(String id, {required String name}) async {
    final ws = await _read();
    final source = _alive(ws, id, protectInbox: true);
    // Действующий родитель, а не записанный: записанный мог ещё не прийти
    // или быть отброшен разрывом цикла.
    final parentId = ws.projectParent(id);
    final siblings = ws.childProjects(parentId);
    final index = siblings.indexWhere((p) => p.id == id);
    final keys = [for (final p in siblings) p.orderKey];
    return _mutator.batch(() async {
      final copy = await _mutator.create(EntityTypes.project, {
        ProjectFields.name: _name(name),
        ProjectFields.color: source.color,
        ProjectFields.parentId: ?parentId,
        ProjectFields.orderKey: index < 0
            ? keyAtEnd(keys)
            : keyForInsert(keys, index + 1),
        ProjectFields.viewStyle: source.viewStyle,
      });
      for (final task in ws.children(null, projectId: id)) {
        if (task.isCompleted) continue;
        await _tasks.copyTree(
          ws,
          task,
          projectId: copy,
          sectionId: null,
          parentId: null,
          orderKey: task.orderKey,
        );
      }
      for (final section in ws.sectionsOf(id)) {
        final sectionCopy = await _mutator.create(EntityTypes.section, {
          SectionFields.name: section.name,
          SectionFields.projectId: copy,
          SectionFields.orderKey: section.orderKey,
        });
        for (final task in ws.children(
          null,
          projectId: id,
          sectionId: section.id,
        )) {
          if (task.isCompleted) continue;
          await _tasks.copyTree(
            ws,
            task,
            projectId: copy,
            sectionId: sectionCopy,
            parentId: null,
            orderKey: task.orderKey,
          );
        }
      }
      return copy;
    });
  }

  // --- Внутреннее ---

  void _checkParent(Workspace ws, String parentId, {required int height}) {
    final parent = ws.project(parentId);
    if (parent == null) throw const CommandRejected(RejectReason.notFound);
    if (parent.isInbox) {
      throw const CommandRejected(RejectReason.inboxProtected);
    }
    if (ws.projectDepth(parentId) + height > Limits.projectLevels) {
      throw const CommandRejected(RejectReason.tooDeep);
    }
  }

  Future<void> _update(
    String id,
    Map<String, Object?> fields, {
    bool protectInbox = false,
  }) async {
    _alive(await _read(), id, protectInbox: protectInbox);
    await _mutator.update(EntityTypes.project, id, fields);
  }

  static Project _alive(Workspace ws, String id, {bool protectInbox = false}) {
    final project = ws.project(id);
    if (project == null) throw const CommandRejected(RejectReason.notFound);
    if (protectInbox && project.isInbox) {
      throw const CommandRejected(RejectReason.inboxProtected);
    }
    return project;
  }

  static String _name(String name) {
    final text = name.trim();
    if (text.isEmpty) throw const CommandRejected(RejectReason.emptyName);
    return text;
  }
}
