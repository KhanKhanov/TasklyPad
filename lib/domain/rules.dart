/// Ограничения Todoist (help: sub-tasks, sub-projects, sections).
///
/// Уровни считаются как `INDENT` в CSV Todoist: 1 — верхний уровень. Они
/// проверяются только при записи с этого устройства; пришедшее с другого
/// устройства глубже (после параллельных переносов) показывается как есть.
abstract final class Limits {
  /// Задача и подзадачи: «Todoist supports four indent levels».
  static const int taskLevels = 4;

  /// Проект и подпроекты: «three indent levels for personal projects».
  static const int projectLevels = 3;

  /// Разделов в одном проекте.
  static const int sectionsPerProject = 20;
}

/// Почему действие не выполнено. Интерфейс показывает текст по причине.
enum RejectReason {
  /// Пустое имя или название.
  emptyName,

  /// «Входящие» нельзя удалить, архивировать, переименовать, перекрасить,
  /// вложить в другой проект или сделать родителем подпроекта.
  inboxProtected,

  /// Превышена вложенность [Limits].
  tooDeep,

  /// Элемент нельзя вложить в самого себя или своего потомка.
  cycle,

  /// В проекте уже [Limits.sectionsPerProject] разделов.
  tooManySections,

  /// Метка с таким именем уже есть.
  duplicateName,

  /// Сущности нет (удалена, в том числе на другом устройстве).
  notFound,
}

/// Действие отклонено правилами — данные не изменены.
final class CommandRejected implements Exception {
  const CommandRejected(this.reason);

  final RejectReason reason;

  @override
  String toString() => 'CommandRejected(${reason.name})';
}
