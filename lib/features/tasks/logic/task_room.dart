import '../../../domain/models.dart';
import '../../../domain/rules.dart';
import '../../../domain/workspace.dart';

/// Место для активных задач в проекте — лимит help «Usage limits» (О-84).
abstract final class TaskRoom {
  /// В проект [projectId] приходят ещё [adding] активных задач: больше
  /// [Limits.activeTasksPerProject] — [RejectReason.tooManyTasks] (решение 3А
  /// «Часть M4.11» plans/m4). Проверяется только прирост: проект, уже
  /// переполненный синхронизацией, не мешает правкам и уходу задач.
  /// [already] — активные, добавленные прошлыми шагами того же действия
  /// после чтения [ws] (`_Steps` в task_core.dart).
  static void checkRoom(
    Workspace ws,
    String projectId,
    int adding, {
    int already = 0,
  }) {
    if (adding <= 0) return;
    if (ws.activeTaskCount(projectId) + already + adding >
        Limits.activeTasksPerProject) {
      throw const CommandRejected(RejectReason.tooManyTasks);
    }
  }

  /// Задачи поддеревьев [roots], которые активны, если корни встанут в
  /// активное место (О-81): незавершённые, у которых в поддереве нет
  /// завершённого предка; завершённый корень не даёт ни одной. [done] —
  /// завершена ли задача после действия (по умолчанию — как в снимке).
  static Set<String> openInTrees(
    Workspace ws,
    Iterable<String> roots, {
    bool Function(Task task)? done,
  }) {
    final isDone = done ?? (Task t) => t.isCompleted;
    final open = <String>{};
    final pending = [...roots];
    while (pending.isNotEmpty) {
      final task = ws.task(pending.removeLast());
      if (task == null || isDone(task) || !open.add(task.id)) continue;
      pending.addAll([for (final c in ws.children(task.id)) c.id]);
    }
    return open;
  }
}
