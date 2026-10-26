import 'package:flutter/material.dart';

import '../../../domain/models.dart';
import '../../../domain/tree.dart';
import '../../../domain/workspace.dart';
import 'add_task_editor.dart';
import 'task_row.dart';

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
    this.showProject = false,
    this.hierarchy = true,
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

  /// Показать у задач проект и раздел (список из разных проектов).
  final bool showProject;

  /// `false` — плоский список из разных мест (экран метки): строки не
  /// делаются подзадачами по `Ctrl+]` / `Ctrl+[` — в настоящем списке у
  /// задачи другие соседи, и правка прошла бы незаметно.
  final bool hierarchy;

  Widget _editor(bool top) => AddTaskEditor(
    projectId: projectId,
    sectionId: sectionId,
    parentId: parentId,
    atTop: top,
    labelIds: labelIds,
    onClose: () => onAddAt(AddTaskAt.none),
  );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (canAdd && addAt == AddTaskAt.top) _editor(true),
      for (final item in items)
        TaskRow(
          key: ValueKey(item.value.id),
          item: item,
          ws: ws,
          collapsible: parentId == null,
          showProject: showProject,
          hierarchy: hierarchy,
        ),
      if (canAdd && addAt == AddTaskAt.bottom)
        _editor(false)
      else if (canAdd)
        AddTaskButton(
          label: addLabel,
          onPressed: () => onAddAt(AddTaskAt.bottom),
        ),
    ],
  );
}
