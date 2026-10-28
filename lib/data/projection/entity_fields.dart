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

  /// Метка задачи: связь многие ко многим с id [taskLabelId].
  static const String taskLabel = 'task_label';

  /// Настройки пользователя — одна сущность [settingsEntityId] без таблицы:
  /// поля читаются из `field_versions` (SYNC_DESIGN «Специальные случаи»).
  static const String settings = 'settings';
}

/// Id сущности настроек — один на всех устройствах, как [inboxProjectId]:
/// иначе каждое устройство завело бы свои настройки, и они бы не сошлись.
const String settingsEntityId = '00000000-0000-8000-8000-000000000002';

/// Id связи «задача — метка»: один и тот же на всех устройствах. Две
/// установки одной метки офлайн пишут одну сущность одинаковыми значениями —
/// это не конфликт; снятие метки — tombstone этой сущности.
String taskLabelId(String taskId, String labelId) =>
    uuidV8([EntityTypes.taskLabel, taskId, labelId]);

/// Id метки, созданной заново вместо удалённой [labelId], когда задачу с ней
/// вернули в работу: один и тот же на всех устройствах. Два устройства,
/// вернувшие офлайн задачи с одной удалённой меткой, пишут одну метку
/// одинаковыми значениями, а не две. Если и эта метка уже есть (удалена или
/// переименована), берётся следующий id цепочки — от неё.
String revivedLabelId(String labelId) =>
    uuidV8([EntityTypes.label, 'revived', labelId]);

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

/// Поля, параллельная правка которых не конфликт: порядок, свёрнутость и
/// дата выполнения (задачу завершили на двух устройствах — спорить о минуте
/// незачем) пользователю выбирать незачем, LWW решает сам. Имена полей общие
/// для всех типов сущностей. Правило — SYNC_DESIGN «Конфликты».
const Set<String> silentFields = {
  TaskFields.orderKey,
  TaskFields.isCollapsed,
  TaskFields.completedAt,
};

/// Поля-объекты и ключи, которые знает эта версия приложения. При правке
/// известные ключи заменяются новым значением, а незнакомые сохраняются из
/// текущего: так не теряется, например, правило повторения от более новой
/// версии. Новый ключ срока (правило повторения, M3) — добавить сюда (docs/OBLIGATIONS.md, О-7).
const Map<String, Map<String, Set<String>>> mergedObjectFields = {
  EntityTypes.task: {
    TaskFields.due: {DueKeys.date, DueKeys.time, DueKeys.tz},
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
  static const String addedAt = 'added_at';
  static const String deleted = Op.deletedField;
}

/// Ключи объекта срока. Остальные ключи (например, правило повторения)
/// хранятся в op и `field_versions` как есть.
abstract final class DueKeys {
  static const String date = 'date';
  static const String time = 'time';
  static const String tz = 'tz';
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

/// Поля настроек.
abstract final class SettingsFields {
  /// Id темы (`taskly`) — строкой, а не числом `user.theme_id` Todoist API:
  /// темы Taskly в Todoist нет.
  static const String themeId = 'theme_id';

  /// Внешний вид: `light`, `dark` или `system`.
  static const String themeAppearance = 'theme_appearance';
}

/// Поля связи «задача — метка».
abstract final class TaskLabelFields {
  static const String taskId = 'task_id';
  static const String labelId = 'label_id';
  static const String deleted = Op.deletedField;
}
