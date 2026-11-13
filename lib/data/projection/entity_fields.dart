import 'package:oplog_sync/oplog_sync.dart';

// Типы сущностей и имена полей ops — один источник для проекторов и Mutator.
// Имена — как в Todoist API v1 (для импорта), кроме `order_key` (fractional
// index вместо целого порядка), `deleted` (tombstone) и `is_completed`.

/// Типы сущностей в журнале.
abstract final class EntityTypes {
  static const String task = 'task';
  static const String project = 'project';
  static const String section = 'section';
  static const String label = 'label';

  /// Сохранённый фильтр.
  static const String filter = 'filter';

  /// Метка задачи: связь многие ко многим с id [taskLabelId].
  static const String taskLabel = 'task_label';

  /// Настройки пользователя — одна сущность [settingsEntityId] без таблицы:
  /// поля читаются из `field_versions` (SYNC_DESIGN «Специальные случаи»).
  static const String settings = 'settings';

  /// Выполненное вхождение повторяющейся задачи с id [completionId].
  static const String completion = 'completion';

  /// Настройки вида («Отображение») с id [viewOptionsId].
  static const String viewOptions = 'view_options';
}

/// Типы сущностей, которые не дают конфликтов: спор о выполнении вхождения и
/// так виден конфликтом поля `due` задачи (решение 3 плана M3), а спор о виде
/// списка карточки не стоит (решение 1 плана M4).
const Set<String> silentEntityTypes = {
  EntityTypes.completion,
  EntityTypes.viewOptions,
};

/// Id настроек вида [viewType] объекта [objectId] (проект, метка; у
/// «Сегодня» и «Предстоящего» — `null`): один и тот же на всех устройствах,
/// поэтому настройки одного вида с двух устройств — одна сущность, а не две
/// (SYNC_DESIGN «Специальные случаи»). «Входящие» — `project` с
/// [inboxProjectId].
String viewOptionsId(String viewType, String? objectId) =>
    uuidV8([EntityTypes.viewOptions, viewType, objectId ?? '']);

/// Id записи о выполнении вхождения [dueWas] задачи [taskId]: один и тот же
/// на всех устройствах. Два устройства, отметившие одно вхождение офлайн,
/// пишут одну запись, а «Отменить» её удаляет (SYNC_DESIGN «Специальные
/// случаи»). [dueWas] — только из [dueWasOf].
String completionId(String taskId, String dueWas) =>
    uuidV8([EntityTypes.completion, taskId, dueWas]);

/// Срок вхождения для [completionId] и поля `due_was`: `YYYY-MM-DD` или
/// `YYYY-MM-DDTHH:MM` у срока со временем — иначе два вхождения одного дня
/// (`every hour`) дали бы одну запись. Пояс не входит: вхождения одной
/// задачи различаются стенным временем. Строка — часть id, менять формат
/// нельзя: записи одного вхождения на разных версиях раздвоились бы.
String dueWasOf(String date, String? time) =>
    time == null ? date : '${date}T$time';

/// Id сущности настроек — один на всех устройствах, как [inboxProjectId]:
/// иначе каждое устройство завело бы свои настройки, и они бы не сошлись.
const String settingsEntityId = '00000000-0000-8000-8000-000000000002';

/// Id связи «задача — метка»: один и тот же на всех устройствах. Две
/// установки одной метки офлайн пишут одну сущность одинаковыми значениями —
/// это не конфликт; снятие метки — tombstone этой сущности.
String taskLabelId(String taskId, String labelId) =>
    uuidV8([EntityTypes.taskLabel, taskId, labelId]);

/// Id метки с именем [name], созданной заново вместо удалённой [labelId],
/// когда задачу с ней вернули в работу: один и тот же на всех устройствах.
/// Два устройства, вернувшие офлайн задачи с одной удалённой меткой, пишут
/// одну метку одинаковыми значениями, а не две. Имя (без учёта регистра) —
/// часть id: в снимках задач одна метка может называться по-разному, и
/// каждое имя получает свою метку (решение 2А M4.2 в plans/m4). Если и эта
/// метка уже есть (удалена или переименована), берётся следующий id
/// цепочки — от неё.
String revivedLabelId(String labelId, String name) =>
    uuidV8([EntityTypes.label, 'revived', labelId, name.toLowerCase()]);

/// Id проекта «Входящие» — один на всех устройствах.
///
/// Случайный id дал бы каждому устройству свои «Входящие». Фиксированный id и
/// одинаковые значения полей при создании ([inboxProjectFields]) превращают
/// параллельное создание на двух устройствах в правку одинаковыми значениями,
/// а это не конфликт. Вид UUID версии 8 («свой алгоритм», RFC 9562).
const String inboxProjectId = '00000000-0000-8000-8000-000000000001';

/// Поля «Входящих» при создании — только неизменяемые. Имя одно на всех
/// языках, на экране его заменяет перевод (M2): разные имена дали бы
/// конфликт. Цвет и вид не пишутся: их умолчания уже в колонках таблицы, а
/// новое устройство, записав `view_style: list` до первой синхронизации,
/// откатило бы выбранную на другом устройстве доску и создало бы конфликт.
const Map<String, Object?> inboxProjectFields = {
  ProjectFields.name: 'Inbox',
  ProjectFields.isInbox: true,
};

/// Поля, параллельная правка которых не конфликт: порядок (и порядок дня),
/// свёрнутость, дата выполнения (задачу завершили на двух устройствах —
/// спорить о минуте незачем) и имена меток на момент завершения (пишутся
/// вместе с выполнением, спор о нём виден в `is_completed`) пользователю
/// выбирать незачем, LWW решает сам. Имена полей общие для всех типов
/// сущностей. Правило — SYNC_DESIGN «Конфликты».
const Set<String> silentFields = {
  TaskFields.orderKey,
  TaskFields.dayOrderKey,
  TaskFields.isCollapsed,
  TaskFields.completedAt,
  TaskFields.completedLabelNames,
};

/// Поля-объекты и ключи, которые знает эта версия приложения. При правке
/// известные ключи заменяются новым значением, а незнакомые сохраняются из
/// текущего: так не теряются ключи от более новой версии. Правило повторения
/// — известный ключ: команда, пишущая срок, передаёт его явно, а срок без
/// правила снимает повторение (решение 1 плана M3).
const Map<String, Map<String, Set<String>>> mergedObjectFields = {
  EntityTypes.task: {
    TaskFields.due: {
      DueKeys.date,
      DueKeys.time,
      DueKeys.tz,
      DueKeys.string,
      DueKeys.lang,
      DueKeys.rule,
      DueKeys.seriesTime,
    },
    TaskFields.deadline: {DeadlineKeys.date},
    TaskFields.duration: {DurationKeys.amount, DurationKeys.unit},
  },
};

/// Поля задачи.
abstract final class TaskFields {
  static const String content = 'content';
  static const String description = 'description';
  static const String projectId = 'project_id';
  static const String sectionId = 'section_id';
  static const String parentId = 'parent_id';
  static const String orderKey = 'order_key';

  /// Ручной порядок внутри дня в «Сегодня» и «Предстоящем» — fractional
  /// index вместо целого `day_order` Todoist API (решение 3 плана M4).
  static const String dayOrderKey = 'day_order_key';

  /// 1 = P1 (высший) … 4 = P4; в API Todoist шкала обратная.
  static const String priority = 'priority';

  /// Объект [DueKeys]: дата, время и таймзона меняются одной правкой, поэтому
  /// параллельная правка срока — один конфликт, а не смесь двух сроков.
  static const String due = 'due';

  /// Объект [DeadlineKeys] — как `deadline` в Todoist API.
  static const String deadline = 'deadline';

  /// Объект [DurationKeys]: число и единица меняются вместе.
  static const String duration = 'duration';
  static const String isCollapsed = 'is_collapsed';
  static const String isCompleted = 'is_completed';
  static const String completedAt = 'completed_at';

  /// Имена меток задачи на момент завершения — объект {id метки: имя}; когда
  /// пишется и снимается — SYNC_DESIGN «Специальные случаи». Имени поля в
  /// Todoist API нет — своё (решение 4 плана M4, О-41).
  static const String completedLabelNames = 'completed_label_names';
  static const String addedAt = 'added_at';
  static const String deleted = Op.deletedField;
}

/// Ключи объекта срока. Незнакомые ключи (от более новой версии) хранятся в
/// op и `field_versions` как есть.
abstract final class DueKeys {
  static const String date = 'date';
  static const String time = 'time';
  static const String tz = 'tz';

  /// Срок текстом, как его ввёл пользователь («каждый пн»), — как `string`
  /// в Todoist API; нужен экспорту CSV (M11).
  static const String string = 'string';

  /// Язык, на котором разобран [string] (`ru`, `en`).
  static const String lang = 'lang';

  /// Объект [RuleKeys]; есть — задача повторяющаяся. `is_recurring` Todoist
  /// не пишется: это «правило есть».
  static const String rule = 'rule';

  /// Время серии повторяющегося срока, когда «Время» перенесло только
  /// ближайшее вхождение: `HH:MM`, пустая строка — серия без времени, ключа
  /// нет — время серии равно [time] (решение 1А по О-65, SYNC_DESIGN
  /// «Проекции»).
  static const String seriesTime = 'series_time';
}

/// Ключи правила повторения в сроке. Набор закрыт: правило заменяется
/// целиком, и ключ, добавленный сюда более новой версией, эта стёрла бы —
/// расширения только новыми ключами [DueKeys] (SYNC_DESIGN «Проекции»).
abstract final class RuleKeys {
  /// Непустой список строк RRULE (RFC 5545) без DTSTART; конец серии —
  /// `UNTIL`. Несколько правил — для форм вроде `every 14 jan, 14 apr`.
  static const String rrule = 'rrule';

  /// `every!`: следующее вхождение считается от даты выполнения.
  static const String fromCompletion = 'from_completion';
}

/// Ключи объекта дедлайна.
abstract final class DeadlineKeys {
  static const String date = 'date';
}

/// Ключи объекта длительности.
abstract final class DurationKeys {
  static const String amount = 'amount';

  /// `minute` или `day`.
  static const String unit = 'unit';
}

/// Поля проекта.
abstract final class ProjectFields {
  static const String name = 'name';

  /// Описание — как `description` проекта в Todoist API.
  static const String description = TaskFields.description;
  static const String color = 'color';
  static const String parentId = 'parent_id';
  static const String orderKey = 'order_key';
  static const String isFavorite = 'is_favorite';
  static const String isArchived = 'is_archived';
  static const String isInbox = 'is_inbox';
  static const String viewStyle = 'view_style';
  static const String isCollapsed = TaskFields.isCollapsed;
  static const String deleted = Op.deletedField;
}

/// Поля раздела.
abstract final class SectionFields {
  static const String name = 'name';
  static const String projectId = 'project_id';
  static const String orderKey = 'order_key';
  static const String isCollapsed = TaskFields.isCollapsed;
  static const String isArchived = 'is_archived';
  static const String deleted = Op.deletedField;
}

/// Поля метки.
abstract final class LabelFields {
  static const String name = 'name';
  static const String color = 'color';
  static const String orderKey = 'order_key';
  static const String isFavorite = 'is_favorite';
  static const String deleted = Op.deletedField;
}

/// Поля сохранённого фильтра — имена как у фильтра в Todoist API (импорт
/// M11). Описание — как `description` проекта: в API фильтра его нет, а в
/// Todoist оно есть (help «Introduction to filters»).
abstract final class FilterFields {
  static const String name = 'name';

  /// Запрос текстом (TODOIST_SYNTAX §4).
  static const String query = 'query';
  static const String description = TaskFields.description;
  static const String color = 'color';
  static const String orderKey = 'order_key';
  static const String isFavorite = 'is_favorite';
  static const String deleted = Op.deletedField;
}

/// Поля настроек.
abstract final class SettingsFields {
  /// Id темы (`taskly`) — строкой, а не числом `user.theme_id` Todoist API:
  /// темы Taskly в Todoist нет.
  static const String themeId = 'theme_id';

  /// Внешний вид: `light`, `dark` или `system`.
  static const String themeAppearance = 'theme_appearance';

  /// «Умное распознавание дат» в быстром добавлении; поля нет — включено,
  /// как у нового аккаунта Todoist. Имени в Todoist API не нашли — своё.
  static const String smartDateRecognition = 'smart_date_recognition';

  /// «Сбрасывать подзадачи» повторяющейся задачи — имя как
  /// `reset_recurring_subtasks` в Todoist API (импорт M11); поля нет —
  /// выключено (решение 1А «Ход M3.4», О-57).
  static const String resetRecurringSubtasks = 'reset_recurring_subtasks';
}

/// Поля настроек вида — имена и значения как у `view_options` Todoist API.
/// Удаления нет: «Сбросить всё» пишет значения по умолчанию.
abstract final class ViewOptionsFields {
  /// `today`, `upcoming`, `project`, `label` или `filter` — часть
  /// [viewOptionsId].
  static const String viewType = 'view_type';

  /// Id проекта, метки или фильтра — часть [viewOptionsId].
  static const String objectId = 'object_id';
  static const String groupedBy = 'grouped_by';
  static const String sortedBy = 'sorted_by';
  static const String sortOrder = 'sort_order';
  static const String showCompletedTasks = 'show_completed_tasks';

  /// Запрос фильтра «Отображения» — как `filtered_by` в Todoist API.
  static const String filteredBy = 'filtered_by';
  static const String deleted = Op.deletedField;
}

/// Поля записи о выполнении вхождения.
abstract final class CompletionFields {
  static const String taskId = 'task_id';

  /// Срок выполненного вхождения — ключ [completionId].
  static const String dueWas = 'due_was';

  /// Момент выполнения, UTC ISO-8601.
  static const String completedAt = TaskFields.completedAt;

  /// «Отменить» в тосте — tombstone записи.
  static const String deleted = Op.deletedField;
}

/// Поля связи «задача — метка».
abstract final class TaskLabelFields {
  static const String taskId = 'task_id';
  static const String labelId = 'label_id';
  static const String deleted = Op.deletedField;
}
