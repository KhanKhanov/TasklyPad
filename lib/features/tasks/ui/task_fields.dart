import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/data_providers.dart';
import '../../../app/theme/app_palette.dart';
import '../../../domain/models.dart';
import '../../../domain/workspace.dart';
import '../../../l10n/app_localizations.dart';
import '../../common/ui/ui_kit.dart';
import '../state/today.dart';
import 'deadline_dialog.dart';
import 'due_ui.dart';
import 'task_edits.dart';
import 'task_field_menus.dart';

/// Правая колонка панели задачи, как в Todoist: Проект, Срок (с длительностью
/// при времени), Дедлайн, Приоритет, Метки.
class TaskFields extends ConsumerWidget {
  const TaskFields({
    super.key,
    required this.task,
    required this.ws,
    this.readOnly = false,
  });

  final Task task;
  final Workspace ws;

  /// Проект в архиве — поля только показываются.
  final bool readOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final commands = ref.read(taskCommandsProvider);
    final today = ref.watch(todayProvider);
    final project = ws.project(ws.rootProjectOf(task.id));
    final section = ws.rootSectionOf(task.id);
    final due = task.due;
    // Прошедший дедлайн повторяющейся задачи пропадает и из окна задачи
    // (help: «disappear from the task view», решение 1А «Ход M3.7»); значение
    // хранится, новый дедлайн его заменяет.
    final deadline = switch (task.deadline) {
      final d? when deadlineShown(task, d, today) => d,
      _ => null,
    };
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TaskField(
            label: l10n.fieldProject,
            onTap: readOnly ? null : () => moveTaskTo(context, ref, task),
            child: Row(
              children: [
                if (project != null && !project.isInbox)
                  ProjectHash(color: project.color, size: 15),
                Flexible(
                  child: Text(
                    [
                      if (project != null) projectTitle(l10n, project),
                      ?section?.name,
                    ].join(' / '),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          TaskField(
            label: l10n.fieldDue,
            onTap: readOnly ? null : () => editDue(context, ref, task),
            child: due == null
                ? Text(
                    l10n.noDue,
                    style: TextStyle(color: palette.textSecondary),
                  )
                : Builder(
                    builder: (context) {
                      final label = dueLabelOf(context, ref, due, today);
                      final rule = repeatText(context, due);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label.text,
                            style: TextStyle(color: label.color),
                          ),
                          if (rule != null)
                            Row(
                              children: [
                                Icon(
                                  Icons.repeat,
                                  size: 14,
                                  color: palette.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    rule,
                                    style: TextStyle(
                                      color: palette.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      );
                    },
                  ),
          ),
          DurationField(task: task, enabled: !readOnly),
          TaskField(
            label: l10n.fieldDeadline,
            onTap: readOnly
                ? null
                : () async {
                    final picked = await pickDeadline(context, ref, deadline);
                    if (picked == null || !context.mounted) return;
                    await runCommand(
                      context,
                      () => commands.setDeadline(task.id, picked.date),
                    );
                  },
            child: deadline == null
                ? Text(
                    l10n.noDeadline,
                    style: TextStyle(color: palette.textSecondary),
                  )
                : Builder(
                    builder: (context) {
                      final label = deadlineLabel(context, deadline, today);
                      return Text(
                        label.text,
                        style: TextStyle(color: label.color),
                      );
                    },
                  ),
          ),
          PriorityField(task: task, enabled: !readOnly),
          TaskField(
            label: l10n.fieldLabels,
            onTap: readOnly ? null : () => editLabels(context, ref, task),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final id in task.labelIds)
                  if (ws.taskLabel(task, id) case final label?)
                    Text(
                      label.name,
                      style: TextStyle(color: projectColor(label.color)),
                    ),
                Icon(Icons.add, size: 16, color: palette.textSecondary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
