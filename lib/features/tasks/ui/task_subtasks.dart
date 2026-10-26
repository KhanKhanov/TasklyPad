import 'package:flutter/material.dart';

import '../../../app/theme/app_palette.dart';
import '../../../domain/models.dart';
import '../../../domain/workspace.dart';
import '../../../l10n/app_localizations.dart';
import 'task_list.dart';

/// «Подзадачи» в панели задачи: заголовок, «Показать / скрыть выполненные»
/// и список с «Добавить подзадачу». Показ выполненных здесь — на время, пока
/// панель открыта.
class TaskSubtasks extends StatefulWidget {
  const TaskSubtasks({
    super.key,
    required this.task,
    required this.ws,
    required this.readOnly,
  });

  final Task task;
  final Workspace ws;
  final bool readOnly;

  @override
  State<TaskSubtasks> createState() => _TaskSubtasksState();
}

class _TaskSubtasksState extends State<TaskSubtasks> {
  bool _showCompleted = false;
  AddTaskAt _addAt = AddTaskAt.none;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final ws = widget.ws;
    final task = widget.task;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              l10n.subtasks,
              style: TextStyle(
                color: palette.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => setState(() => _showCompleted = !_showCompleted),
              child: Text(
                _showCompleted ? l10n.hideCompleted : l10n.showCompleted,
              ),
            ),
          ],
        ),
        TaskList(
          items: ws.subtasksOf(task.id, showCompleted: _showCompleted),
          ws: ws,
          projectId: ws.rootProjectOf(task.id),
          parentId: task.id,
          addAt: _addAt,
          onAddAt: (v) => setState(() => _addAt = v),
          addLabel: l10n.addSubtask,
          canAdd: !widget.readOnly,
        ),
      ],
    );
  }
}
