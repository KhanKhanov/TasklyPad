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
import 'duration_text.dart';

/// Действия пользователя над задачами — всё через [Mutator].
///
/// Проверки правил (глубина, циклы) идут по свежему снимку [Workspace];
/// нарушение — [CommandRejected] до любой записи. Действия, у которых в
/// Todoist есть тост «Отменить» (завершение, перенос, смена срока),
/// возвращают [Undo]. Удаление — без отмены, как в Todoist.
final class TaskCommands {
  TaskCommands({
    required this._mutator,
    required this._read,
    required this._clock,
    required this._resetRecurringSubtasks,
  });

  final Mutator _mutator;
  final Future<Workspace> Function() _read;
  final AppClock _clock;

  /// Настройка «Сбрасывать подзадачи» (синхронизируется в `settings`).
  final Future<bool> Function() _resetRecurringSubtasks;

  /// Сколько выполненных прямых подзадач возвращает в работу выполнение
  /// повторяющейся задачи (help «Reset a sub-task»).
  static const int resetSubtasksLimit = 30;

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
    checkDuration(duration);
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
    checkRoom(ws, place.projectId, placeActive ? 1 : 0);
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

  /// Бросок на другой день («Предстоящее», зона «завтра» в «Сегодня»): только
  /// дата вхождения, как в планировщике ([dueOnDate]), время, пояс и правило
  /// остаются (решение 8 плана M4). Тот же день — без записи и с пустой
  /// отменой: тоста без видимой перемены нет.
  Future<Undo> moveToDay(String id, String date) => _mutator.batch(() async {
    final ws = await _read();
    final task = await _alive(id, ws);
    if (task.due?.date == date) return _mutator.capture(const []);
    return setDue(id, dueOnDate(task.due, date), snapshot: ws);
  });

  /// Бросок на место в дне [date] («Сегодня», «Предстоящее»): сразу после
  /// [afterId] (`null` — первой), с датой дня, если задача с другого дня.
  /// Порядок задаёт `day_order_key` (решение 8 плана M4). При [sorting]
  /// «Вручную» место — среди всех задач дня, при «Умной» — среди задач с теми
  /// же сроком, приоритетом и дедлайном: выше ручного порядка они сильнее
  /// (решение 1А «Ход M4.9»).
  ///
  /// Задачи без ключа стоят после задач с ключом, поэтому ключ получают все
  /// задачи выше места, а хвост без ключа остаётся без записей. [afterId] —
  /// строка над местом броска: из группы выше — первой в своей группе, из
  /// группы ниже — последней. Сортировка с направлением — ошибка вызывающего
  /// кода: там порядок дня не действует ([ViewOptions.allowsDrag]).
  Future<Undo> reorderInDay(
    String id,
    String date, {
    String? afterId,
    Sorting sorting = Sorting.byDefault,
  }) => _mutator.batch(() async {
    if (sorting.hasDirection) {
      throw ArgumentError.value(sorting, 'sorting', 'порядок дня не действует');
    }
    final ws = await _read();
    final task = await _alive(id, ws);
    final sameDay = task.due?.date == date;
    final due = dueOnDate(task.due, date);
    if (!sameDay && due.isRecurring) _next(due, _clock.nowWall());
    final moved = task.copyWith(due: due);
    final order = ws.taskOrder(DefaultOrder.smart, sorting: sorting);
    bool inClass(Task t) =>
        sorting == Sorting.manual || order.sameBeforeDayOrder(moved, t);
    final full = ws.todayTasks(date, order: order);
    final others = [
      for (final t in full)
        if (t.id != id && inClass(t)) t,
    ];
    final at = afterId == null ? -1 : full.indexWhere((t) => t.id == afterId);
    final index = afterId == null
        ? 0
        : at < 0
        ? others.length
        : full.take(at + 1).where((t) => t.id != id && inClass(t)).length;
    final before = full.takeWhile((t) => t.id != id).where(inClass).length;
    if (sameDay && before == index) return _mutator.capture(const []);
    final keys = [for (final t in others) t.dayOrderKey];
    final lastKeyed = keys.lastIndexWhere((k) => k.isNotEmpty);
    final cut = index > lastKeyed + 1 ? index : lastKeyed + 1;
    final place = insertionKeys(keys.sublist(0, cut), index, 1);
    final rekeyed = [
      for (final (i, key) in place.rekeyed.indexed)
        if (key != null) (others[i].id, key),
    ];
    final undo = await _mutator.capture([
      _target(id, {if (!sameDay) TaskFields.due, TaskFields.dayOrderKey}),
      for (final (other, _) in rekeyed)
        _target(other, {TaskFields.dayOrderKey}),
    ]);
    for (final (other, key) in rekeyed) {
      await _mutator.update(EntityTypes.task, other, {
        TaskFields.dayOrderKey: key,
      });
    }
    await _mutator.update(EntityTypes.task, id, {
      if (!sameDay) TaskFields.due: _dueValue(due),
      TaskFields.dayOrderKey: place.inserted.single,
    });
    return undo;
  });

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

  /// Длительность от 1 минуты до 24 часов ([checkDuration]); `null` убирает.
  Future<void> setDuration(String id, TaskDuration? duration) async {
    checkDuration(duration);
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

  /// Завершить задачу вместе с незавершёнными подзадачами. Повторяющаяся
  /// задача не завершается, а получает следующий срок ([_completeOccurrence]);
  /// [resetSubtasks] — «Выполнить и снова добавить подзадачи»: сброс
  /// подзадач и при выключенной настройке.
  ///
  /// Снимок читается внутри транзакции: правка правила, пришедшая
  /// синхронизацией между чтением и записью, не посчитается по старому.
  Future<Undo> complete(String id, {bool resetSubtasks = false}) =>
      _mutator.batch(() async {
        final steps = await _steps();
        return _completeStep(steps, id, forceReset: resetSubtasks);
      });

  /// [complete] каждой из [ids] по порядку — шаги действия над выделенными
  /// одной транзакцией, по отмене на шаг. [snapshot] — снимок, уже
  /// прочитанный в той же транзакции; перечитывается он, только когда
  /// прошлый шаг изменил то, что читает следующий ([_Steps]).
  Future<List<Undo>> completeEach(List<String> ids, {Workspace? snapshot}) =>
      _mutator.batch(() async {
        final steps = await _steps(snapshot);
        return [for (final id in ids) await _completeStep(steps, id)];
      });

  /// Шаг [complete]: читает и меняет дерево задачи, а повторяющаяся со
  /// сбросом подзадач — ещё и метки ([_labelRevival]).
  Future<Undo> _completeStep(
    _Steps steps,
    String id, {
    bool forceReset = false,
  }) async {
    final seen = await _alive(id, steps.ws);
    final tree = _treeKey(steps.ws, id);
    final ws = await steps.fresh([
      tree,
      if (seen.due?.isRecurring ?? false) _Steps.labels,
    ]);
    final task = await _alive(id, ws);
    steps.changed([tree]);
    final due = task.due;
    if (due != null && due.isRecurring && !task.isCompleted) {
      return _completeOccurrence(steps, ws, task, due, forceReset: forceReset);
    }
    return _completeTree(ws, id);
  }

  /// «Завершить навсегда»: задача завершается вместе с незавершёнными
  /// подзадачами, срок и правило остаются как были (help «Reset a
  /// sub-task»). У обычной задачи — то же, что [complete].
  Future<Undo> completeForever(String id) => _mutator.batch(() async {
    final ws = await _read();
    await _alive(id, ws);
    return _completeTree(ws, id);
  });

  Future<Undo> _completeTree(Workspace ws, String id) => markCompleted(ws, [
    for (final t in ws.taskSubtree(id))
      if (!ws.task(t)!.isCompleted) t,
  ]);

  /// Выполнение вхождения повторяющейся задачи (решения 3, 6 плана M3):
  /// запись о выполнении с id из (задача, вхождение) — два устройства пишут
  /// одну — и следующий срок по правилу; выполненные прямые подзадачи (до
  /// [resetSubtasksLimit]) возвращаются в работу с удалёнными метками, как
  /// при [uncomplete], если включено «Сбрасывать подзадачи» или
  /// [forceReset]; незавершённые остаются как есть (решение 3А «Ход M3.4»,
  /// допущение О-57). Серия закончилась (`UNTIL` позади) — задача
  /// завершается навсегда (допущение О-57).
  ///
  /// Момент выполнения — стенное время устройства: пояс срока, отличный от
  /// пояса устройства, не учитывается (решение 1А «Ход M3.4», О-64).
  ///
  /// Лимиты 300 задач в проекте и 500 меток сброс не проверяет (решение 3А
  /// «Ход M4.13», [Limits]). «Отменить» возвращает и метки сброшенных
  /// подзадач: связи с удалёнными метками и без созданных заново (О-70).
  Future<Undo> _completeOccurrence(
    _Steps steps,
    Workspace ws,
    Task task,
    Due due, {
    required bool forceReset,
  }) async {
    final next = _next(due, _clock.nowWall());
    if (next == null) return _completeTree(ws, task.id);

    final dueWas = dueWasOf(due.date, due.time);
    final record = completionId(task.id, dueWas);
    final reset = forceReset || await _resetRecurringSubtasks()
        ? [
            for (final s in ws.children(task.id))
              if (s.isCompleted) s.id,
          ].take(resetSubtasksLimit).toList()
        : const <String>[];
    final revival = _labelRevival(ws, reset);
    final undo = await _mutator.capture(
      [
        _dueTarget(task, next),
        for (final s in reset)
          _target(s, {
            TaskFields.isCompleted,
            TaskFields.completedAt,
            TaskFields.completedLabelNames,
          }),
        ...revival.restored,
      ],
      // Запись уже есть (пришла с другого устройства) — «Отменить» вернёт
      // её прежнее время, а не удалит чужое выполнение.
      created: [
        (
          entityType: EntityTypes.completion,
          entityId: record,
          fields: {CompletionFields.completedAt},
        ),
        ...revival.created,
      ],
    );
    await _mutator.update(EntityTypes.completion, record, {
      CompletionFields.taskId: task.id,
      CompletionFields.dueWas: dueWas,
      CompletionFields.completedAt: _now(),
      // Запись могла быть удалена «Отменить» — выполнение возвращает её.
      CompletionFields.deleted: false,
    });
    await _mutator.update(EntityTypes.task, task.id, _dueFields(task, next));
    for (final s in reset) {
      await _mutator.update(EntityTypes.task, s, {
        TaskFields.isCompleted: false,
        TaskFields.completedAt: null,
        TaskFields.completedLabelNames: null,
      });
    }
    await _applyRevival(revival);
    if (!revival.isEmpty) steps.changed([_Steps.labels]);
    return undo;
  }

  /// «Отложить» повторяющуюся задачу: на следующее будущее вхождение без
  /// записи о выполнении; просроченная — на завтра, со временем и правилом
  /// (help «Introduction to recurring dates»). Серия закончилась (в том числе
  /// для просроченной) или задача выполнена — срок не меняется. Обычная
  /// задача — [RejectReason.notRecurring].
  Future<Undo> postpone(String id) => _mutator.batch(() async {
    final ws = await _read();
    final task = await _alive(id, ws);
    final due = task.due;
    if (due == null || !due.isRecurring) {
      throw const CommandRejected(RejectReason.notRecurring);
    }
    // Сначала само правило: битое — отказ даже у выполненной задачи.
    final next = postponedDue(due, _clock.nowWall());
    if (task.isCompleted || next == null) return _mutator.capture(const []);
    final undo = await _mutator.capture([_dueTarget(task, next)]);
    await _mutator.update(EntityTypes.task, id, _dueFields(task, next));
    return undo;
  });

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

  /// [nextOccurrence] с отказом вместо FormatException: битое правило
  /// (пришло с другого устройства) — сообщение пользователю, данные целы.
  static Due? _next(Due due, DateTime now, {bool postpone = false}) {
    try {
      return nextOccurrence(due, completedAt: now, postpone: postpone);
    } on FormatException {
      throw const CommandRejected(RejectReason.brokenRecurrence);
    }
  }

  /// Вернуть задачу в работу: вместе с ней возвращаются завершённые предки и
  /// архивный раздел корневой задачи, как `item_uncomplete` в Todoist API.
  /// Возвращённые встают на прежнее место — ключ порядка при выполнении не
  /// меняется (отступление от API, где они встают в конец: решение 4А
  /// «M4.10a» plans/m4). Новый ключ — только если прежний совпал с ключом
  /// активного соседа (два устройства вставили элемент в одно место): на том
  /// же месте, сразу после равных. «Отменить» в тосте после завершения сюда не
  /// ведёт: он восстанавливает прежние значения полей.
  ///
  /// Удалённые метки возвращённых задач возвращаются, как в Todoist
  /// ([_labelRevival]); снимок имён меток снимается. Лимит 500 меток при этом
  /// не проверяется (решение 3А «Ход M4.13»). [Undo] (в интерфейсе его нет)
  /// возвращает только поля задач и раздела, метки остаются.
  Future<Undo> uncomplete(String id) => _mutator.batch(() async {
    final steps = await _steps();
    return _uncompleteStep(steps, id);
  });

  /// [uncomplete] каждой из [ids] по порядку — как [completeEach].
  Future<List<Undo>> uncompleteEach(List<String> ids, {Workspace? snapshot}) =>
      _mutator.batch(() async {
        final steps = await _steps(snapshot);
        return [for (final id in ids) await _uncompleteStep(steps, id)];
      });

  /// Шаг [uncomplete]: читает и меняет дерево задачи, раздел её корня (его
  /// возврат из архива) и метки; места активных соседей и число активных
  /// задач проекта после прошлых шагов берёт из [steps].
  Future<Undo> _uncompleteStep(_Steps steps, String id) async {
    await _alive(id, steps.ws);
    final tree = _treeKey(steps.ws, id);
    final rootSection = steps.ws.rootSectionOf(id);
    final ws = await steps.fresh([
      tree,
      if (rootSection != null) _Steps.section(rootSection.id),
      // Возврат раздела ставит его среди активных разделов проекта: раздел,
      // возвращённый прошлым шагом, должен быть в снимке среди соседей.
      if (rootSection != null && rootSection.isArchived)
        _Steps.sections(steps.ws.rootProjectOf(id)),
      _Steps.labels,
    ]);
    var root = await _alive(id, ws);
    final ids = <String>[];
    for (String? t = id; t != null; t = ws.taskParent(t)) {
      root = ws.task(t)!;
      if (root.isCompleted) ids.add(t);
    }
    if (ids.isEmpty) return _mutator.capture(const []);
    final top = ids.last;
    final projectId = ws.rootProjectOf(top);
    final section = ws.section(root.sectionId ?? '');
    final reinstateSection = section != null && section.isArchived;
    // Активными становятся верхняя возвращаемая задача и её поддерево без
    // выполненных отдельно подзадач и их потомков, а с возвратом раздела — и
    // остальные задачи раздела (О-81). В архивном проекте — никто.
    bool doneAfter(Task t) => t.isCompleted && !ids.contains(t.id);
    final opening = ws.isProjectArchived(projectId)
        ? 0
        : openInTrees(ws, [
            if (reinstateSection)
              for (final r in ws.children(
                null,
                projectId: projectId,
                sectionId: section.id,
              ))
                r.id
            else
              top,
          ], done: doneAfter).length;
    checkRoom(ws, projectId, opening, already: steps.addedTo(projectId));

    // Ключи считаются до записи: соседи — незавершённые (в том числе
    // возвращённые прошлыми шагами) и не возвращаемые.
    final keys = <String, String>{
      for (final t in ids)
        t: ?_returnKey(t, ws.task(t)!.orderKey, [
          for (final s in _siblings(ws, ws.task(t)!))
            if (!steps.isCompleted(s) && !ids.contains(s.id))
              (s.id, steps.orderKey(s)),
        ]),
    };
    final sectionKey = reinstateSection
        ? _returnKey(section.id, section.orderKey, [
            for (final s in ws.sectionsOf(
              section.projectId ?? ws.inbox?.id ?? inboxProjectId,
            ))
              (s.id, s.orderKey),
          ])
        : null;
    final undo = await _mutator.capture([
      for (final t in ids)
        _target(t, {
          TaskFields.isCompleted,
          TaskFields.completedAt,
          TaskFields.completedLabelNames,
          if (keys.containsKey(t)) TaskFields.orderKey,
        }),
      if (reinstateSection)
        (
          entityType: EntityTypes.section,
          entityId: section.id,
          fields: {
            SectionFields.isArchived,
            if (sectionKey != null) SectionFields.orderKey,
          },
        ),
    ]);
    for (final t in ids) {
      await _mutator.update(EntityTypes.task, t, {
        TaskFields.isCompleted: false,
        TaskFields.completedAt: null,
        TaskFields.completedLabelNames: null,
        TaskFields.orderKey: ?keys[t],
      });
    }
    if (reinstateSection) {
      await _mutator.update(EntityTypes.section, section.id, {
        SectionFields.isArchived: false,
        SectionFields.orderKey: ?sectionKey,
      });
    }
    final revival = _labelRevival(ws, ids);
    await _applyRevival(revival);
    steps
      ..changed([
        tree,
        if (reinstateSection) ...[
          _Steps.section(section.id),
          _Steps.sections(projectId),
        ],
        if (!revival.isEmpty) _Steps.labels,
      ])
      ..reopened(projectId, opening, {
        for (final t in ids) t: keys[t] ?? ws.task(t)!.orderKey,
      });
    return undo;
  }

  /// Новый ключ порядка для элемента [id] с ключом [key], который
  /// возвращается к активным соседям [others] (id и ключ): `null` — прежний
  /// ключ свободен и место сохраняется. Ключ совпал с соседским или пуст и
  /// неверен — ключ на том же месте списка, сразу после равных (как при
  /// вставке, [keyForInsert]); без верного ключа — в конец.
  static String? _returnKey(
    String id,
    String key,
    List<(String, String)> others,
  ) {
    final valid = key.isNotEmpty && !key.endsWith('0');
    if (valid && others.every((o) => o.$2 != key)) return null;
    final sorted = [...others]
      ..sort((a, b) {
        final byKey = a.$2.compareTo(b.$2);
        return byKey != 0 ? byKey : a.$1.compareTo(b.$1);
      });
    final keys = [for (final o in sorted) o.$2];
    if (!valid) return keyAtEnd(keys);
    // Место — как у сортировки [Workspace]: ключ, затем id.
    final index = sorted
        .where(
          (o) =>
              o.$2.compareTo(key) < 0 ||
              (o.$2 == key && o.$1.compareTo(id) < 0),
        )
        .length;
    return keyForInsert(keys, index);
  }

  /// Удалённые метки задач [ids], которые возвращаются в работу, — как в
  /// Todoist (help «Introduction to labels»): задача получает живую метку с
  /// именем на момент завершения (снимок [Task.completedLabelNames]; нет
  /// снимка — последнее имя удалённой метки), без учёта регистра, а если её
  /// нет — метку, созданную заново с этим именем, цветом и избранным по
  /// умолчанию, в конце списка.
  /// Связь с удалённой меткой снимается: если ту восстановят (выбор на экране
  /// «Конфликты»), задача не понесёт две одноимённые метки. Id новой метки —
  /// [revivedLabelId] из id удалённой и имени: два устройства, вернувшие
  /// такие задачи офлайн, создают одну метку, а разные имена одной удалённой
  /// метки в снимках задач — разные метки.
  ///
  /// Только расчёт: пишет [_applyRevival], а «Отменить» берёт из результата,
  /// что вернуть ([_Revival.restored]) и что удалить ([_Revival.created]).
  static _Revival _labelRevival(Workspace ws, List<String> ids) {
    final byName = <String, String>{};
    for (final l in ws.labels) {
      byName.putIfAbsent(l.name.toLowerCase(), () => l.id);
    }
    final keys = [for (final l in ws.labels) l.orderKey];
    final labels = <String, ({String name, String orderKey})>{};
    final relinks = <({String task, String from, String to})>[];
    for (final t in ids) {
      final task = ws.task(t)!;
      for (final old in task.labelIds) {
        if (ws.deletedLabel(old) == null) continue;
        // Пустое имя — снимка нет, а метка известна только по tombstone (поля
        // создателя ещё не пришли): создавать нечего.
        final name = ws.taskLabel(task, old)!.name;
        if (name.trim().isEmpty) continue;
        final target = byName[name.toLowerCase()] ??= () {
          var id = old;
          do {
            id = revivedLabelId(id, name);
          } while (ws.label(id) != null || ws.deletedLabel(id) != null);
          final key = keyAtEnd(keys);
          keys.add(key);
          labels[id] = (name: name, orderKey: key);
          return id;
        }();
        relinks.add((task: t, from: old, to: target));
      }
    }
    return _Revival(labels, relinks);
  }

  /// Записать [revival]: новые метки, затем перевязки задач.
  Future<void> _applyRevival(_Revival revival) async {
    for (final MapEntry(key: id, value: label) in revival.labels.entries) {
      await _mutator.update(EntityTypes.label, id, {
        LabelFields.name: label.name,
        LabelFields.color: 'charcoal',
        LabelFields.orderKey: label.orderKey,
        LabelFields.isFavorite: false,
      });
    }
    for (final link in revival.relinks) {
      await _link(link.task, link.from, linked: false);
      await _link(link.task, link.to, linked: true);
    }
  }

  /// Удалить (tombstone). Подзадачи скрываются вместе с задачей.
  Future<void> delete(String id, {Workspace? snapshot}) async {
    await _alive(id, snapshot);
    await _mutator.delete(EntityTypes.task, id);
  }

  /// Перенести задачу с подзадачами: под [parentId] или в раздел
  /// [sectionId] проекта [projectId]; место — как в [add].
  Future<Undo> move(
    String id, {
    String? projectId,
    String? sectionId,
    String? parentId,
    String? afterId,
    bool atTop = false,
  }) => placeAll(
    [id],
    projectId: projectId,
    sectionId: sectionId,
    parentId: parentId,
    afterId: afterId,
    atTop: atTop,
  );

  /// Поставить задачи [roots] с подзадачами подряд на одно место: «Перенести
  /// в…» и перетаскивание, одной или нескольких (решение 8 плана M4). Каждая
  /// задача — одна правка: место и ключ одним действием, поэтому перенос на
  /// другом устройстве даёт одну карточку. Проект, раздел и родитель пишутся,
  /// только если место меняется: у подзадач они намеренно устаревшие
  /// (SYNC_DESIGN «Специальные случаи»), и перестановка на месте спорила бы
  /// с их правками. Равные ключи соседей разводятся здесь же (О-8). Задачи
  /// уже на этом месте — с пустой отменой: записывается только исправленный
  /// `parent_id`, если записанный устарел (см. `staleParent`). Это не видимая
  /// правка: «Отменить» его не возвращает, и тоста без перемены нет.
  Future<Undo> placeAll(
    List<String> roots, {
    String? projectId,
    String? sectionId,
    String? parentId,
    String? afterId,
    bool atTop = false,
  }) => _mutator.batch(() async {
    final ws = await _read();
    for (final id in roots) {
      await _alive(id, ws);
    }
    if (parentId != null) {
      for (final id in roots) {
        if (ws.taskSubtree(id).contains(parentId)) {
          throw const CommandRejected(RejectReason.cycle);
        }
        if (ws.taskDepth(parentId) + ws.taskHeight(id) > Limits.taskLevels) {
          throw const CommandRejected(RejectReason.tooDeep);
        }
      }
    }
    final place = _place(
      ws,
      projectId: projectId,
      sectionId: sectionId,
      parentId: parentId,
    );
    // Прирост активных в проекте (О-81): активными станут незавершённые без
    // завершённого предка, если место активно (родитель не выполнен), минус
    // те, что уже активны в этом проекте.
    final opening = parentId == null || ws.isTaskActive(parentId)
        ? openInTrees(ws, roots).length
        : 0;
    final staying = {
      for (final root in roots)
        for (final t in ws.taskSubtree(root))
          if (ws.isTaskActive(t) && ws.rootProjectOf(t) == place.projectId) t,
    }.length;
    checkRoom(ws, place.projectId, opening - staying);
    final moved = roots.toSet();
    final siblings = ws.children(
      parentId,
      projectId: place.projectId,
      sectionId: place.sectionId,
    );
    final others = [
      for (final t in siblings)
        if (!moved.contains(t.id)) t,
    ];
    final index = _insertIndex(siblings, moved, afterId: afterId, atTop: atTop);
    final target = [
      for (final t in others.take(index)) t.id,
      ...roots,
      for (final t in others.skip(index)) t.id,
    ];
    // Записанный родитель отличается от действующего: цикл, разорванный
    // после правок двух устройств, или родитель, которого здесь ещё нет.
    // Перенос пишет его и тогда, когда видимое место то же: иначе цикл
    // восстановится, как только второй элемент уйдёт из-под первого. На
    // экране это ничего не меняет, поэтому в «Отменить» не входит: отмена
    // вернула бы устаревшего родителя.
    bool staleParent(String id) => ws.task(id)!.parentId != parentId;
    if (_sameOrder(target, [for (final t in siblings) t.id])) {
      for (final id in roots) {
        if (!staleParent(id)) continue;
        await _mutator.update(EntityTypes.task, id, {
          TaskFields.parentId: parentId,
        });
      }
      return _mutator.capture(const []);
    }
    final keys = insertionKeys(
      [for (final t in others) t.orderKey],
      index,
      roots.length,
    );
    final rekeyed = [
      for (final (i, key) in keys.rekeyed.indexed)
        if (key != null) (others[i].id, key),
    ];
    bool samePlace(String id) =>
        ws.taskParent(id) == parentId &&
        (parentId != null ||
            (ws.rootProjectOf(id) == place.projectId &&
                ws.rootSectionOf(id)?.id == place.sectionId));
    // Только то, что правка пишет: лишнее поле откатило бы перенос с другого
    // устройства, пока виден тост.
    final undo = await _mutator.capture([
      for (final id in roots)
        _target(id, {
          if (!samePlace(id)) ...{
            TaskFields.projectId,
            TaskFields.sectionId,
            TaskFields.parentId,
          },
          TaskFields.orderKey,
        }),
      for (final (other, _) in rekeyed) _target(other, {TaskFields.orderKey}),
    ]);
    for (final (other, key) in rekeyed) {
      await _mutator.update(EntityTypes.task, other, {
        TaskFields.orderKey: key,
      });
    }
    for (final (i, id) in roots.indexed) {
      await _mutator.update(EntityTypes.task, id, {
        if (!samePlace(id)) ...{
          TaskFields.projectId: place.projectId,
          TaskFields.sectionId: place.sectionId,
          TaskFields.parentId: parentId,
        } else if (staleParent(id))
          TaskFields.parentId: parentId,
        TaskFields.orderKey: keys.inserted[i],
      });
    }
    return undo;
  });

  /// Место среди соседей без [moved]: после [afterId] (переносимый [afterId]
  /// — на его месте), в начало при [atTop] или в конец. Считается по
  /// соседям, а не по экрану: скрытые выполненные место не сдвигают.
  static int _insertIndex(
    List<Task> siblings,
    Set<String> moved, {
    String? afterId,
    bool atTop = false,
  }) {
    final at = afterId == null
        ? -1
        : siblings.indexWhere((t) => t.id == afterId);
    if (at < 0) {
      return atTop ? 0 : siblings.where((t) => !moved.contains(t.id)).length;
    }
    return siblings.take(at + 1).where((t) => !moved.contains(t.id)).length;
  }

  static bool _sameOrder(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Сделать подзадачей предыдущей задачи (Ctrl+]); в конец её подзадач.
  /// `null` — сдвигать некуда (задача первая).
  Future<Undo?> indent(String id) async {
    final ws = await _read();
    final task = await _alive(id, ws);
    final siblings = _activeSiblings(ws, task);
    final index = siblings.indexWhere((t) => t.id == id);
    if (index <= 0) return null;
    final newParent = siblings[index - 1].id;
    final last = ws.children(newParent).lastOrNull;
    return move(id, parentId: newParent, afterId: last?.id);
  }

  /// Поднять на уровень выше (Ctrl+[): сразу после бывшего родителя.
  /// `null` — задача и так корневая.
  Future<Undo?> outdent(String id) async {
    final ws = await _read();
    await _alive(id, ws);
    final parentId = ws.taskParent(id);
    if (parentId == null) return null;
    final parent = ws.task(parentId)!;
    final grandparent = ws.taskParent(parentId);
    return move(
      id,
      parentId: grandparent,
      projectId: ws.rootProjectOf(parentId),
      sectionId: parent.sectionId,
      afterId: parentId,
    );
  }

  /// Поднять выше соседа. `false` — задача уже первая.
  Future<bool> moveUp(String id) => _shift(id, up: true);

  /// Опустить ниже соседа. `false` — задача уже последняя.
  Future<bool> moveDown(String id) => _shift(id, up: false);

  /// Дубликат задачи с незавершёнными подзадачами и метками — сразу после
  /// неё, а в «Сегодня» и «Предстоящем» — сразу после неё в своём дне (ключ
  /// порядка дня между её ключом и следующим). Возвращает id копии.
  Future<String> duplicate(String id) => _mutator.batch(() async {
    final steps = await _steps();
    return _duplicateStep(steps, id);
  });

  /// [duplicate] каждой из [ids] по порядку — как [completeEach]. Копии
  /// прошлых шагов снимок не перечитывают: их места и число в проекте ведёт
  /// [_Steps].
  Future<List<String>> duplicateEach(List<String> ids, {Workspace? snapshot}) =>
      _mutator.batch(() async {
        final steps = await _steps(snapshot);
        return [for (final id in ids) await _duplicateStep(steps, id)];
      });

  Future<String> _duplicateStep(_Steps steps, String id) async {
    final ws = steps.ws;
    final task = await _alive(id, ws);
    final projectId = ws.rootProjectOf(id);
    final parentId = ws.taskParent(id);
    // Копия всегда незавершённая, с незавершёнными подзадачами, а активна —
    // если активно её место: не под выполненным родителем, не в архиве (О-81).
    final placeActive = parentId != null
        ? ws.isTaskActive(parentId)
        : !ws.isProjectArchived(projectId) &&
              !(ws.rootSectionOf(id)?.isArchived ?? false);
    final adding = placeActive
        ? 1 + openInTrees(ws, [for (final c in ws.children(id)) c.id]).length
        : 0;
    checkRoom(ws, projectId, adding, already: steps.addedTo(projectId));
    final group = _siblingGroup(ws, task);
    final siblings = [
      for (final t in _siblings(ws, task)) (t.id, t.orderKey),
      ...steps.copiesIn(group),
    ]..sort(_byKeyThenId);
    final index = siblings.indexWhere((s) => s.$1 == id);
    final orderKey = keyForInsert([for (final s in siblings) s.$2], index + 1);
    final copy = await copyTree(
      ws,
      task,
      projectId: projectId,
      sectionId: task.sectionId,
      parentId: parentId,
      orderKey: orderKey,
      dayOrderKey: (source) => _dayKeyAfter(ws, steps, source),
    );
    steps.copied(group, copy, orderKey, projectId, adding);
    return copy;
  }

  /// Ключ порядка дня копии [source] — сразу после неё в её дне: между её
  /// ключом и следующим ключом активных задач того же дня (и копий прошлых
  /// шагов). `null` — у неё нет ключа или срока.
  static String? _dayKeyAfter(Workspace ws, _Steps steps, Task source) {
    final key = source.dayOrderKey;
    final date = source.due?.date;
    if (date == null || !_isValidKey(key)) return null;
    String? next;
    for (final k in [
      for (final t in ws.todayTasks(date)) t.dayOrderKey,
      ...steps.dayKeysOn(date),
    ]) {
      if (_isValidKey(k) &&
          k.compareTo(key) > 0 &&
          (next == null || k.compareTo(next) < 0)) {
        next = k;
      }
    }
    final copyKey = between(key, next);
    steps.dayKeyUsed(date, copyKey);
    return copyKey;
  }

  /// Копия задачи [source] и её незавершённых подзадач в новое место; для
  /// дубликатов задачи, раздела и проекта. Вызывать внутри [Mutator.batch].
  /// [dayOrderKey] — ключ порядка дня копии каждой задачи дерева по
  /// оригиналу (дубликат задачи); без него копии ключа дня не получают.
  Future<String> copyTree(
    Workspace ws,
    Task source, {
    required String projectId,
    required String? sectionId,
    required String? parentId,
    required String orderKey,
    String? Function(Task source)? dayOrderKey,
  }) async {
    final id = await _mutator.create(EntityTypes.task, {
      TaskFields.content: source.content,
      if (source.description.isNotEmpty)
        TaskFields.description: source.description,
      TaskFields.projectId: projectId,
      TaskFields.sectionId: ?sectionId,
      TaskFields.parentId: ?parentId,
      TaskFields.orderKey: orderKey,
      TaskFields.dayOrderKey: ?dayOrderKey?.call(source),
      TaskFields.priority: source.priority,
      TaskFields.due: ?_dueValue(source.due),
      TaskFields.deadline: ?_deadlineValue(source.deadline),
      TaskFields.duration: ?_durationValue(source.duration),
      TaskFields.addedAt: _now(),
    });
    // Удалённая метка выполненного оригинала на активную копию не идёт.
    for (final label in source.labelIds) {
      if (ws.label(label) != null) await _link(id, label, linked: true);
    }
    for (final child in ws.children(source.id)) {
      if (child.isCompleted) continue;
      await copyTree(
        ws,
        child,
        projectId: projectId,
        sectionId: sectionId,
        parentId: id,
        orderKey: child.orderKey,
        dayOrderKey: dayOrderKey,
      );
    }
    return id;
  }

  // --- Внутреннее ---

  /// Завершить задачи [ids] снимка [ws] одной транзакцией, без проверок
  /// дерева: для действий над группой (завершение с подзадачами, архив
  /// раздела). Задача с метками получает снимок их имён
  /// ([TaskFields.completedLabelNames]) тем же действием (решение 4 плана
  /// M4); «Отменить» возвращает и его. У задачи без меток снимок снимается:
  /// старый мог остаться после параллельных завершения и возврата, а метку
  /// могут поставить и выполненной задаче.
  Future<Undo> markCompleted(Workspace ws, List<String> ids) async {
    final names = {
      for (final t in ids)
        t: {
          for (final l in ws.task(t)!.labelIds)
            if (ws.label(l) case final label?) l: label.name,
        },
    };
    final undo = await _mutator.capture([
      for (final t in ids)
        _target(t, {
          TaskFields.isCompleted,
          TaskFields.completedAt,
          TaskFields.completedLabelNames,
        }),
    ]);
    final at = _now();
    await _mutator.batch(() async {
      for (final t in ids) {
        await _mutator.update(EntityTypes.task, t, {
          TaskFields.isCompleted: true,
          TaskFields.completedAt: at,
          // Пустого снимка нет — `null`; без старого снимка op не пишется.
          TaskFields.completedLabelNames: names[t]!.isEmpty ? null : names[t],
        });
      }
    });
    return undo;
  }

  Future<bool> _shift(String id, {required bool up}) async {
    final ws = await _read();
    final task = await _alive(id, ws);
    final siblings = _activeSiblings(ws, task);
    final i = siblings.indexWhere((t) => t.id == id);
    final j = up ? i - 1 : i + 1;
    if (i < 0 || j < 0 || j >= siblings.length) return false;
    final others = [
      for (final t in siblings)
        if (t.id != id) t.orderKey,
    ];
    // Обычно хватает нового ключа у самой задачи — соседи не трогаются.
    final key = keyForInsert(others, j);
    final fits =
        (j == 0 || key.compareTo(others[j - 1]) > 0) &&
        (j == others.length || key.compareTo(others[j]) < 0);
    if (fits) {
      await _mutator.update(EntityTypes.task, id, {TaskFields.orderKey: key});
      return true;
    }
    // Соседи с одинаковыми ключами (параллельные вставки на двух устройствах):
    // между ними не встать — перевыдаём минимум ключей в новом порядке.
    final order = [...siblings]
      ..removeAt(i)
      ..insert(j, task);
    final keys = rekeyInOrder([for (final t in order) t.orderKey]);
    await _mutator.batch(() async {
      for (final (k, newKey) in keys.indexed) {
        if (newKey == null) continue;
        await _mutator.update(EntityTypes.task, order[k].id, {
          TaskFields.orderKey: newKey,
        });
      }
    });
    return true;
  }

  /// Соседи задачи по месту в дереве (включая её саму), по порядку.
  List<Task> _siblings(Workspace ws, Task task) {
    final parent = ws.taskParent(task.id);
    return parent != null
        ? ws.children(parent)
        : ws.children(
            null,
            projectId: ws.rootProjectOf(task.id),
            sectionId: ws.section(task.sectionId ?? '') == null
                ? null
                : task.sectionId,
          );
  }

  List<Task> _activeSiblings(Workspace ws, Task task) => [
    for (final t in _siblings(ws, task))
      if (!t.isCompleted || t.id == task.id) t,
  ];

  /// Проект и раздел нового места: подзадача — как у родителя. Место в
  /// архивном проекте или архивном разделе, в том числе родитель там, —
  /// [RejectReason.notFound], как
  /// место, которого нет: его убрали в архив на другом устройстве, пока окно
  /// было открыто, и задача ушла бы туда невидимой (интерфейс туда не
  /// переносит и не добавляет).
  ({String projectId, String? sectionId}) _place(
    Workspace ws, {
    String? projectId,
    String? sectionId,
    String? parentId,
  }) {
    if (parentId != null) {
      final parent = ws.task(parentId);
      if (parent == null) throw const CommandRejected(RejectReason.notFound);
      final project = ws.rootProjectOf(parentId);
      if (ws.isProjectArchived(project) ||
          (ws.rootSectionOf(parentId)?.isArchived ?? false)) {
        throw const CommandRejected(RejectReason.notFound);
      }
      return (projectId: project, sectionId: parent.sectionId);
    }
    final inbox = ws.inbox?.id ?? inboxProjectId;
    if (sectionId != null) {
      // Проект задачи в разделе — проект раздела; раздел чужого проекта —
      // ошибка вызывающего кода, а не повод создать невидимую задачу.
      final section = ws.section(sectionId);
      final sectionProject = section?.projectId ?? inbox;
      if (section == null ||
          section.isArchived ||
          ws.isProjectArchived(sectionProject) ||
          (projectId != null && projectId != sectionProject)) {
        throw const CommandRejected(RejectReason.notFound);
      }
      return (projectId: sectionProject, sectionId: sectionId);
    }
    final project = projectId ?? inbox;
    if (ws.project(project) == null || ws.isProjectArchived(project)) {
      throw const CommandRejected(RejectReason.notFound);
    }
    return (projectId: project, sectionId: null);
  }

  /// Ключ порядка: после [afterId], в начало или в конец [siblings].
  static String _keyFor(
    List<Task> siblings, {
    String? afterId,
    bool atTop = false,
  }) {
    final keys = [for (final t in siblings) t.orderKey];
    if (afterId != null) {
      final i = siblings.indexWhere((t) => t.id == afterId);
      if (i >= 0) return keyForInsert(keys, i + 1);
    }
    return atTop ? keyForInsert(keys, 0) : keyAtEnd(keys);
  }

  Future<void> _link(String taskId, String labelId, {required bool linked}) =>
      _mutator.update(EntityTypes.taskLabel, taskLabelId(taskId, labelId), {
        TaskLabelFields.taskId: taskId,
        TaskLabelFields.labelId: labelId,
        TaskLabelFields.deleted: !linked,
      });

  /// В проект [projectId] приходят ещё [adding] активных задач: больше
  /// [Limits.activeTasksPerProject] — [RejectReason.tooManyTasks] (решение 3А
  /// «Часть M4.11» plans/m4). Проверяется только прирост: проект, уже
  /// переполненный синхронизацией, не мешает правкам и уходу задач.
  /// [already] — активные, добавленные прошлыми шагами того же действия
  /// после чтения [ws] ([_Steps]).
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

  static String _content(String content) {
    final text = content.trim();
    if (text.isEmpty) throw const CommandRejected(RejectReason.emptyName);
    return Limits.checkLength(text, Limits.taskContent);
  }

  /// Новый текст срока — до [Limits.dueText] символов. Прежний текст
  /// задачи [task] (пришёл с другого устройства длиннее) не проверяется:
  /// «Время», перенос дня и «Перенести» его сохраняют.
  static void _checkDueText(Due? due, [Task? task]) {
    final text = due?.string;
    if (text == null || text == task?.due?.string) return;
    Limits.checkLength(text, Limits.dueText);
  }

  Future<void> _update(
    String id,
    Map<String, Object?> fields, [
    Workspace? snapshot,
  ]) async {
    await _alive(id, snapshot);
    await _mutator.update(EntityTypes.task, id, fields);
  }

  Future<Task> _alive(String id, [Workspace? ws]) async {
    final task = (ws ?? await _read()).task(id);
    if (task == null) throw const CommandRejected(RejectReason.notFound);
    return task;
  }

  /// Поля срока: ручной порядок дня относится к дню — срок на другой дате
  /// снимает `day_order_key` той же правкой (О-71), иначе ключ старого дня
  /// поставил бы задачу выше задач нового. Время внутри дня ключ не снимает.
  static Map<String, Object?> _dueFields(Task task, Due? due) => {
    TaskFields.due: _dueValue(due),
    if (task.due?.date != due?.date) TaskFields.dayOrderKey: null,
  };

  /// Что возвращает «Отменить» после смены срока на [due]: только то, что
  /// правка пишет ([_dueFields]). Лишнее поле откатило бы правку, пришедшую с
  /// другого устройства, пока виден тост.
  static UndoTarget _dueTarget(Task task, Due? due) => _target(task.id, {
    TaskFields.due,
    if (task.due?.date != due?.date) TaskFields.dayOrderKey,
  });

  static UndoTarget _target(String id, Set<String> fields) =>
      (entityType: EntityTypes.task, entityId: id, fields: fields);

  String _now() => _clock.nowUtc().toIso8601String();

  /// Срок целиком, с правилом: ключ, которого нет, `Mutator.update` уберёт
  /// из прежнего срока (известный ключ), — срок без правила снимает повтор.
  static Map<String, Object?>? _dueValue(Due? due) => due == null
      ? null
      : ({
          DueKeys.date: due.date,
          DueKeys.time: due.time,
          DueKeys.tz: due.tz,
          DueKeys.string: due.string,
          DueKeys.lang: due.lang,
          DueKeys.rule: switch (due.rule) {
            final rule? => {
              RuleKeys.rrule: rule.rrule,
              RuleKeys.fromCompletion: rule.fromCompletion,
            },
            null => null,
          },
          // Время серии — только у повторяющегося срока.
          DueKeys.seriesTime: due.rule == null ? null : due.seriesTime,
        }..removeWhere((_, v) => v == null));

  static Map<String, Object?>? _deadlineValue(String? date) =>
      date == null ? null : {DeadlineKeys.date: date};

  static Map<String, Object?>? _durationValue(TaskDuration? d) => d == null
      ? null
      : {DurationKeys.amount: d.amount, DurationKeys.unit: d.unit};

  /// Шаги одного действия над снимком [snapshot] (уже прочитанным в той же
  /// транзакции) или над свежим.
  Future<_Steps> _steps([Workspace? snapshot]) async =>
      _Steps(snapshot ?? await _read(), _read);

  /// Ключ [_Steps] дерева задачи [id] — по её корневой задаче.
  static String _treeKey(Workspace ws, String id) {
    var root = id;
    for (var p = ws.taskParent(root); p != null; p = ws.taskParent(p)) {
      root = p;
    }
    return 'tree:$root';
  }

  /// Соседи задачи по месту ([_siblings]) — одной строкой: родитель или
  /// проект и раздел корня.
  static String _siblingGroup(Workspace ws, Task task) {
    final parent = ws.taskParent(task.id);
    if (parent != null) return 'parent:$parent';
    final section = ws.section(task.sectionId ?? '') == null
        ? ''
        : task.sectionId;
    return 'root:${ws.rootProjectOf(task.id)}:$section';
  }

  /// Порядок соседей, как в [Workspace]: ключ, затем id.
  static int _byKeyThenId((String, String) a, (String, String) b) {
    final byKey = a.$2.compareTo(b.$2);
    return byKey != 0 ? byKey : a.$1.compareTo(b.$1);
  }

  /// Верный ключ порядка: не пустой и не на `0` (fractional_index.dart).
  static bool _isValidKey(String key) => key.isNotEmpty && !key.endsWith('0');
}

/// Снимок для шагов одного действия над выделенными задачами (300 задач —
/// 300 шагов) в одной транзакции: перечитывается, только когда прошлый шаг
/// изменил то, что читает следующий, — дерево задачи (`tree:`), раздел её
/// корня (`section:`), порядок активных разделов проекта (`sections:`) или
/// метки ([labels]). Остальное, что меняют шаги и
/// читают другие — задачи, возвращённые в работу, копии и число активных в
/// проекте, — шаги записывают сюда же, и следующий учитывает это поверх
/// снимка. Так результат и «Отменить» — те же, что при свежем снимке на
/// каждом шаге (замер и решение — plans/m4 «Ход M4.13»).
final class _Steps {
  _Steps(this.ws, this._read);

  /// Ключ «метки изменились»: новые метки и перевязки задач.
  static const String labels = 'labels';

  /// Ключ раздела [id].
  static String section(String id) => 'section:$id';

  /// Ключ порядка активных разделов проекта [projectId].
  static String sections(String projectId) => 'sections:$projectId';

  Workspace ws;
  final Future<Workspace> Function() _read;
  final Set<String> _changed = {};
  final Map<String, int> _added = {};
  final Map<String, String> _reopened = {};
  final Map<String, List<(String, String)>> _copies = {};
  final Map<String, List<String>> _dayKeys = {};

  /// Снимок для шага, который читает [needs]: свежий, если прошлые шаги их
  /// меняли.
  Future<Workspace> fresh(Iterable<String> needs) async {
    if (needs.any(_changed.contains)) {
      ws = await _read();
      _changed.clear();
      _added.clear();
      _reopened.clear();
      _copies.clear();
      _dayKeys.clear();
    }
    return ws;
  }

  /// Шаг изменил [keys].
  void changed(Iterable<String> keys) => _changed.addAll(keys);

  /// Активных задач, добавленных в проект [projectId] после чтения снимка.
  int addedTo(String projectId) => _added[projectId] ?? 0;

  /// Шаг вернул в работу задачи [orderKeys] (id → ключ порядка после шага),
  /// и в проекте [projectId] стало на [opening] активных больше.
  void reopened(String projectId, int opening, Map<String, String> orderKeys) {
    _added[projectId] = addedTo(projectId) + opening;
    _reopened.addAll(orderKeys);
  }

  /// Завершена ли [task] с учётом возвращённых прошлыми шагами.
  bool isCompleted(Task task) =>
      task.isCompleted && !_reopened.containsKey(task.id);

  /// Ключ порядка [task] с учётом прошлых шагов.
  String orderKey(Task task) => _reopened[task.id] ?? task.orderKey;

  /// Копии прошлых шагов среди соседей [group]: id и ключ порядка.
  List<(String, String)> copiesIn(String group) => _copies[group] ?? const [];

  /// Шаг создал копию [id] с ключом [orderKey] среди соседей [group], и в
  /// проекте [projectId] стало на [adding] активных больше.
  void copied(
    String group,
    String id,
    String orderKey,
    String projectId,
    int adding,
  ) {
    (_copies[group] ??= []).add((id, orderKey));
    _added[projectId] = addedTo(projectId) + adding;
  }

  /// Ключи порядка дня [date], выданные копиям прошлых шагов.
  List<String> dayKeysOn(String date) => _dayKeys[date] ?? const [];

  void dayKeyUsed(String date, String key) => (_dayKeys[date] ??= []).add(key);
}

/// Возврат удалённых меток задачам, которые возвращаются в работу
/// ([TaskCommands._labelRevival]).
final class _Revival {
  _Revival(this.labels, this.relinks);

  /// Метки, создаваемые заново: id → имя и ключ порядка.
  final Map<String, ({String name, String orderKey})> labels;

  /// Перевязки: задача, удалённая метка, живая метка вместо неё.
  final List<({String task, String from, String to})> relinks;

  bool get isEmpty => relinks.isEmpty;

  /// Что «Отменить» возвращает: связи задач с удалёнными метками.
  List<UndoTarget> get restored => [
    for (final r in relinks)
      (
        entityType: EntityTypes.taskLabel,
        entityId: taskLabelId(r.task, r.from),
        fields: {TaskLabelFields.deleted},
      ),
  ];

  /// Что «Отменить» удаляет, если этого не было до действия: новые связи и
  /// метки, созданные заново ([Mutator.capture], `created`). Уже бывшая
  /// живой связь возвращается как была.
  List<UndoTarget> get created => [
    for (final r in relinks)
      (
        entityType: EntityTypes.taskLabel,
        entityId: taskLabelId(r.task, r.to),
        fields: {TaskLabelFields.deleted},
      ),
    for (final id in labels.keys)
      (
        entityType: EntityTypes.label,
        entityId: id,
        fields: {
          LabelFields.name,
          LabelFields.color,
          LabelFields.orderKey,
          LabelFields.isFavorite,
        },
      ),
  ];
}
