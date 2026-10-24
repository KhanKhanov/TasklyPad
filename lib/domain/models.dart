import 'package:freezed_annotation/freezed_annotation.dart';

part 'models.freezed.dart';

// Сущности, какими их видят интерфейс и логика: без tombstone и служебных
// полей журнала. Удалённые сущности сюда не попадают — их отсеивает
// [Workspace] (lib/domain/workspace.dart).

/// Проект. «Входящие» — проект с [isInbox].
@freezed
abstract class Project with _$Project {
  const factory Project({
    required String id,
    required String name,

    /// Имя цвета палитры Todoist (`berry_red` … `taupe`).
    required String color,
    String? parentId,
    required String orderKey,
    required bool isFavorite,
    required bool isArchived,
    required bool isInbox,

    /// `list`, `board` или `calendar`; незнакомое значение — как `list`.
    required String viewStyle,
    required bool isCollapsed,
  }) = _Project;
}

/// Раздел проекта.
@freezed
abstract class Section with _$Section {
  const factory Section({
    required String id,
    required String name,
    String? projectId,
    required String orderKey,
    required bool isCollapsed,
    required bool isArchived,
  }) = _Section;
}

/// Метка.
@freezed
abstract class Label with _$Label {
  const factory Label({
    required String id,
    required String name,
    required String color,
    required String orderKey,
    required bool isFavorite,
  }) = _Label;
}

/// Срок задачи: дата и, если задано, время. [tz] — IANA-таймзона; `null` —
/// «плавающее» время по часам устройства.
@freezed
abstract class Due with _$Due {
  const factory Due({
    /// `YYYY-MM-DD`.
    required String date,

    /// `HH:MM`; `null` — срок без времени («весь день»).
    String? time,
    String? tz,
  }) = _Due;
}

/// Длительность задачи, как в Todoist: число минут или дней.
@freezed
abstract class TaskDuration with _$TaskDuration {
  const factory TaskDuration({
    required int amount,

    /// `minute` или `day`.
    required String unit,
  }) = _TaskDuration;
}

/// Задача.
@freezed
abstract class Task with _$Task {
  const factory Task({
    required String id,
    required String content,
    required String description,

    /// `null` — «Входящие» (задача без проекта бывает, пока не пришла op).
    String? projectId,
    String? sectionId,
    String? parentId,
    required String orderKey,

    /// 1 = P1 (высший) … 4 = P4 (по умолчанию).
    required int priority,
    Due? due,

    /// Дедлайн — дата `YYYY-MM-DD`.
    String? deadline,
    TaskDuration? duration,
    required bool isCollapsed,
    required bool isCompleted,

    /// UTC ISO-8601.
    String? completedAt,
    String? addedAt,

    /// Живые метки задачи (id), по порядку меток.
    @Default(<String>[]) List<String> labelIds,
  }) = _Task;
}
