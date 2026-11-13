import '../../../core/clock.dart';
import '../../../core/fractional_index.dart';
import '../../../data/projection/entity_fields.dart';
import '../../../domain/models.dart';
import '../../../domain/recurrence.dart';
import '../../../domain/rules.dart';
import '../../../domain/view_options.dart';
import '../../../domain/view_order.dart';
import '../../../domain/workspace.dart';
import '../../../sync/mutator.dart';
import 'due_dates.dart';
import 'task_room.dart';

part 'task_completion.dart';
part 'task_core.dart';
part 'task_placement.dart';

/// Действия пользователя над задачами — всё через [Mutator].
///
/// Проверки правил (глубина, циклы) идут по свежему снимку [Workspace];
/// нарушение — [CommandRejected] до любой записи. Действия, у которых в
/// Todoist есть тост «Отменить» (завершение, перенос, смена срока),
/// возвращают [Undo]. Удаление — без отмены, как в Todoist.
///
/// Здесь — добавление и правка полей; выполнение и возврат в работу —
/// [_Completion] (task_completion.dart), место задач — [_Placement]
/// (task_placement.dart), общее — [_TaskCore] (task_core.dart), лимит
/// активных задач проекта — [TaskRoom] (О-84).
final class TaskCommands extends _TaskCore with _Completion, _Placement {
  TaskCommands({
    required Mutator mutator,
    required Future<Workspace> Function() read,
    required AppClock clock,
    required Future<bool> Function() resetRecurringSubtasks,
  }) : super(mutator, read, clock, resetRecurringSubtasks);

  /// Сколько выполненных прямых подзадач возвращает в работу выполнение
  /// повторяющейся задачи (help «Reset a sub-task»).
  static const int resetSubtasksLimit = 30;

  /// Срок повторяющегося [due] после «Отложить» в момент [now] (стенное
  /// время устройства): следующее будущее вхождение, просроченный — завтра со
  /// временем и правилом. `null` — серия закончилась, переносить некуда (в
  /// том числе просроченный). Битое правило — [CommandRejected]. Общая для
  /// [postpone] и даты у пункта «Отложить» в планировщике.
  static Due? postponedDue(Due due, DateTime now) {
    final following = _next(due, now, postpone: true);
    if (following == null) return null;
    final today = DateTime.utc(now.year, now.month, now.day);
    final dueAt = DateTime.parse('${due.date}T${due.time ?? '00:00'}:00Z');
    // Срок без времени просрочен со следующего дня, со временем — сразу.
    final overdue = due.time == null
        ? dueAt.isBefore(today)
        : dueAt.isBefore(now);
    // Просроченная — на завтра во время серии: это новое вхождение.
    return overdue
        ? withSeriesTime(due)
              .copyWith(date: isoDate(today.add(const Duration(days: 1))))
        : following;
  }

  /// Примет ли [setDue] срок [due] в момент [now] (стенное время): планировщик
  /// не предлагает правку, от которой команда откажет («Убрать время» у
  /// часового правила).
  static bool acceptsDue(Due due, DateTime now) {
    if (!due.isRecurring) return true;
    try {
      _next(due, now);
      return true;
    } on CommandRejected {
      return false;
    }
  }

  /// Добавить задачу. Место: подзадача [parentId], иначе раздел [sectionId]
  /// проекта [projectId] (`null` — «Входящие»); внутри — сразу после
  /// [afterId], в начало при [atTop] или в конец. Возвращает id.
  Future<String> add({
    required String content,
    String description = '',
    String? projectId,
    String? sectionId,
    String? parentId,
    String? afterId,
    bool atTop = false,
    int priority = 4,
    Due? due,
    String? deadline,
    TaskDuration? duration,
    Set<String> labelIds = const {},
  }) async {
    final text = _content(content);
    Limits.checkLength(description, Limits.description);
    Limits.checkDuration(duration);
    _checkDueText(due);
    if (labelIds.length > Limits.labelsPerTask) {
      throw const CommandRejected(RejectReason.tooManyLabels);
    }
    final ws = await _read();
    final place = _place(
      ws,
      projectId: projectId,
      sectionId: sectionId,
      parentId: parentId,
    );
    if (parentId != null && ws.taskDepth(parentId) + 1 > Limits.taskLevels) {
      throw const CommandRejected(RejectReason.tooDeep);
    }
    // Подзадача под выполненным родителем не активна и в лимит не идёт
    // (О-81); архивный проект, архивный раздел и родителя в них [_place] уже
    // отклонил.
    final placeActive = parentId == null || ws.isTaskActive(parentId);
    TaskRoom.checkRoom(ws, place.projectId, placeActive ? 1 : 0);
    final siblings = ws.children(
      parentId,
      projectId: place.projectId,
      sectionId: place.sectionId,
    );
    return _mutator.batch(() async {
      final id = await _mutator.create(EntityTypes.task, {
        TaskFields.content: text,
        if (description.isNotEmpty) TaskFields.description: description,
        TaskFields.projectId: place.projectId,
        TaskFields.sectionId: ?place.sectionId,
        TaskFields.parentId: ?parentId,
        TaskFields.orderKey: _keyFor(siblings, afterId: afterId, atTop: atTop),
        TaskFields.priority: priority,
        TaskFields.due: ?_dueValue(due),
        TaskFields.deadline: ?_deadlineValue(deadline),
        TaskFields.duration: ?_durationValue(duration),
        TaskFields.addedAt: _now(),
      });
      for (final label in labelIds) {
        await _link(id, label, linked: true);
      }
      return id;
    });
  }

  /// Изменить название.
  Future<void> rename(String id, String content) async {
    await _update(id, {TaskFields.content: _content(content)});
  }

  /// Название и срок одной правкой — дата, набранная в названии
  /// существующей задачи (решение 1А конца M3): [due] заменяет прежний срок
  /// вместе с правилом повторения (help «Introduction to recurring dates»);
  /// `null` — «без срока». Повторяющийся срок, который не примет расчёт, —
  /// отказ до записи, как у [setDue].
  Future<void> renameWithDue(String id, String content, Due? due) async {
    final text = _content(content);
    if (due != null && due.isRecurring) _next(due, _clock.nowWall());
    await _mutator.batch(() async {
      final task = await _alive(id);
      _checkDueText(due, task);
      await _mutator.update(EntityTypes.task, id, {
        TaskFields.content: text,
        ..._dueFields(task, due),
      });
    });
  }

  /// Описание до [Limits.description] символов.
  Future<void> setDescription(String id, String description) async {
    Limits.checkLength(description, Limits.description);
    await _update(id, {TaskFields.description: description});
  }

  /// Приоритет 1 (P1, высший) … 4 (P4). [snapshot] — снимок, уже
  /// прочитанный в той же транзакции (действие над выделенными): иначе
  /// каждая задача читала бы всю базу заново.
  Future<void> setPriority(String id, int priority, {Workspace? snapshot}) {
    RangeError.checkValueInInterval(priority, 1, 4, 'priority');
    return _update(id, {TaskFields.priority: priority}, snapshot);
  }

  /// Срок; `null` убирает срок. Повторяющийся срок, по которому расчёт не
  /// найдёт следующее вхождение (часовое правило без времени, битая строка
  /// правила), — [RejectReason.brokenRecurrence] до записи: иначе выполнение
  /// такой задачи отказало бы потом.
  @override
  Future<Undo> setDue(String id, Due? due, {Workspace? snapshot}) async {
    if (due != null && due.isRecurring) _next(due, _clock.nowWall());
    return _mutator.batch(() async {
      final task = await _alive(id, snapshot);
      _checkDueText(due, task);
      final undo = await _mutator.capture([_dueTarget(task, due)]);
      await _mutator.update(EntityTypes.task, id, _dueFields(task, due));
      return undo;
    });
  }

  /// «Перенести» у блока «Просрочено» (решение 10 плана M4): срок задач [ids]
  /// — на дату [date] одним действием с одним «Отменить». Время, пояс и
  /// правило повторения каждой задачи остаются, у повторяющейся переносится
  /// только вхождение — как дата из планировщика ([dueOnDate]); `null` —
  /// «Без срока» у всех. Меняются только задачи, просроченные в свежем
  /// снимке по стенным часам устройства: выполненная, удалённая, перенесённая
  /// или убранная в архив на другом устройстве, пока окно было открыто,
  /// остаётся как есть — правку, которой пользователь не видел, команда не
  /// пишет.
  Future<Undo> rescheduleOverdue(Iterable<String> ids, String? date) =>
      _mutator.batch(() async {
        final ws = await _read();
        final wanted = {...ids};
        final tasks = [
          for (final t in ws.overdueTasks(isoDate(_clock.nowWall())))
            if (wanted.contains(t.id)) t,
        ];
        Due? moved(Task t) => date == null ? null : dueOnDate(t.due, date);
        final undo = await _mutator.capture([
          for (final t in tasks) _dueTarget(t, moved(t)),
        ]);
        for (final t in tasks) {
          await _mutator.update(
            EntityTypes.task,
            t.id,
            _dueFields(t, moved(t)),
          );
        }
        return undo;
      });

  /// Дедлайн `YYYY-MM-DD`; `null` убирает.
  Future<void> setDeadline(String id, String? date, {Workspace? snapshot}) =>
      _update(id, {TaskFields.deadline: _deadlineValue(date)}, snapshot);

  /// Длительность от 1 минуты до 24 часов ([Limits.checkDuration]);
  /// `null` убирает.
  Future<void> setDuration(String id, TaskDuration? duration) async {
    Limits.checkDuration(duration);
    await _update(id, {TaskFields.duration: _durationValue(duration)});
  }

  /// Свернуть или развернуть подзадачи.
  Future<void> setCollapsed(String id, bool collapsed) =>
      _update(id, {TaskFields.isCollapsed: collapsed});

  /// Метки задачи ровно [labelIds]: недостающие ставятся, лишние снимаются.
  /// Удалённая метка выполненной задачи в выборе не участвует и остаётся.
  Future<void> setLabels(
    String id,
    Set<String> labelIds, {
    Workspace? snapshot,
  }) async {
    final ws = snapshot ?? await _read();
    final task = await _alive(id, ws);
    final current = {
      for (final l in task.labelIds)
        if (ws.label(l) != null) l,
    };
    final wanted = {
      for (final l in labelIds)
        if (ws.label(l) != null) l,
    };
    // Сверх лимита только добавлять нельзя: пришедшие синхронизацией лишние
    // метки снимать можно.
    if (wanted.difference(current).isNotEmpty &&
        wanted.length > Limits.labelsPerTask) {
      throw const CommandRejected(RejectReason.tooManyLabels);
    }
    await _mutator.batch(() async {
      for (final label in wanted.difference(current)) {
        await _link(id, label, linked: true);
      }
      for (final label in current.difference(wanted)) {
        await _link(id, label, linked: false);
      }
    });
  }

  /// Удалить (tombstone). Подзадачи скрываются вместе с задачей.
  Future<void> delete(String id, {Workspace? snapshot}) async {
    await _alive(id, snapshot);
    await _mutator.delete(EntityTypes.task, id);
  }
}
