import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/data_providers.dart';
import '../../../domain/models.dart';
import '../../../domain/tree.dart';
import '../../../domain/view_options.dart';
import '../../../domain/view_order.dart';
import '../../../domain/workspace.dart';
import '../../common/ui/drag_rows.dart';
import '../../common/ui/drag_source.dart';
import '../../common/state/drag_session.dart';
import '../state/selection.dart';
import 'task_drag_ghost.dart';
import 'task_drag_payload.dart';
import 'task_drop_calc.dart';

export 'task_drag_payload.dart';
export 'task_end_slot.dart';

/// Шаг уровня подзадачи в строке (как отступ в `TaskRow`).
const double taskIndentStep = 28;

/// Список, из которого тащат задачи и в который их бросают: что с ним можно
/// делать при перетаскивании. Нет значения — нет ни ручки, ни слота.
sealed class TaskListDrop {
  const TaskListDrop();

  /// Владелец линии «в конец списка» (у «Добавить задачу»).
  Object get endOwner;
}

/// Проект, раздел или подзадачи в окне задачи: перестановка, уровень, раздел,
/// несколько выделенных вместе.
final class ProjectDrop extends TaskListDrop {
  const ProjectDrop({
    required this.ws,
    required this.projectId,
    this.sectionId,
    this.parentId,
    this.baseDepth = 0,
  });

  final Workspace ws;
  final String projectId;
  final String? sectionId;

  /// Подзадачи окна задачи: родитель, из которого они не выходят.
  final String? parentId;

  /// Уровень корней списка (0 — верх проекта; у подзадач окна — уровень
  /// родителя): от него считаются пределы вложенности.
  final int baseDepth;

  /// Выделенные тащатся вместе: только в списках вида, не в окне задачи.
  bool get multi => parentId == null;

  @override
  Object get endOwner => 'end:$projectId/$sectionId/$parentId';
}

/// День в «Сегодня» или «Предстоящем»: перестановка среди задач дня
/// ([TaskCommands.reorderInDay]), уровень не меняется.
final class DayDrop extends TaskListDrop {
  const DayDrop({
    required this.date,
    required this.sorting,
    required this.order,
    this.tomorrow,
    this.tomorrowLabel,
  });

  final String date;
  final Sorting sorting;
  final TaskOrder order;

  /// «Сегодня»: всё ниже последней активной строки — бросок «на завтра»
  /// (решение 2А «Ход M4.9»). `null` — «Предстоящее».
  final String? tomorrow;

  /// Подпись «Завтра» у линии зоны «на завтра».
  final String? tomorrowLabel;

  @override
  Object get endOwner => 'end-day:$date';
}

/// «Просрочено»: задачи можно только брать, перестановки нет.
final class OverdueDrop extends TaskListDrop {
  const OverdueDrop();

  @override
  Object get endOwner => 'end-overdue';
}

/// Строка задачи в списке с перетаскиванием: поле под ручку слева, ручка при
/// наведении мыши, долгое нажатие касанием, слот броска и отметка места.
/// Без [drop] — ни ручки, ни слота, только поле слева, чтобы строки не сдвигались.
class TaskDragRow extends ConsumerStatefulWidget {
  const TaskDragRow({
    super.key,
    required this.item,
    required this.items,
    required this.drop,
    required this.child,
  });

  final TreeItem<Task> item;

  /// Все строки списка, где стоит эта, — для расчёта места.
  final List<TreeItem<Task>> items;
  final TaskListDrop? drop;
  final Widget child;

  @override
  ConsumerState<TaskDragRow> createState() => _TaskDragRowState();
}

class _TaskDragRowState extends ConsumerState<TaskDragRow> {
  bool _hover = false;

  Task get _task => widget.item.value;

  /// Выделенные тащатся вместе, если взялись за выделенную мышью: help «Add
  /// or manage multiple tasks» — переставлять несколько задач можно только в
  /// веб-версии и на компьютере, долгое нажатие на телефоне тащит одну.
  List<String> _pick({required bool multi}) {
    final drop = widget.drop;
    if (multi && drop is ProjectDrop && drop.multi) {
      final ws = ref.read(workspaceProvider).value;
      final selection = ref.read(taskSelectionProvider);
      if (ws != null && selection.contains(_task.id)) {
        final live = selection.live(ws);
        if (live.length > 1 && live.contains(_task.id)) return live;
      }
    }
    return [_task.id];
  }

  /// Мышь тянет за ручку (она левее кружка на поле и ниже на 6), касание —
  /// за всю строку с полем и отступом уровня. Образ — шириной со строку.
  TaskDrag _payload(TaskListDrop drop, {required bool multi}) {
    final indent = dragGutter + widget.item.depth * taskIndentStep;
    return TaskDrag(
      task: _task,
      depth: widget.item.depth + (drop is ProjectDrop ? drop.baseDepth : 0),
      origin: drop,
      pick: () => _pick(multi: multi),
      ghostOrigin: multi ? const Offset(dragGutter, -6) : Offset(indent, 0),
      measure: () {
        final box = context.findRenderObject();
        return box is RenderBox && box.hasSize ? box.size.width - indent : 400;
      },
    );
  }

  /// Дерево не зависит от [TaskDragRow.drop] и «можно тащить»: смена типа
  /// виджета над [TaskDragRow.child] пересоздала бы строку и унесла фокус
  /// (выполнили `e` с «Выполненными» — строка заморожена; сменили сортировку).
  /// Запрет — выключенный источник (`maxSimultaneousDrags: 0`) и слот,
  /// который отвечает «не моё».
  @override
  Widget build(BuildContext context) {
    final drop = widget.drop;
    // Выполненную задачу и всё под ней не тащат, но линия над ней нужна.
    final canDrag = drop != null && !frozenIds(widget.items).contains(_task.id);
    final dragging = ref.watch(dragSessionProvider.select((s) => s != null));
    final touch = canDrag ? _payload(drop, multi: false) : null;
    final mouse = canDrag ? _payload(drop, multi: true) : null;
    final Widget row = Stack(
      children: [
        TouchDraggable(
          data: touch,
          maxSimultaneousDrags: canDrag ? 1 : 0,
          feedback: touch == null
              ? const SizedBox.shrink()
              : TaskDragGhost(payload: touch),
          child: Padding(
            padding: const EdgeInsets.only(left: dragGutter),
            child: widget.child,
          ),
        ),
        // Ручка — при наведении и пока никого не тащат.
        if (canDrag && _hover && !dragging)
          Positioned(
            left: widget.item.depth * taskIndentStep,
            top: 6,
            width: dragGutter,
            height: 32,
            child: MouseDraggable(
              data: mouse,
              feedback: TaskDragGhost(payload: mouse!),
              child: const DragGrip(),
            ),
          ),
      ],
    );
    return DropArea(
      owner: _task.id,
      resolve: (query, box) => drop == null || drop is OverdueDrop
          ? null
          : taskDropPlace(
              drop,
              query,
              box,
              items: widget.items,
              rowId: _task.id,
            ),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: DragSourceDim(
          id: _task.id,
          child: DragBlocker(child: row),
        ),
      ),
    );
  }
}
