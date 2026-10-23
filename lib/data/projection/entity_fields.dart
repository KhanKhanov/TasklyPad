import 'package:oplog_sync/oplog_sync.dart';

// Типы сущностей и имена полей ops — один источник для проекторов и Mutator.
// Имена — как в Todoist API v1 (для импорта), кроме `order_key` (fractional
// index вместо целого порядка), `deleted` (tombstone) и `is_completed`.

/// Типы сущностей в журнале.
abstract final class EntityTypes {
  static const String task = 'task';
  static const String project = 'project';
}

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
  static const String deleted = Op.deletedField;
}
