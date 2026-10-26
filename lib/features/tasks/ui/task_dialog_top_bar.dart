import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/data_providers.dart';
import '../../../app/theme/app_palette.dart';
import '../../../domain/models.dart';
import '../../../domain/workspace.dart';
import '../../../l10n/app_localizations.dart';
import '../../common/ui/ui_kit.dart';
import 'task_actions.dart';

/// Верх панели: путь «проект › раздел», меню и закрыть.
class TaskDialogTopBar extends ConsumerWidget {
  const TaskDialogTopBar({
    super.key,
    required this.task,
    required this.ws,
    this.readOnly = false,
  });

  final Task task;
  final Workspace ws;

  /// Проект в архиве — меню действий не показывается.
  final bool readOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final project = ws.project(ws.rootProjectOf(task.id));
    final parent = ws.task(ws.taskParent(task.id) ?? '');
    final path = [
      if (project != null) projectTitle(l10n, project),
      ?ws.section(task.sectionId ?? '')?.name,
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
          if (!readOnly)
            PopupMenuButton<bool>(
              tooltip: l10n.moreActions,
              icon: const Icon(Icons.more_horiz),
              onSelected: (delete) async {
                if (delete) {
                  await deleteTask(context, ref, task);
                } else {
                  await runCommand(
                    context,
                    () => ref.read(taskCommandsProvider).duplicate(task.id),
                  );
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(value: false, child: Text(l10n.actionDuplicate)),
                PopupMenuItem(value: true, child: Text(l10n.actionDelete)),
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
