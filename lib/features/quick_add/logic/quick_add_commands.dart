import '../../../domain/workspace.dart';
import '../../../sync/mutator.dart';
import '../../labels/logic/label_commands.dart';
import '../../projects/logic/project_commands.dart';
import '../../tasks/logic/task_commands.dart';
import 'quick_add_draft.dart';

/// Запись быстрого добавления: недостающие проекты и метки создаются вместе
/// с задачами одной транзакцией (план M3.6): сбой не оставит проект без
/// задачи, ради которой его создавали.
final class QuickAddCommands {
  QuickAddCommands({
    required this._mutator,
    required this._read,
    required this._tasks,
    required this._projects,
    required this._labels,
  });

  final Mutator _mutator;
  final Future<Workspace> Function() _read;
  final TaskCommands _tasks;
  final ProjectCommands _projects;
  final LabelCommands _labels;

  /// Добавить задачи [drafts] по порядку (вставка нескольких строк — все
  /// разом). [atTop] — в начало места, иначе в конец. Одинаковое новое имя
  /// у нескольких задач создаёт один проект или одну метку; имя, которое
  /// уже появилось (пришло синхронизацией, пока окно было открыто), —
  /// существующее. Возвращает id задач.
  Future<List<String>> add(List<TaskDraft> drafts, {bool atTop = false}) =>
      _mutator.batch(() async {
        final ws = await _read();
        final projects = <String, String>{};
        final labels = <String, String>{};
        final ids = <String>[];
        // Задачи вверху места — в порядке строк: каждая следующая — после
        // предыдущей, а не над ней.
        String? previous;
        for (final d in drafts) {
          final projectId =
              d.projectId ?? await _projectFor(ws, d.newProject!, projects);
          final labelIds = {...d.labelIds};
          for (final name in d.newLabels) {
            labelIds.add(await _labelFor(ws, name, labels));
          }
          final id = await _tasks.add(
            content: d.title,
            description: d.description,
            projectId: d.parentId == null ? projectId : null,
            sectionId: d.parentId == null ? d.sectionId : null,
            parentId: d.parentId,
            afterId: atTop ? previous : null,
            atTop: atTop && previous == null,
            priority: d.priority,
            due: d.due,
            deadline: d.deadline,
            duration: d.duration,
            labelIds: labelIds,
          );
          ids.add(id);
          previous = id;
        }
        return ids;
      });

  Future<String> _projectFor(
    Workspace ws,
    String name,
    Map<String, String> created,
  ) async {
    final key = name.trim().toLowerCase();
    final existing = findProject(ws, name);
    if (existing != null) return existing.id;
    return created[key] ??= await _projects.add(name: name);
  }

  Future<String> _labelFor(
    Workspace ws,
    String name,
    Map<String, String> created,
  ) async {
    final key = name.trim().toLowerCase();
    final existing = findLabel(ws, name);
    if (existing != null) return existing.id;
    return created[key] ??= await _labels.add(name: name);
  }
}
