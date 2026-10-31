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

    /// Срок текстом, как его ввёл пользователь («каждый пн»).
    String? string,

    /// Язык, на котором разобран [string]: `ru` или `en`.
    String? lang,

    /// Правило повторения; `null` — срок не повторяется.
    RecurrenceRule? rule,
  }) = _Due;

  const Due._();

  /// Повторяющийся срок — у него есть правило (как `is_recurring` Todoist).
  bool get isRecurring => rule != null;
}

/// Правило повторения срока: следующую дату по нему считает устройство,
/// отметившее выполнение (решение 1 плана M3).
@freezed
abstract class RecurrenceRule with _$RecurrenceRule {
  const factory RecurrenceRule({
    /// Непустой список строк RRULE (RFC 5545) без DTSTART; конец серии —
    /// `UNTIL`. Несколько правил — следующее вхождение по ближайшему.
    required List<String> rrule,

    /// `every!`: следующее вхождение — от даты выполнения, а не от срока.
    required bool fromCompletion,
  }) = _RecurrenceRule;
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
