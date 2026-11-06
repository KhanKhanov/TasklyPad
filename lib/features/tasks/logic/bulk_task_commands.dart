import '../../../domain/models.dart';
import '../../../domain/rules.dart';
import '../../../domain/workspace.dart';
import '../../../sync/mutator.dart';
import 'due_dates.dart';
import 'task_commands.dart';

/// Действия над выделенными задачами (help «Add or manage multiple tasks»,
/// решение 9 плана M4): каждое — одна транзакция, всё или ничего (отказ на
/// одной задаче отменяет действие целиком), а действие с «Отменить» — одна
/// отмена на все задачи. Шаги — те же одиночные правки [TaskCommands]:
/// задача меняется так же, как если бы её правили по одной.
///
/// [ids] — в порядке списка, где их выделили: в нём задачи встают при
/// переносе и дубликате. Задачи, которых уже нет (удалены, в том числе на
/// другом устройстве, пока были выделены), пропускаются. Перенос, дубликат
/// и удаление берут задачу с подзадачами, поэтому подзадача, родитель
/// которой тоже выделен, отдельно не трогается: иначе её скопировало бы
/// дважды.
final class BulkTaskCommands {
  BulkTaskCommands({
    required this._mutator,
    required this._read,
    required this._tasks,
  });

  final Mutator _mutator;
  final Future<Workspace> Function() _read;
  final TaskCommands _tasks;

  /// «Срок» (решение 1А «Ход M4.8»): у [due] только дата (нет времени,
  /// правила и введённого текста — так её отдают календарь и быстрые
  /// варианты планировщика) — у каждой задачи остаются её время, пояс и
  /// правило, у повторяющейся переносится вхождение, как «Перенести»; иначе
  /// срок [due] целиком у всех; `null` — «Без срока».
  Future<Undo> setDue(List<String> ids, Due? due) => _mutator.batch(() async {
    final ws = await _read();
    final dateOnly =
        due != null &&
        due.time == null &&
        due.rule == null &&
        due.string == null;
    return _mutator.combine([
      for (final id in _alive(ws, ids))
        await _tasks.setDue(
          id,
          dateOnly ? dueOnDate(ws.task(id)!.due, due.date) : due,
          snapshot: ws,
        ),
    ]);
  });

  /// «Перенести в…» — в конец проекта или раздела, в порядке [ids].
  Future<Undo> move(List<String> ids, String projectId, String? sectionId) =>
      moveMany(ids, projectId: projectId, sectionId: sectionId);

  /// Поставить выделенные подряд на одно место (перетаскивание, «Перенести
  /// в…»), в порядке [ids]; место — как у [TaskCommands.placeAll].
  Future<Undo> moveMany(
    List<String> ids, {
    String? projectId,
    String? sectionId,
    String? parentId,
    String? afterId,
    bool atTop = false,
  }) => _mutator.batch(() async {
    final roots = _roots(await _read(), ids);
    return _tasks.placeAll(
      roots,
      projectId: projectId,
      sectionId: sectionId,
      parentId: parentId,
      afterId: afterId,
      atTop: atTop,
    );
  });

  /// «Метки» добавляют [labelIds] к меткам каждой задачи (help: «Adds a
  /// label»); снятых нет. Задача, у которой прибавились бы метки сверх
  /// [Limits.labelsPerTask], — отказ всего действия до записи.
  Future<void> addLabels(List<String> ids, Set<String> labelIds) =>
      _mutator.batch(() async {
        final ws = await _read();
        final wanted = {
          for (final l in labelIds)
            if (ws.label(l) != null) l,
        };
        final changed = <String, Set<String>>{};
        for (final id in _alive(ws, ids)) {
          final current = {
            for (final l in ws.task(id)!.labelIds)
              if (ws.label(l) != null) l,
          };
          final next = {...current, ...wanted};
          if (next.length == current.length) continue;
          if (next.length > Limits.labelsPerTask) {
            throw const CommandRejected(RejectReason.tooManyLabels);
          }
          changed[id] = next;
        }
        for (final MapEntry(key: id, value: labels) in changed.entries) {
          await _tasks.setLabels(id, labels, snapshot: ws);
        }
      });

  Future<void> setPriority(List<String> ids, int priority) =>
      _mutator.batch(() async {
        final ws = await _read();
        for (final id in _alive(ws, ids)) {
          await _tasks.setPriority(id, priority, snapshot: ws);
        }
      });

  /// Дедлайн `YYYY-MM-DD` у всех; `null` убирает.
  Future<void> setDeadline(List<String> ids, String? date) =>
      _mutator.batch(() async {
        final ws = await _read();
        for (final id in _alive(ws, ids)) {
          await _tasks.setDeadline(id, date, snapshot: ws);
        }
      });

  /// «Выполнить»: каждая выделенная незавершённая — как кружком
  /// (повторяющаяся получает следующий срок). Подзадача выделенного родителя
  /// не пропускается: выполнение повторяющегося родителя её не закрывает, а
  /// закрытая вместе с родителем — пустой шаг. Родители — раньше подзадач:
  /// сброс подзадач повторяющегося родителя не вернёт только что выполненную.
  Future<Undo> complete(List<String> ids) => _mutator.batch(() async {
    final ws = await _read();
    final alive = _alive(ws, ids);
    final order = {for (var i = 0; i < alive.length; i++) alive[i]: i};
    final byDepth = [...alive]
      ..sort((a, b) {
        final depth = ws.taskDepth(a).compareTo(ws.taskDepth(b));
        return depth != 0 ? depth : order[a]!.compareTo(order[b]!);
      });
    return _mutator.combine([
      for (final id in byDepth)
        if (!ws.task(id)!.isCompleted) await _tasks.complete(id),
    ]);
  });

  /// «Вернуть» выполненные задачи.
  Future<Undo> uncomplete(List<String> ids) => _mutator.batch(() async {
    final ws = await _read();
    return _mutator.combine([
      for (final id in _alive(ws, ids))
        if (ws.task(id)!.isCompleted) await _tasks.uncomplete(id),
    ]);
  });

  /// «Дублировать»: копия каждой — сразу после неё.
  Future<void> duplicate(List<String> ids) => _mutator.batch(() async {
    for (final id in _roots(await _read(), ids)) {
      await _tasks.duplicate(id);
    }
  });

  /// «Удалить» — после подтверждения, без «Отменить», как одиночное.
  Future<void> delete(List<String> ids) => _mutator.batch(() async {
    final ws = await _read();
    for (final id in _roots(ws, ids)) {
      await _tasks.delete(id, snapshot: ws);
    }
  });

  static List<String> _alive(Workspace ws, List<String> ids) => [
    for (final id in {...ids})
      if (ws.task(id) != null) id,
  ];

  /// Выделенные, у которых ни один предок не выделен.
  static List<String> _roots(Workspace ws, List<String> ids) {
    final selected = ids.toSet();
    bool covered(String id) {
      for (var p = ws.taskParent(id); p != null; p = ws.taskParent(p)) {
        if (selected.contains(p)) return true;
      }
      return false;
    }

    return [
      for (final id in _alive(ws, ids))
        if (!covered(id)) id,
    ];
  }
}
