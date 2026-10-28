import '../../../core/clock.dart';
import '../../../core/fractional_index.dart';
import '../../../data/projection/entity_fields.dart';
import '../../../domain/models.dart';
import '../../../domain/rules.dart';
import '../../../domain/workspace.dart';
import '../../../sync/mutator.dart';

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
  });

  final Mutator _mutator;
  final Future<Workspace> Function() _read;
  final AppClock _clock;

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
    final text = content.trim();
    if (text.isEmpty) throw const CommandRejected(RejectReason.emptyName);
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
    final text = content.trim();
    if (text.isEmpty) throw const CommandRejected(RejectReason.emptyName);
    await _update(id, {TaskFields.content: text});
  }

  Future<void> setDescription(String id, String description) =>
      _update(id, {TaskFields.description: description});

  /// Приоритет 1 (P1, высший) … 4 (P4).
  Future<void> setPriority(String id, int priority) {
    RangeError.checkValueInInterval(priority, 1, 4, 'priority');
    return _update(id, {TaskFields.priority: priority});
  }

  /// Срок; `null` убирает срок.
  Future<Undo> setDue(String id, Due? due) async {
    await _alive(id);
    final undo = await _mutator.capture([
      _target(id, {TaskFields.due}),
    ]);
    await _mutator.update(EntityTypes.task, id, {
      TaskFields.due: _dueValue(due),
    });
    return undo;
  }

  /// Дедлайн `YYYY-MM-DD`; `null` убирает.
  Future<void> setDeadline(String id, String? date) =>
      _update(id, {TaskFields.deadline: _deadlineValue(date)});

  /// Длительность; `null` убирает.
  Future<void> setDuration(String id, TaskDuration? duration) =>
      _update(id, {TaskFields.duration: _durationValue(duration)});

  /// Свернуть или развернуть подзадачи.
  Future<void> setCollapsed(String id, bool collapsed) =>
      _update(id, {TaskFields.isCollapsed: collapsed});

  /// Метки задачи ровно [labelIds]: недостающие ставятся, лишние снимаются.
  /// Удалённая метка выполненной задачи в выборе не участвует и остаётся.
  Future<void> setLabels(String id, Set<String> labelIds) async {
    final ws = await _read();
    final task = await _alive(id, ws);
    final current = {
      for (final l in task.labelIds)
        if (ws.label(l) != null) l,
    };
    final wanted = {
      for (final l in labelIds)
        if (ws.label(l) != null) l,
    };
    await _mutator.batch(() async {
      for (final label in wanted.difference(current)) {
        await _link(id, label, linked: true);
      }
      for (final label in current.difference(wanted)) {
        await _link(id, label, linked: false);
      }
    });
  }

  /// Завершить задачу вместе с незавершёнными подзадачами.
  Future<Undo> complete(String id) async {
    final ws = await _read();
    await _alive(id, ws);
    final ids = [
      for (final t in ws.taskSubtree(id))
        if (!ws.task(t)!.isCompleted) t,
    ];
    return markCompleted(ids, completed: true);
  }

  /// Вернуть задачу в работу — как `item_uncomplete` в Todoist API: вместе с
  /// ней возвращаются завершённые предки и архивный раздел корневой задачи,
  /// а возвращённые встают в конец незавершённых соседей (раздел — в конец
  /// разделов проекта). «Отменить» в тосте после завершения сюда не ведёт:
  /// он восстанавливает прежние значения полей, в том числе место.
  ///
  /// Удалённые метки возвращённых задач возвращаются, как в Todoist
  /// ([_reviveLabels]). [Undo] (в интерфейсе его нет) возвращает только поля
  /// задач и раздела, метки остаются.
  Future<Undo> uncomplete(String id) async {
    final ws = await _read();
    var root = await _alive(id, ws);
    final ids = <String>[];
    for (String? t = id; t != null; t = ws.taskParent(t)) {
      root = ws.task(t)!;
      if (root.isCompleted) ids.add(t);
    }
    if (ids.isEmpty) return _mutator.capture(const []);
    final section = ws.section(root.sectionId ?? '');
    final reinstateSection = section != null && section.isArchived;

    // Ключи считаются до записи: соседи — незавершённые и не возвращаемые.
    final keys = <String, String>{
      for (final t in ids)
        t: keyAtEnd([
          for (final s in _siblings(ws, ws.task(t)!))
            if (!s.isCompleted && !ids.contains(s.id)) s.orderKey,
        ]),
    };
    final undo = await _mutator.capture([
      for (final t in ids)
        _target(t, {
          TaskFields.isCompleted,
          TaskFields.completedAt,
          TaskFields.orderKey,
        }),
      if (reinstateSection)
        (
          entityType: EntityTypes.section,
          entityId: section.id,
          fields: {SectionFields.isArchived, SectionFields.orderKey},
        ),
    ]);
    await _mutator.batch(() async {
      for (final t in ids) {
        await _mutator.update(EntityTypes.task, t, {
          TaskFields.isCompleted: false,
          TaskFields.completedAt: null,
          TaskFields.orderKey: keys[t],
        });
      }
      if (reinstateSection) {
        final projectId = section.projectId ?? ws.inbox?.id ?? inboxProjectId;
        await _mutator.update(EntityTypes.section, section.id, {
          SectionFields.isArchived: false,
          SectionFields.orderKey: keyAtEnd([
            for (final s in ws.sectionsOf(projectId)) s.orderKey,
          ]),
        });
      }
      await _reviveLabels(ws, ids);
    });
    return undo;
  }

  /// Удалённые метки задач [ids], которые возвращаются в работу, — как в
  /// Todoist (help «Introduction to labels»): задача получает живую метку с
  /// тем же именем (без учёта регистра), а если её нет — метку, созданную
  /// заново с этим именем, цветом и избранным по умолчанию, в конце списка.
  /// Связь с удалённой меткой снимается: если ту восстановят (выбор на экране
  /// «Конфликты»), задача не понесёт две одноимённые метки. Id новой метки —
  /// [revivedLabelId]: два устройства, вернувшие такие задачи офлайн,
  /// создают одну метку.
  Future<void> _reviveLabels(Workspace ws, List<String> ids) async {
    final byName = <String, String>{};
    for (final l in ws.labels) {
      byName.putIfAbsent(l.name.toLowerCase(), () => l.id);
    }
    final keys = [for (final l in ws.labels) l.orderKey];
    for (final t in ids) {
      for (final old in ws.task(t)!.labelIds) {
        final deleted = ws.deletedLabel(old);
        // Пустое имя — строка известна только по tombstone, поля создателя
        // ещё не пришли: создавать нечего.
        if (deleted == null || deleted.name.trim().isEmpty) continue;
        final target = byName[deleted.name.toLowerCase()] ??= await () async {
          var id = old;
          do {
            id = revivedLabelId(id);
          } while (ws.label(id) != null || ws.deletedLabel(id) != null);
          final key = keyAtEnd(keys);
          keys.add(key);
          await _mutator.update(EntityTypes.label, id, {
            LabelFields.name: deleted.name,
            LabelFields.color: 'charcoal',
            LabelFields.orderKey: key,
            LabelFields.isFavorite: false,
          });
          return id;
        }();
        await _link(t, old, linked: false);
        await _link(t, target, linked: true);
      }
    }
  }

  /// Удалить (tombstone). Подзадачи скрываются вместе с задачей.
  Future<void> delete(String id) async {
    await _alive(id);
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
  }) async {
    final ws = await _read();
    await _alive(id, ws);
    final subtree = ws.taskSubtree(id);
    if (parentId != null) {
      if (subtree.contains(parentId)) {
        throw const CommandRejected(RejectReason.cycle);
      }
      if (ws.taskDepth(parentId) + ws.taskHeight(id) > Limits.taskLevels) {
        throw const CommandRejected(RejectReason.tooDeep);
      }
    }
    final place = _place(
      ws,
      projectId: projectId,
      sectionId: sectionId,
      parentId: parentId,
    );
    final siblings = [
      for (final t in ws.children(
        parentId,
        projectId: place.projectId,
        sectionId: place.sectionId,
      ))
        if (t.id != id) t,
    ];
    // Пишутся поля только самой задачи: проект и раздел подзадач вычисляются
    // по дереву (Workspace.rootProjectOf). Запись в подзадачи спорила бы с
    // их параллельными правками и удалением на другом устройстве.
    final undo = await _mutator.capture([
      _target(id, {
        TaskFields.projectId,
        TaskFields.sectionId,
        TaskFields.parentId,
        TaskFields.orderKey,
      }),
    ]);
    await _mutator.update(EntityTypes.task, id, {
      TaskFields.projectId: place.projectId,
      TaskFields.sectionId: place.sectionId,
      TaskFields.parentId: parentId,
      TaskFields.orderKey: _keyFor(siblings, afterId: afterId, atTop: atTop),
    });
    return undo;
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

  /// Поднять выше соседа (перетаскивание — M4). `false` — задача уже первая.
  Future<bool> moveUp(String id) => _shift(id, up: true);

  /// Опустить ниже соседа (перетаскивание — M4). `false` — задача уже последняя.
  Future<bool> moveDown(String id) => _shift(id, up: false);

  /// Дубликат задачи с незавершёнными подзадачами и метками — сразу после
  /// неё. Возвращает id копии.
  Future<String> duplicate(String id) async {
    final ws = await _read();
    final task = await _alive(id, ws);
    final siblings = _siblings(ws, task);
    final index = siblings.indexWhere((t) => t.id == id);
    return _mutator.batch(
      () => copyTree(
        ws,
        task,
        projectId: ws.rootProjectOf(id),
        sectionId: task.sectionId,
        parentId: ws.taskParent(id),
        orderKey: keyForInsert([
          for (final t in siblings) t.orderKey,
        ], index + 1),
      ),
    );
  }

  /// Копия задачи [source] и её незавершённых подзадач в новое место; для
  /// дубликатов задачи, раздела и проекта. Вызывать внутри [Mutator.batch].
  Future<String> copyTree(
    Workspace ws,
    Task source, {
    required String projectId,
    required String? sectionId,
    required String? parentId,
    required String orderKey,
  }) async {
    final id = await _mutator.create(EntityTypes.task, {
      TaskFields.content: source.content,
      if (source.description.isNotEmpty)
        TaskFields.description: source.description,
      TaskFields.projectId: projectId,
      TaskFields.sectionId: ?sectionId,
      TaskFields.parentId: ?parentId,
      TaskFields.orderKey: orderKey,
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
      );
    }
    return id;
  }

  // --- Внутреннее ---

  /// Отметить задачи [ids] завершёнными или нет одной транзакцией, без
  /// проверок дерева: для действий над группой (завершение с подзадачами,
  /// архив раздела).
  Future<Undo> markCompleted(
    List<String> ids, {
    required bool completed,
  }) async {
    const fields = {TaskFields.isCompleted, TaskFields.completedAt};
    final undo = await _mutator.capture([
      for (final t in ids) _target(t, fields),
    ]);
    final at = completed ? _now() : null;
    await _mutator.batch(() async {
      for (final t in ids) {
        await _mutator.update(EntityTypes.task, t, {
          TaskFields.isCompleted: completed,
          TaskFields.completedAt: at,
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

  /// Проект и раздел нового места: подзадача — как у родителя.
  ({String projectId, String? sectionId}) _place(
    Workspace ws, {
    String? projectId,
    String? sectionId,
    String? parentId,
  }) {
    if (parentId != null) {
      final parent = ws.task(parentId);
      if (parent == null) throw const CommandRejected(RejectReason.notFound);
      return (
        projectId: ws.rootProjectOf(parentId),
        sectionId: parent.sectionId,
      );
    }
    final inbox = ws.inbox?.id ?? inboxProjectId;
    if (sectionId != null) {
      // Проект задачи в разделе — проект раздела; раздел чужого проекта —
      // ошибка вызывающего кода, а не повод создать невидимую задачу.
      final section = ws.section(sectionId);
      final sectionProject = section?.projectId ?? inbox;
      if (section == null ||
          (projectId != null && projectId != sectionProject)) {
        throw const CommandRejected(RejectReason.notFound);
      }
      return (projectId: sectionProject, sectionId: sectionId);
    }
    final project = projectId ?? inbox;
    if (ws.project(project) == null) {
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

  Future<void> _update(String id, Map<String, Object?> fields) async {
    await _alive(id);
    await _mutator.update(EntityTypes.task, id, fields);
  }

  Future<Task> _alive(String id, [Workspace? ws]) async {
    final task = (ws ?? await _read()).task(id);
    if (task == null) throw const CommandRejected(RejectReason.notFound);
    return task;
  }

  static UndoTarget _target(String id, Set<String> fields) =>
      (entityType: EntityTypes.task, entityId: id, fields: fields);

  String _now() => _clock.nowUtc().toIso8601String();

  static Map<String, Object?>? _dueValue(Due? due) => due == null
      ? null
      : ({DueKeys.date: due.date, DueKeys.time: due.time, DueKeys.tz: due.tz}
          ..removeWhere((_, v) => v == null));

  static Map<String, Object?>? _deadlineValue(String? date) =>
      date == null ? null : {DeadlineKeys.date: date};

  static Map<String, Object?>? _durationValue(TaskDuration? d) => d == null
      ? null
      : {DurationKeys.amount: d.amount, DurationKeys.unit: d.unit};
}
