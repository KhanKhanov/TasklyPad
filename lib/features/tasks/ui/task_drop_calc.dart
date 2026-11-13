import 'package:flutter/rendering.dart';

import '../../../domain/models.dart';
import '../../../domain/rules.dart';
import '../../../domain/tree.dart';
import '../../../domain/view_options.dart';
import '../../common/state/drag_session.dart';
import '../../common/ui/drag_layer.dart';
import '../../common/ui/drag_rows.dart';
import '../logic/due_dates.dart';
import 'task_drag.dart';
import 'task_drop_places.dart';

/// Куда встанут перетаскиваемые задачи, если бросить их под указателем на
/// строке [rowId] списка [items] (`null` — в конце списка, а при [atStart] —
/// перед первой строкой: открытый сверху редактор): расчёт места и уровня,
/// без записи. `null` — места нет, бросок ничего не сделает.
DropPlace? taskDropPlace(
  TaskListDrop drop,
  DropQuery query,
  RenderBox box, {
  required List<TreeItem<Task>> items,
  String? rowId,
  bool atStart = false,
}) {
  final payload = query.payload;
  if (payload is! TaskDrag) return null;
  // Половина строки по высоте решает, линия над ней или под ней.
  final upper =
      rowId != null &&
      box.globalToLocal(query.pointer).dy < box.size.height / 2;
  return switch (drop) {
    ProjectDrop() => _projectPlace(
      drop,
      payload,
      query,
      items,
      rowId,
      upper,
      atStart,
    ),
    DayDrop() => _dayPlace(drop, payload, items, rowId, upper, atStart),
    OverdueDrop() => null,
  };
}

/// Проект, раздел, подзадачи окна: линия между строками и уровень по сдвигу
/// указателя. Поддеревья переносимых, выполненные строки и всё под
/// выполненной ([frozenIds]) в расчёте не участвуют: над ними линия встаёт
/// после последней активной.
DropPlace? _projectPlace(
  ProjectDrop drop,
  TaskDrag payload,
  DropQuery query,
  List<TreeItem<Task>> items,
  String? rowId,
  bool upper,
  bool atStart,
) {
  final origin = payload.origin;
  // Окно задачи не выпускает подзадачи из родителя; проект — один.
  if (origin is! ProjectDrop ||
      origin.parentId != drop.parentId ||
      origin.projectId != drop.projectId) {
    return null;
  }
  final ws = drop.ws;
  final moved = {for (final id in payload.ids) ...ws.taskSubtree(id)};
  final frozen = frozenIds(items);
  bool keeps(TreeItem<Task> item) =>
      !moved.contains(item.value.id) && !frozen.contains(item.value.id);
  final row = rowId == null
      ? items.length
      : items.indexWhere((i) => i.value.id == rowId);
  if (row < 0) return null;
  final boundary = atStart
      ? 0
      : rowId == null
      ? row
      : row + (upper ? 0 : 1);
  final index = items.take(boundary).where(keeps).length;
  final shown = [
    for (final item in items)
      if (keeps(item))
        TreeItem(item.value, item.depth + drop.baseDepth, item.childCount),
  ];
  final height = payload.ids.fold<int>(1, (h, id) {
    final own = ws.taskHeight(id);
    return own > h ? own : h;
  });
  final at = treeDropPlace(
    shown,
    (task) => task.id,
    index: index,
    wantedDepth: payload.depth + payload.indentShift(query.delta.dx),
    movedHeight: height,
    maxLevels: Limits.taskLevels,
    baseDepth: drop.baseDepth,
  );
  if (at == null) return null;
  return MoveTasksPlace(
    ids: payload.ids,
    projectId: drop.projectId,
    sectionId: drop.sectionId,
    parentId: at.parentId ?? drop.parentId,
    afterId: at.afterId,
    atTop: true,
    indicator: lineBefore(
      [for (final item in shown) item.value.id],
      index,
      endOwner: drop.endOwner,
      indent: dragGutter + (at.depth - drop.baseDepth) * taskIndentStep,
    ),
  );
}

/// День: «Сегодня» и «Предстоящее». Линия ходит только там, где задача
/// реально встанет: при «Умной» — среди задач с тем же сроком, приоритетом и
/// дедлайном (решение 1А «Ход M4.9»), при «Вручную» — среди всех задач дня.
DropPlace? _dayPlace(
  DayDrop drop,
  TaskDrag payload,
  List<TreeItem<Task>> items,
  String? rowId,
  bool upper,
  bool atStart,
) {
  final origin = payload.origin;
  if (origin is! DayDrop && origin is! OverdueDrop) return null;
  final task = payload.task;
  final active = [
    for (final item in items)
      if (!item.value.isCompleted) item.value,
  ];
  final row = rowId == null
      ? null
      : items.where((i) => i.value.id == rowId).firstOrNull?.value;
  // Ниже последней активной строки (выполненные, «Добавить задачу»,
  // свободное место): в «Сегодня» — «на завтра», иначе — в конец дня.
  final below = !atStart && (rowId == null || (row != null && row.isCompleted));
  if (below && drop.tomorrow != null) {
    // Линия и подпись — на строке или слоте под указателем: зона «на завтра»
    // под длинным списком может быть вне экрана.
    return tomorrowPlace(
      payload,
      drop.tomorrow!,
      owner: rowId ?? drop.endOwner,
      label: drop.tomorrowLabel,
    );
  }
  final others = [
    for (final t in active)
      if (t.id != task.id) t,
  ];
  final int index;
  if (below) {
    index = others.length;
  } else if (atStart) {
    index = 0;
  } else {
    final at = active.indexWhere((t) => t.id == rowId);
    if (at < 0) return null;
    index = dropIndex(active, at, upper: upper, keeps: (t) => t.id != task.id);
  }
  final sameDay = task.due?.date == drop.date;
  final moved = task.copyWith(due: dueOnDate(task.due, drop.date));
  final classIdx = [
    for (var i = 0; i < others.length; i++)
      if (drop.sorting == Sorting.manual ||
          drop.order.sameBeforeDayOrder(moved, others[i]))
        i,
  ];
  if (classIdx.isEmpty) {
    // Своего класса среди задач дня нет: в дне задача встанет по порядку вида,
    // а ручной порядок не пишется — бросок на день целиком. Линия — на этом
    // месте; на своём дне ничего не меняется.
    if (sameDay) return null;
    return MoveToDayPlace(
      id: task.id,
      date: drop.date,
      indicator: lineBefore(
        [for (final t in others) t.id],
        others.where((t) => drop.order.compare(t, moved) < 0).length,
        endOwner: drop.endOwner,
        indent: dragGutter,
      ),
    );
  }
  final first = classIdx.first;
  final last = classIdx.last + 1;
  final line = index < first
      ? first
      : index > last
      ? last
      : index;
  return ReorderInDayPlace(
    id: task.id,
    date: drop.date,
    // Строка над местом как есть: команда сама ставит задачу первой или
    // последней в её группе.
    afterId: afterIdAt([for (final t in others) t.id], line),
    sorting: drop.sorting,
    changesDate: !sameDay,
    indicator: lineBefore(
      [for (final t in others) t.id],
      line,
      endOwner: drop.endOwner,
      indent: dragGutter,
    ),
  );
}

/// Бросок на заголовок дня [date]: меняется только дата. На свой день и
/// чужой груз — `null`.
DropPlace? dayHeaderPlace(DragPayload drag, String date) {
  if (drag is! TaskDrag) return null;
  final origin = drag.origin;
  if ((origin is! DayDrop && origin is! OverdueDrop) ||
      drag.task.due?.date == date) {
    return null;
  }
  return MoveToDayPlace(
    id: drag.task.id,
    date: date,
    indicator: DropIndicator(owner: 'day:$date', mark: DropMark.frame),
  );
}

/// Бросок «на завтра» в «Сегодня»: линия с подписью [label] («Завтра») у
/// [owner] — зоны под списком, строки или «Добавить задачу» под указателем.
DropPlace? tomorrowPlace(
  DragPayload drag,
  String date, {
  required Object owner,
  String? label,
}) {
  if (drag is! TaskDrag) return null;
  final origin = drag.origin;
  if (origin is! DayDrop && origin is! OverdueDrop) return null;
  return MoveToDayPlace(
    id: drag.task.id,
    date: date,
    indicator: DropIndicator(
      owner: owner,
      mark: DropMark.above,
      indent: dragGutter,
      caption: label,
    ),
  );
}
