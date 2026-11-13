import '../../../core/fractional_index.dart';
import '../../../data/projection/entity_fields.dart';
import '../../../domain/models.dart';
import '../../../domain/rules.dart';
import '../../../domain/view_options.dart';
import '../../../domain/workspace.dart';
import '../../../sync/mutator.dart';
import '../../tasks/logic/task_commands.dart';
import '../../views/logic/view_options_commands.dart';

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
    required this._views,
  });

  final Mutator _mutator;
  final Future<Workspace> Function() _read;
  final TaskCommands _tasks;
  final ViewOptionsCommands _views;

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
    _checkRoom(ws, 1);
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

  /// Описание (help «Introduction to projects»): до [Limits.description]
  /// символов; у «Входящих» описания нет (допущение О-69). Хранится как
  /// введено, как у задачи: пробелы по краям — часть markdown (блок кода
  /// отступом); текст только из пробелов — пустое описание.
  Future<void> setDescription(String id, String description) async {
    final text = description.trim().isEmpty ? '' : description;
    Limits.checkLength(text, Limits.description);
    await _update(id, {ProjectFields.description: text}, protectInbox: true);
  }

  Future<void> setFavorite(String id, bool favorite) =>
      _update(id, {ProjectFields.isFavorite: favorite}, protectInbox: true);

  /// `list`, `board` или `calendar`.
  Future<void> setViewStyle(String id, String viewStyle) =>
      _update(id, {ProjectFields.viewStyle: viewStyle});

  /// Свернуть или развернуть подпроекты в сайдбаре.
  Future<void> setCollapsed(String id, bool collapsed) =>
      _update(id, {ProjectFields.isCollapsed: collapsed});

  /// Перенести проект с подпроектами под [parentId] (`null` — верхний
  /// уровень), в конец уровня. Родитель в архиве (убран на другом
  /// устройстве) — [RejectReason.notFound], как в [reorder]. Снимок, запись
  /// и «Отменить» — в одной транзакции.
  Future<Undo> move(String id, {String? parentId}) => _mutator.batch(() async {
    final ws = await _read();
    _alive(ws, id, protectInbox: true);
    if (parentId != null) {
      if (ws.projectSubtree(id).contains(parentId)) {
        throw const CommandRejected(RejectReason.cycle);
      }
      _checkParent(ws, parentId, height: ws.projectHeight(id));
      if (ws.isProjectArchived(parentId)) {
        throw const CommandRejected(RejectReason.notFound);
      }
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
  });

  /// Перетаскивание проекта: сразу после [afterId] (`null` — первым) на уровне
  /// [parentId] (`null` — верхний), с подпроектами. Проект перетаскивается сам,
  /// без ручки; уровень — сдвигом, три уровня (help «Introduction to
  /// projects», «Create a sub-project»). Родитель пишется, только если
  /// записанный отличается от [parentId]: действующий может совпасть с целью
  /// при другом записанном — цикл, разорванный после правок двух устройств, —
  /// и без записи цикл вернулся бы, как только второй проект уйдёт из-под
  /// первого. Равные ключи соседей разводятся здесь же (О-8). Без «Отменить»:
  /// help говорит о нём только у задач (решение 8 плана M4).
  Future<void> reorder(String id, {String? parentId, String? afterId}) =>
      _mutator.batch(() async {
        final ws = await _read();
        _alive(ws, id, protectInbox: true);
        if (parentId != null) {
          if (ws.projectSubtree(id).contains(parentId)) {
            throw const CommandRejected(RejectReason.cycle);
          }
          _checkParent(ws, parentId, height: ws.projectHeight(id));
          if (ws.isProjectArchived(parentId)) {
            throw const CommandRejected(RejectReason.notFound);
          }
        }
        final level = [
          for (final p in ws.childProjects(parentId))
            if (!p.isInbox) p,
        ];
        final others = [
          for (final p in level)
            if (p.id != id) p,
        ];
        final after = others.indexWhere((p) => p.id == afterId);
        final index = afterId == null
            ? 0
            : after < 0
            ? others.length
            : after + 1;
        final staleParent = ws.project(id)!.parentId != parentId;
        if (ws.projectParent(id) == parentId &&
            level.indexWhere((p) => p.id == id) == index) {
          if (staleParent) {
            await _mutator.update(EntityTypes.project, id, {
              ProjectFields.parentId: parentId,
            });
          }
          return;
        }
        final keys = insertionKeys(
          [for (final p in others) p.orderKey],
          index,
          1,
        );
        for (final (i, key) in keys.rekeyed.indexed) {
          if (key == null) continue;
          await _mutator.update(EntityTypes.project, others[i].id, {
            ProjectFields.orderKey: key,
          });
        }
        await _mutator.update(EntityTypes.project, id, {
          if (staleParent) ProjectFields.parentId: parentId,
          ProjectFields.orderKey: keys.inserted.single,
        });
      });

  /// Архивировать — подпроекты уходят в архив вместе с ним.
  Future<void> archive(String id) =>
      _update(id, {ProjectFields.isArchived: true}, protectInbox: true);

  /// Вернуть из архива — как `project_unarchive` в Todoist API: предки не
  /// возвращаются. Если предок в архиве, проект возвращается один,
  /// становится корневым и встаёт в конец корневых проектов.
  Future<void> unarchive(String id) async {
    final ws = await _read();
    final project = _alive(ws, id, protectInbox: true);
    final parent = ws.projectParent(id);
    final ancestorArchived = parent != null && ws.isProjectArchived(parent);
    // Не в архиве — не пишем ничего: op `is_archived=false` на поле, которого
    // ещё не было, спорила бы с параллельным архивом на другом устройстве.
    if (!project.isArchived && !ancestorArchived) return;
    // Возвращаются проект и подпроекты, у которых до него нет своего архива
    // (подпроект в архиве — сам и с потомками — остаётся там).
    bool returns(String p) {
      for (String? q = p; q != null && q != id; q = ws.projectParent(q)) {
        if (ws.project(q)!.isArchived) return false;
      }
      return true;
    }

    _checkRoom(ws, ws.projectSubtree(id).where(returns).length);
    if (!ancestorArchived) {
      await _mutator.update(EntityTypes.project, id, {
        ProjectFields.isArchived: false,
      });
      return;
    }
    await _mutator.update(EntityTypes.project, id, {
      ProjectFields.isArchived: false,
      ProjectFields.parentId: null,
      ProjectFields.orderKey: keyAtEnd([
        for (final p in ws.childProjects(null)) p.orderKey,
      ]),
    });
  }

  /// Удалить (tombstone): подпроекты, разделы и задачи скрываются с ним.
  Future<void> delete(String id) async {
    _alive(await _read(), id, protectInbox: true);
    await _mutator.delete(EntityTypes.project, id);
  }

  /// Дубликат сразу после проекта: поля (кроме избранного) с описанием,
  /// «Отображение», активные разделы, незавершённые задачи с подзадачами.
  /// Подпроекты не копируются (в Todoist их дублируют по одному). [name] —
  /// имя копии из
  /// интерфейса («Копия …»).
  Future<String> duplicate(String id, {required String name}) => _mutator.batch(
    () async {
      final ws = await _read();
      final source = _alive(ws, id, protectInbox: true);
      _checkRoom(ws, 1);
      // Действующий родитель, а не записанный: записанный мог ещё не прийти
      // или быть отброшен разрывом цикла.
      final parentId = ws.projectParent(id);
      final siblings = ws.childProjects(parentId);
      final index = siblings.indexWhere((p) => p.id == id);
      final keys = [for (final p in siblings) p.orderKey];
      final copy = await _mutator.create(EntityTypes.project, {
        ProjectFields.name: _name(Limits.clip(name.trim(), Limits.projectName)),
        ProjectFields.color: source.color,
        ProjectFields.parentId: ?parentId,
        ProjectFields.orderKey: index < 0
            ? keyAtEnd(keys)
            : keyForInsert(keys, index + 1),
        ProjectFields.viewStyle: source.viewStyle,
        // Описание копируется (help «Introduction to projects»: «Project
        // description» — в списке «Included»).
        if (source.description.isNotEmpty)
          ProjectFields.description: source.description,
      });
      await _views.copy(ViewType.project, id, copy);
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
    },
  );

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
    return Limits.checkLength(text, Limits.projectName);
  }

  /// Активных проектов стало бы больше [Limits.activeProjects] —
  /// [RejectReason.tooManyProjects] (решение 3А «Часть M4.11» plans/m4).
  static void _checkRoom(Workspace ws, int adding) {
    if (ws.activeProjectCount + adding > Limits.activeProjects) {
      throw const CommandRejected(RejectReason.tooManyProjects);
    }
  }
}
