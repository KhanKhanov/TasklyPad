import 'package:flutter/material.dart';

import '../../../domain/models.dart';
import '../../../domain/tree.dart';
import '../../../domain/workspace.dart';
import 'add_task_editor.dart';
import 'task_drag.dart';
import 'task_row.dart';
import 'task_row_parts.dart';
import '../../common/ui/drag_rows.dart';

/// Где открыт редактор «Добавить задачу» в списке.
enum AddTaskAt { none, top, bottom }

/// Задачи одного места (корень проекта, раздел или подзадачи) деревом и
/// «Добавить задачу» в конце. Редактор сверху — по `Shift+A`.
class TaskList extends StatelessWidget {
  const TaskList({
    super.key,
    required this.items,
    required this.ws,
    required this.projectId,
    this.sectionId,
    this.parentId,
    required this.addAt,
    required this.onAddAt,
    this.addLabel,
    this.canAdd = true,
    this.labelIds = const {},
    this.due,
    this.priority,
    this.deadline,
    this.collapseOf,
    this.showProject = false,
    this.hierarchy = true,
    this.drop,
    this.gutter = false,
  });

  final List<TreeItem<Task>> items;
  final Workspace ws;
  final String projectId;
  final String? sectionId;
  final String? parentId;
  final AddTaskAt addAt;
  final ValueChanged<AddTaskAt> onAddAt;
  final String? addLabel;

  /// `false` — проект в архиве: задачи только для просмотра.
  final bool canAdd;

  /// Метки новой задачи: на экране метки задача добавляется с ней.
  final Set<String> labelIds;

  /// Срок новой задачи: в «Сегодня» — сегодня, в «Предстоящем» — день.
  final Due? due;

  /// Приоритет и дедлайн новой задачи: на экране фильтра — из запроса.
  final int? priority;
  final String? deadline;

  /// Свёрнутость подзадач строки вне данных задачи (экран фильтра); `null`
  /// у списка или строки — поле задачи.
  final RowCollapse? Function(TreeItem<Task> item)? collapseOf;

  /// Показать у задач проект и раздел (список из разных проектов).
  final bool showProject;

  /// `false` — плоский список из разных мест (экран метки): строки не
  /// делаются подзадачами по `Ctrl+]` / `Ctrl+[` — в настоящем списке у
  /// задачи другие соседи, и правка прошла бы незаметно.
  final bool hierarchy;

  /// Что можно делать при перетаскивании задач списка; `null` — ничего: ни
  /// ручки, ни места броска (архив, группировка, сортировка с направлением).
  final TaskListDrop? drop;

  /// Слева оставлено поле под ручку ([dragGutter]): экран сдвинул отступ
  /// списка на него, и строки со «Добавить задачу» занимают его место.
  /// Включено у любого списка с [drop].
  final bool gutter;

  bool get _gutter => gutter || drop != null;

  Widget _editor(bool top) => AddTaskEditor(
    projectId: projectId,
    sectionId: sectionId,
    parentId: parentId,
    atTop: top,
    labelIds: labelIds,
    due: due,
    priority: priority,
    deadline: deadline,
    onClose: () => onAddAt(AddTaskAt.none),
  );

  /// Редактор или кнопка «Добавить задачу» в конце списка: слот «в конец».
  Widget _end(Widget add, {bool top = false}) => TaskEndSlot(
    drop: drop,
    items: items,
    atStart: top,
    child: _gutter
        ? Padding(
            padding: const EdgeInsets.only(left: dragGutter),
            child: add,
          )
        : add,
  );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (canAdd && addAt == AddTaskAt.top) _end(_editor(true), top: true),
      for (final item in items)
        _row(
          TaskRow(
            key: ValueKey(item.value.id),
            item: item,
            ws: ws,
            collapsible: parentId == null,
            // Подзадачи в окне задачи не выделяются: панель выделения — под
            // окном, и её клавиши туда не доходят.
            selectable: parentId == null,
            showProject: showProject,
            hierarchy: hierarchy,
            collapse: collapseOf?.call(item),
          ),
          item,
        ),
      if (canAdd && addAt == AddTaskAt.bottom)
        _end(_editor(false))
      else if (canAdd)
        _end(
          AddTaskButton(
            label: addLabel,
            onPressed: () => onAddAt(AddTaskAt.bottom),
          ),
        ),
    ],
  );

  Widget _row(TaskRow row, TreeItem<Task> item) => _gutter
      ? TaskDragRow(
          key: ValueKey(item.value.id),
          item: item,
          items: items,
          drop: drop,
          child: row,
        )
      : row;
}
