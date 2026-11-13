part of 'task_commands.dart';

/// Место задач: перенос и перетаскивание, порядок в дне, сдвиг по уровню и
/// среди соседей, дубликаты (О-84).
mixin _Placement on _TaskCore {
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

  /// Перенести задачу с подзадачами: под [parentId] или в раздел
  /// [sectionId] проекта [projectId]; место — как в [TaskCommands.add].
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
        ? TaskRoom.openInTrees(ws, roots).length
        : 0;
    final staying = {
      for (final root in roots)
        for (final t in ws.taskSubtree(root))
          if (ws.isTaskActive(t) && ws.rootProjectOf(t) == place.projectId) t,
    }.length;
    TaskRoom.checkRoom(ws, place.projectId, opening - staying);
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

  /// [duplicate] каждой из [ids] по порядку — как
  /// [_Completion.completeEach]. Копии прошлых шагов снимок не перечитывают:
  /// их места и число в проекте ведёт [_Steps].
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
        ? 1 +
              TaskRoom.openInTrees(ws, [
                for (final c in ws.children(id)) c.id,
              ]).length
        : 0;
    TaskRoom.checkRoom(
      ws,
      projectId,
      adding,
      already: steps.addedTo(projectId),
    );
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
}
