import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/data_providers.dart';
import '../../../app/theme/app_palette.dart';
import '../../../domain/models.dart';
import '../../../domain/workspace.dart';
import '../../../l10n/app_localizations.dart';
import '../../common/ui/ui_kit.dart';
import '../state/today.dart';
import 'due_ui.dart';
import 'task_edits.dart';

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
    final deadline = task.deadline;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Field(
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
          _Field(
            label: l10n.fieldDue,
            onTap: readOnly ? null : () => editDue(context, ref, task),
            child: due == null
                ? Text(
                    l10n.noDue,
                    style: TextStyle(color: palette.textSecondary),
                  )
                : Builder(
                    builder: (context) {
                      final label = dueLabel(
                        context,
                        due.date,
                        due.time,
                        today,
                      );
                      return Text(
                        label.text,
                        style: TextStyle(color: label.color),
                      );
                    },
                  ),
          ),
          if (due?.time != null)
            _Field(
              label: l10n.fieldDuration,
              child: _DurationMenu(task: task, enabled: !readOnly),
            ),
          _Field(
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
                      final label = dueLabel(context, deadline, null, today);
                      return Text(
                        label.text,
                        style: TextStyle(color: label.color),
                      );
                    },
                  ),
          ),
          _Field(
            label: l10n.fieldPriority,
            child: _PriorityMenu(task: task, enabled: !readOnly),
          ),
          _Field(
            label: l10n.fieldLabels,
            onTap: readOnly ? null : () => editLabels(context, ref, task),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final id in task.labelIds)
                  if (ws.taskLabel(id) case final label?)
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

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child, this.onTap});

  final String label;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    // Нажимается всё поле — и подпись, и значение, как в Todoist.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                DefaultTextStyle.merge(
                  style: TextStyle(color: palette.textPrimary, fontSize: 14),
                  child: child,
                ),
              ],
            ),
          ),
        ),
        Divider(color: palette.divider),
      ],
    );
  }
}

class _PriorityMenu extends ConsumerWidget {
  const _PriorityMenu({required this.task, required this.enabled});

  final Task task;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    Widget item(int p) => Row(
      children: [
        Icon(Icons.flag, size: 16, color: palette.priority[p - 1]),
        const SizedBox(width: 8),
        Text(l10n.priorityN(p)),
      ],
    );
    return PopupMenuButton<int>(
      tooltip: l10n.fieldPriority,
      enabled: enabled,
      onSelected: (p) => runCommand(
        context,
        () => ref.read(taskCommandsProvider).setPriority(task.id, p),
      ),
      itemBuilder: (context) => [
        for (var p = 1; p <= 4; p++) PopupMenuItem(value: p, child: item(p)),
      ],
      child: item(task.priority.clamp(1, 4)),
    );
  }
}

class _DurationMenu extends ConsumerWidget {
  const _DurationMenu({required this.task, required this.enabled});

  final Task task;
  final bool enabled;

  static const _minutes = [15, 30, 45, 60, 90, 120];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final current = task.duration;
    final text = current == null
        ? l10n.noDuration
        : l10n.durationMinutes(
            current.unit == 'day' ? current.amount * 1440 : current.amount,
          );
    return PopupMenuButton<int>(
      tooltip: l10n.fieldDuration,
      enabled: enabled,
      onSelected: (m) => runCommand(
        context,
        () => ref
            .read(taskCommandsProvider)
            .setDuration(
              task.id,
              m == 0 ? null : TaskDuration(amount: m, unit: 'minute'),
            ),
      ),
      itemBuilder: (context) => [
        PopupMenuItem(value: 0, child: Text(l10n.noDuration)),
        for (final m in _minutes)
          PopupMenuItem(value: m, child: Text(l10n.durationMinutes(m))),
      ],
      child: Text(text),
    );
  }
}
