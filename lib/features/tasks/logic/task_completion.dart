part of 'task_commands.dart';

/// Выполнение и возврат в работу: повторяющиеся задачи, «Отложить», снимок
/// имён меток и возврат удалённых меток (О-84).
mixin _Completion on _TaskCore {
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
          ].take(TaskCommands.resetSubtasksLimit).toList()
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
    final next = TaskCommands.postponedDue(due, _clock.nowWall());
    if (task.isCompleted || next == null) return _mutator.capture(const []);
    final undo = await _mutator.capture([_dueTarget(task, next)]);
    await _mutator.update(EntityTypes.task, id, _dueFields(task, next));
    return undo;
  });

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
        : TaskRoom.openInTrees(ws, [
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
    TaskRoom.checkRoom(
      ws,
      projectId,
      opening,
      already: steps.addedTo(projectId),
    );

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
}
