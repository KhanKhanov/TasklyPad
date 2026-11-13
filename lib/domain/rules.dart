/// Ограничения Todoist (help: sub-tasks, sub-projects, sections, «Usage
/// limits»).
///
/// Уровни считаются как `INDENT` в CSV Todoist: 1 — верхний уровень. Все
/// лимиты проверяются только при записи с этого устройства; пришедшее с
/// другого устройства сверх них (после параллельных правок) показывается как
/// есть. Длина текста — в символах Unicode ([length]; решение 14А plans/m4).
///
/// Лимиты [activeTasksPerProject] и [labels] не проверяются и там, где
/// превышение — следствие уже сделанного, а не новая запись: сброс подзадач
/// при выполнении повторяющейся задачи, метки, создаваемые заново при
/// «Вернуть» и сбросе, и «Отменить» (решение 3А «Ход M4.13» plans/m4). Отказ
/// там не дал бы выполнить повторяющуюся задачу или отменить действие;
/// превышение показывается как есть — как пришедшее с другого устройства.
abstract final class Limits {
  /// Задача и подзадачи: «Todoist supports four indent levels».
  static const int taskLevels = 4;

  /// Проект и подпроекты: «three indent levels for personal projects».
  static const int projectLevels = 3;

  /// Разделов в одном проекте.
  static const int sectionsPerProject = 20;

  /// Меток на одной задаче (help «Usage limits»; где проверяется — plans/m4
  /// «Часть M4.11»).
  static const int labelsPerTask = 100;

  /// Меток всего (help «Usage limits»: «Labels per account»).
  static const int labels = 500;

  /// Активных задач в одном проекте вместе с подзадачами и повторяющимися
  /// (help: «doesn't increase on any plan»; решение 3А «Часть M4.11»).
  static const int activeTasksPerProject = 300;

  /// Активных (не в архиве) проектов вместе с «Входящими» и подпроектами.
  static const int activeProjects = 500;

  /// Название задачи.
  static const int taskContent = 500;

  /// Описание задачи и проекта (help «Introduction to projects»: «up to
  /// 16,383 characters»).
  static const int description = 16383;

  /// Имя проекта.
  static const int projectName = 120;

  /// Название раздела.
  static const int sectionName = 2048;

  /// Имя метки.
  static const int labelName = 60;

  /// Текст срока («каждый пн», «завтра 9:00»).
  static const int dueText = 150;

  /// Длительность задачи в минутах: «The maximum duration … is 24 hours».
  static const int durationMinutes = 24 * 60;

  /// Длина текста в символах Unicode (кодовых точках): эмодзи из одной
  /// кодовой точки — один символ, а не два, как в `String.length`.
  static int length(String text) => text.runes.length;

  /// [text] длиннее [max] символов — [RejectReason.tooLong].
  static String checkLength(String text, int max) {
    if (length(text) > max) throw const CommandRejected(RejectReason.tooLong);
    return text;
  }

  /// [text], обрезанный до [max] символов (имя копии «Копия …»).
  static String clip(String text, int max) =>
      length(text) <= max ? text : String.fromCharCodes(text.runes.take(max));
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

  /// Действие только для повторяющейся задачи («Отложить»).
  notRecurring,

  /// Правило повторения не разобрано (пришло битым с другого устройства):
  /// следующий срок не посчитать.
  brokenRecurrence,

  /// У задачи стало бы больше [Limits.labelsPerTask] меток.
  tooManyLabels,

  /// Текст длиннее своего лимита [Limits] (название, описание, имя).
  tooLong,

  /// Меток стало бы больше [Limits.labels].
  tooManyLabelsTotal,

  /// В проекте стало бы больше [Limits.activeTasksPerProject] активных задач.
  tooManyTasks,

  /// Активных проектов стало бы больше [Limits.activeProjects].
  tooManyProjects,

  /// Длительность больше [Limits.durationMinutes] или не больше нуля.
  badDuration,
}

/// Действие отклонено правилами — данные не изменены.
final class CommandRejected implements Exception {
  const CommandRejected(this.reason);

  final RejectReason reason;

  @override
  String toString() => 'CommandRejected(${reason.name})';
}
