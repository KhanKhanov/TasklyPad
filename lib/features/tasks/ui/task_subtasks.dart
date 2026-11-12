import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/data_providers.dart';
import '../../../app/theme/app_palette.dart';
import '../../../domain/models.dart';
import '../../../domain/view_options.dart';
import '../../../domain/workspace.dart';
import '../../../l10n/app_localizations.dart';
import '../../common/ui/ui_kit.dart';
import '../../views/state/view_options.dart';
import 'task_drag.dart';
import 'task_list.dart';
import 'task_order.dart';

/// «Подзадачи» в панели задачи: заголовок, «Показать / скрыть выполненные»
/// и список с «Добавить подзадачу». Показ выполненных запоминается для задачи
/// и синхронизируется — настройка вида [ViewType.task] (решение 1Б «M4.10a»
/// plans/m4).
class TaskSubtasks extends ConsumerStatefulWidget {
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
  ConsumerState<TaskSubtasks> createState() => _TaskSubtasksState();
}

class _TaskSubtasksState extends ConsumerState<TaskSubtasks> {
  AddTaskAt _addAt = AddTaskAt.none;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final ws = widget.ws;
    final task = widget.task;
    final progress = ws.subtaskProgress(task.id);
    final options = ref.watch(viewOptionsProvider(ViewType.task, task.id));
    final showCompleted = options.showCompletedTasks;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Row(
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
                onPressed: () => runCommand(
                  context,
                  () => ref
                      .read(viewOptionsCommandsProvider)
                      .save(
                        options,
                        options.copyWith(showCompletedTasks: !showCompleted),
                      ),
                ),
                child: Text(
                  showCompleted ? l10n.hideCompleted : l10n.showCompleted,
                ),
              ),
            ],
          ),
        ),
        TaskOrderScope(
          order: (ws) => [
            for (final item in ws.subtasksOf(
              task.id,
              showCompleted: showCompleted,
            ))
              item.value.id,
          ],
          child: TaskList(
            items: ws.subtasksOf(task.id, showCompleted: showCompleted),
            ws: ws,
            projectId: ws.rootProjectOf(task.id),
            parentId: task.id,
            addAt: _addAt,
            onAddAt: (v) => setState(() => _addAt = v),
            addLabel: l10n.addSubtask,
            canAdd: !widget.readOnly,
            // Подзадачи переставляются и меняют уровень, но из родителя не
            // выходят; в архиве — только просмотр.
            gutter: true,
            drop: widget.readOnly
                ? null
                : ProjectDrop(
                    ws: ws,
                    projectId: ws.rootProjectOf(task.id),
                    parentId: task.id,
                    baseDepth: ws.taskDepth(task.id),
                  ),
          ),
        ),
      ],
    );
  }
}
