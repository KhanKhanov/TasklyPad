import 'package:flutter/material.dart';

import '../../../domain/models.dart';
import '../../../domain/workspace.dart';
import '../../common/ui/drag_rows.dart';
import '../../common/ui/drag_source.dart';
import '../../sections/ui/section_block.dart';
import '../../sections/ui/section_drag.dart';
import '../../tasks/ui/task_drag.dart';
import '../../tasks/ui/task_drop_places.dart';
import '../../tasks/ui/task_list.dart';
import 'project_parts.dart';

/// Задачи без раздела и разделы проекта со своими задачами (список без
/// группировки): заголовок раздела с ручкой, слоты броска, «Добавить задачу»
/// в каждом месте. [drags] — задачи можно перетаскивать (проект не в архиве,
/// сортировка без направления). [addAt] и [onAddAt] — открытый редактор
/// задачи у места (`null` — без раздела), им владеет экран.
List<Widget> sectionedChildren({
  required Workspace ws,
  required String projectId,
  required ProjectView view,
  required bool canAdd,
  required bool drags,
  required AddTaskAt Function(String? sectionId) addAt,
  required void Function(String? sectionId, AddTaskAt at) onAddAt,
}) {
  final active = [
    for (final (:section, tasks: _) in view.sections)
      if (!section.isArchived) section,
  ];
  ProjectDrop? drop(String? sectionId) => drags
      ? ProjectDrop(ws: ws, projectId: projectId, sectionId: sectionId)
      : null;
  return [
    TaskList(
      items: view.unsectioned,
      ws: ws,
      projectId: projectId,
      addAt: addAt(null),
      onAddAt: (at) => onAddAt(null, at),
      canAdd: canAdd,
      drop: drop(null),
      gutter: true,
    ),
    if (view.unsectioned.isEmpty && view.sections.isEmpty)
      const DragGutter(child: ProjectEmpty()),
    for (final (:section, :tasks) in view.sections) ...[
      sectionHeaderSlot(
        // Разделы переставляются и при сортировке: она действует внутри
        // раздела; архивные — не источник и не цель.
        enabled: canAdd && !section.isArchived,
        section: section,
        projectId: projectId,
        sections: active,
        child: section.isArchived
            ? _sectionBlock(ws, projectId, section, !canAdd)
            : SectionDropSlot(
                projectId: projectId,
                sectionId: section.id,
                enabled: drags,
                child: _sectionBlock(ws, projectId, section, !canAdd),
              ),
      ),
      if (!section.isCollapsed)
        sectionTasksSlot(
          enabled: canAdd && !section.isArchived,
          section: section,
          projectId: projectId,
          child: TaskList(
            key: ValueKey('tasks-${section.id}'),
            items: tasks,
            ws: ws,
            projectId: projectId,
            sectionId: section.id,
            addAt: addAt(section.id),
            onAddAt: (at) => onAddAt(section.id, at),
            canAdd: canAdd && !section.isArchived,
            drop: section.isArchived ? null : drop(section.id),
            gutter: true,
          ),
        ),
    ],
  ];
}

Widget _sectionBlock(
  Workspace ws,
  String projectId,
  Section section,
  bool readOnly,
) => DragBlocker(
  // Слот броска задач стоит снаружи: пока тащат, «⋯» заголовка не оживает.
  child: SectionBlock(
    key: ValueKey(section.id),
    section: section,
    count: ws.activeTaskCountIn(projectId, section.id),
    readOnly: readOnly,
  ),
);
