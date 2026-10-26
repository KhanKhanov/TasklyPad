import 'package:flutter/material.dart';

import '../../../app/theme/app_palette.dart';
import '../../../domain/models.dart';
import '../../../domain/workspace.dart';
import '../../../l10n/app_localizations.dart';
import 'task_list.dart';
import 'task_order.dart';

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
    final progress = ws.subtaskProgress(task.id);
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
            // Прогресс, как в окне задачи Todoist (блог «New task view»).
            if (progress.total > 0) ...[
              const SizedBox(width: 10),
              SizedBox.square(
                dimension: 14,
                child: CircularProgressIndicator(
                  value: progress.done / progress.total,
                  strokeWidth: 2.5,
                  color: palette.accent,
                  backgroundColor: palette.divider,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${progress.done}/${progress.total}',
                style: TextStyle(color: palette.textSecondary, fontSize: 12),
              ),
            ],
            const Spacer(),
            TextButton(
              onPressed: () => setState(() => _showCompleted = !_showCompleted),
              child: Text(
                _showCompleted ? l10n.hideCompleted : l10n.showCompleted,
              ),
            ),
          ],
        ),
        TaskOrderScope(
          order: (ws) => [
            for (final item in ws.subtasksOf(
              task.id,
              showCompleted: _showCompleted,
            ))
              item.value.id,
          ],
          child: TaskList(
            items: ws.subtasksOf(task.id, showCompleted: _showCompleted),
            ws: ws,
            projectId: ws.rootProjectOf(task.id),
            parentId: task.id,
            addAt: _addAt,
            onAddAt: (v) => setState(() => _addAt = v),
            addLabel: l10n.addSubtask,
            canAdd: !widget.readOnly,
          ),
        ),
      ],
    );
  }
}
