part of 'task_commands.dart';

/// Общее у действий над задачами: зависимости, чтение и запись, место в
/// дереве, ключи порядка и значения полей (О-84).
abstract class _TaskCore {
  _TaskCore(
    this._mutator,
    this._read,
    this._clock,
    this._resetRecurringSubtasks,
  );

  final Mutator _mutator;
  final Future<Workspace> Function() _read;
  final AppClock _clock;

  /// Настройка «Сбрасывать подзадачи» (синхронизируется в `settings`).
  final Future<bool> Function() _resetRecurringSubtasks;

  /// Срок задачи — [TaskCommands.setDue]: перенос на день ([_Placement])
  /// проверяет и пишет срок так же, как планировщик.
  Future<Undo> setDue(String id, Due? due, {Workspace? snapshot});

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

  Future<void> _link(String taskId, String labelId, {required bool linked}) =>
      _mutator.update(EntityTypes.taskLabel, taskLabelId(taskId, labelId), {
        TaskLabelFields.taskId: taskId,
        TaskLabelFields.labelId: labelId,
        TaskLabelFields.deleted: !linked,
      });

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

  String _now() => _clock.nowUtc().toIso8601String();

  /// Шаги одного действия над снимком [snapshot] (уже прочитанным в той же
  /// транзакции) или над свежим.
  Future<_Steps> _steps([Workspace? snapshot]) async =>
      _Steps(snapshot ?? await _read(), _read);
}

/// Ключ порядка: после [afterId], в начало или в конец [siblings].
String _keyFor(List<Task> siblings, {String? afterId, bool atTop = false}) {
  final keys = [for (final t in siblings) t.orderKey];
  if (afterId != null) {
    final i = siblings.indexWhere((t) => t.id == afterId);
    if (i >= 0) return keyForInsert(keys, i + 1);
  }
  return atTop ? keyForInsert(keys, 0) : keyAtEnd(keys);
}

String _content(String content) {
  final text = content.trim();
  if (text.isEmpty) throw const CommandRejected(RejectReason.emptyName);
  return Limits.checkLength(text, Limits.taskContent);
}

/// Новый текст срока — до [Limits.dueText] символов. Прежний текст
/// задачи [task] (пришёл с другого устройства длиннее) не проверяется:
/// «Время», перенос дня и «Перенести» его сохраняют.
void _checkDueText(Due? due, [Task? task]) {
  final text = due?.string;
  if (text == null || text == task?.due?.string) return;
  Limits.checkLength(text, Limits.dueText);
}

/// Поля срока: ручной порядок дня относится к дню — срок на другой дате
/// снимает `day_order_key` той же правкой (О-71), иначе ключ старого дня
/// поставил бы задачу выше задач нового. Время внутри дня ключ не снимает.
Map<String, Object?> _dueFields(Task task, Due? due) => {
  TaskFields.due: _dueValue(due),
  if (task.due?.date != due?.date) TaskFields.dayOrderKey: null,
};

/// Что возвращает «Отменить» после смены срока на [due]: только то, что
/// правка пишет ([_dueFields]). Лишнее поле откатило бы правку, пришедшую с
/// другого устройства, пока виден тост.
UndoTarget _dueTarget(Task task, Due? due) => _target(task.id, {
  TaskFields.due,
  if (task.due?.date != due?.date) TaskFields.dayOrderKey,
});

UndoTarget _target(String id, Set<String> fields) =>
    (entityType: EntityTypes.task, entityId: id, fields: fields);

/// Срок целиком, с правилом: ключ, которого нет, `Mutator.update` уберёт
/// из прежнего срока (известный ключ), — срок без правила снимает повтор.
Map<String, Object?>? _dueValue(Due? due) => due == null
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

Map<String, Object?>? _deadlineValue(String? date) =>
    date == null ? null : {DeadlineKeys.date: date};

Map<String, Object?>? _durationValue(TaskDuration? d) => d == null
    ? null
    : {DurationKeys.amount: d.amount, DurationKeys.unit: d.unit};

/// Ключ [_Steps] дерева задачи [id] — по её корневой задаче.
String _treeKey(Workspace ws, String id) {
  var root = id;
  for (var p = ws.taskParent(root); p != null; p = ws.taskParent(p)) {
    root = p;
  }
  return 'tree:$root';
}

/// Соседи задачи по месту ([_siblings]) — одной строкой: родитель или
/// проект и раздел корня.
String _siblingGroup(Workspace ws, Task task) {
  final parent = ws.taskParent(task.id);
  if (parent != null) return 'parent:$parent';
  final section = ws.section(task.sectionId ?? '') == null
      ? ''
      : task.sectionId;
  return 'root:${ws.rootProjectOf(task.id)}:$section';
}

/// Порядок соседей, как в [Workspace]: ключ, затем id.
int _byKeyThenId((String, String) a, (String, String) b) {
  final byKey = a.$2.compareTo(b.$2);
  return byKey != 0 ? byKey : a.$1.compareTo(b.$1);
}

/// Верный ключ порядка: не пустой и не на `0` (fractional_index.dart).
bool _isValidKey(String key) => key.isNotEmpty && !key.endsWith('0');

/// [nextOccurrence] с отказом вместо FormatException: битое правило
/// (пришло с другого устройства) — сообщение пользователю, данные целы.
Due? _next(Due due, DateTime now, {bool postpone = false}) {
  try {
    return nextOccurrence(due, completedAt: now, postpone: postpone);
  } on FormatException {
    throw const CommandRejected(RejectReason.brokenRecurrence);
  }
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
/// ([_Completion._labelRevival]).
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
