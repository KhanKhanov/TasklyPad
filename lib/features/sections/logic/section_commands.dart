import '../../../core/fractional_index.dart';
import '../../../data/projection/entity_fields.dart';
import '../../../domain/models.dart';
import '../../../domain/rules.dart';
import '../../../domain/workspace.dart';
import '../../../sync/mutator.dart';
import '../../tasks/logic/task_commands.dart';

/// Действия пользователя над разделами — всё через [Mutator].
final class SectionCommands {
  SectionCommands({
    required this._mutator,
    required this._read,
    required this._tasks,
  });

  final Mutator _mutator;
  final Future<Workspace> Function() _read;
  final TaskCommands _tasks;

  /// Добавить раздел в проект: после раздела [afterId] или в конец.
  Future<String> add(
    String projectId, {
    required String name,
    String? afterId,
  }) async {
    final text = _name(name);
    final ws = await _read();
    if (ws.project(projectId) == null) {
      throw const CommandRejected(RejectReason.notFound);
    }
    final all = [
      ...ws.sectionsOf(projectId),
      ...ws.sectionsOf(projectId, archived: true),
    ];
    if (all.length >= Limits.sectionsPerProject) {
      throw const CommandRejected(RejectReason.tooManySections);
    }
    return _mutator.create(EntityTypes.section, {
      SectionFields.name: text,
      SectionFields.projectId: projectId,
      SectionFields.orderKey: _keyAfter(ws.sectionsOf(projectId), afterId),
    });
  }

  Future<void> rename(String id, String name) async {
    final text = _name(name);
    await _update(id, {SectionFields.name: text});
  }

  Future<void> setCollapsed(String id, bool collapsed) =>
      _update(id, {SectionFields.isCollapsed: collapsed});

  /// Архивировать: задачи раздела скрываются вместе с ним.
  Future<void> archive(String id) =>
      _update(id, {SectionFields.isArchived: true});

  Future<void> unarchive(String id) =>
      _update(id, {SectionFields.isArchived: false});

  /// Удалить (tombstone): задачи раздела скрываются вместе с ним.
  Future<void> delete(String id) async {
    _alive(await _read(), id);
    await _mutator.delete(EntityTypes.section, id);
  }

  /// Перенести раздел с задачами в конец проекта [projectId] («Перенести в…»).
  ///
  /// Пишется только проект раздела: проект задач в живом разделе вычисляется
  /// по разделу (Workspace). Поэтому задача, добавленная в этот раздел на
  /// другом устройстве до синхронизации, переезжает вместе с ним, а
  /// правки задач на другом устройстве не спорят с переносом.
  Future<Undo> moveToProject(String id, String projectId) async {
    final ws = await _read();
    _alive(ws, id);
    if (ws.project(projectId) == null) {
      throw const CommandRejected(RejectReason.notFound);
    }
    final undo = await _mutator.capture([
      (
        entityType: EntityTypes.section,
        entityId: id,
        fields: {SectionFields.projectId, SectionFields.orderKey},
      ),
    ]);
    await _mutator.update(EntityTypes.section, id, {
      SectionFields.projectId: projectId,
      SectionFields.orderKey: _keyAfter(ws.sectionsOf(projectId), null),
    });
    return undo;
  }

  /// Дубликат сразу после раздела, с незавершёнными задачами. [name] — имя
  /// копии из интерфейса («Копия …»).
  Future<String> duplicate(String id, {required String name}) async {
    final ws = await _read();
    final section = _alive(ws, id);
    final projectId = section.projectId ?? ws.inbox!.id;
    return _mutator.batch(() async {
      final copy = await _mutator.create(EntityTypes.section, {
        SectionFields.name: _name(name),
        SectionFields.projectId: projectId,
        SectionFields.orderKey: _keyAfter(ws.sectionsOf(projectId), id),
      });
      for (final task in ws.children(
        null,
        projectId: projectId,
        sectionId: id,
      )) {
        if (task.isCompleted) continue;
        await _tasks.copyTree(
          ws,
          task,
          projectId: projectId,
          sectionId: copy,
          parentId: null,
          orderKey: task.orderKey,
        );
      }
      return copy;
    });
  }

  // --- Внутреннее ---

  static String _keyAfter(List<Section> sections, String? afterId) {
    final i = afterId == null
        ? sections.length - 1
        : sections.indexWhere((s) => s.id == afterId);
    final keys = [for (final s in sections) s.orderKey];
    return i < 0 ? keyAtEnd(keys) : keyForInsert(keys, i + 1);
  }

  Future<void> _update(String id, Map<String, Object?> fields) async {
    _alive(await _read(), id);
    await _mutator.update(EntityTypes.section, id, fields);
  }

  static Section _alive(Workspace ws, String id) {
    final section = ws.section(id);
    if (section == null) throw const CommandRejected(RejectReason.notFound);
    return section;
  }

  static String _name(String name) {
    final text = name.trim();
    if (text.isEmpty) throw const CommandRejected(RejectReason.emptyName);
    return text;
  }
}
