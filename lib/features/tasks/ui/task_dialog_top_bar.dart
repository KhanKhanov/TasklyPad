import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/data_providers.dart';
import '../../../app/theme/app_palette.dart';
import '../../../domain/models.dart';
import '../../../domain/workspace.dart';
import '../../../l10n/app_localizations.dart';
import '../../common/ui/ui_kit.dart';
import 'task_actions.dart';

enum _Action { complete, completeForever, completeReset, duplicate, delete }

/// Верх панели: путь «проект › раздел», стрелки к соседним задачам, меню и
/// закрыть.
class TaskDialogTopBar extends ConsumerWidget {
  const TaskDialogTopBar({
    super.key,
    required this.task,
    required this.ws,
    this.readOnly = false,
    this.onPrevious,
    this.onNext,
  });

  final Task task;
  final Workspace ws;

  /// Проект в архиве — меню действий не показывается.
  final bool readOnly;

  /// Стрелки «предыдущая / следующая задача» (`K` / `J`); `null` — нет соседа.
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final project = ws.project(ws.rootProjectOf(task.id));
    final parent = ws.task(ws.taskParent(task.id) ?? '');
    final recurring = (task.due?.isRecurring ?? false) && !task.isCompleted;
    final path = [
      if (project != null) projectTitle(l10n, project),
      ?ws.rootSectionOf(task.id)?.name,
      ?parent?.content,
    ].join(' › ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              path,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: palette.textSecondary, fontSize: 13),
            ),
          ),
          IconButton(
            tooltip: l10n.previousTask,
            icon: const Icon(Icons.keyboard_arrow_up),
            onPressed: onPrevious,
          ),
          IconButton(
            tooltip: l10n.nextTask,
            icon: const Icon(Icons.keyboard_arrow_down),
            onPressed: onNext,
          ),
          if (!readOnly)
            PopupMenuButton<_Action>(
              tooltip: l10n.moreActions,
              icon: const Icon(Icons.more_horiz),
              onSelected: (action) => switch (action) {
                _Action.complete => toggleComplete(context, ref, task),
                _Action.completeForever => completeForever(context, ref, task),
                _Action.completeReset => completeResettingSubtasks(
                  context,
                  ref,
                  task,
                ),
                _Action.duplicate => runCommand(
                  context,
                  () => ref.read(taskCommandsProvider).duplicate(task.id),
                ),
                _Action.delete => deleteTask(context, ref, task),
              },
              itemBuilder: (context) => [
                // Пункты повторяющейся задачи — в меню «⋯» окна задачи, как
                // в help (решения 5А и 3А «Ход M3.7»): «Выполнить» — это
                // вхождение, как кружок.
                if (recurring) ...[
                  PopupMenuItem(
                    value: _Action.complete,
                    child: Text(l10n.completeTask),
                  ),
                  PopupMenuItem(
                    value: _Action.completeForever,
                    child: Text(l10n.completeForever),
                  ),
                  if (ws.children(task.id).isNotEmpty)
                    PopupMenuItem(
                      value: _Action.completeReset,
                      child: Text(l10n.completeResetSubtasks),
                    ),
                  const PopupMenuDivider(),
                ],
                PopupMenuItem(
                  value: _Action.duplicate,
                  child: Text(l10n.actionDuplicate),
                ),
                PopupMenuItem(
                  value: _Action.delete,
                  child: Text(l10n.actionDelete),
                ),
              ],
            ),
          IconButton(
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
