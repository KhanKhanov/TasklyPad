import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_palette.dart';
import '../../../domain/models.dart';
import '../../../domain/workspace.dart';
import '../../../l10n/app_localizations.dart';
import '../state/today.dart';
import 'due_ui.dart';
import 'task_actions.dart';

/// Кружок задачи: обводка цвета приоритета; у выполненной — заливка с
/// галочкой. Нажатие — выполнить (с «Отменить») или вернуть в работу;
/// повторное нажатие, пока первое пишется, не действует. [enabled] `false` —
/// проект в архиве.
class TaskCheckCircle extends ConsumerStatefulWidget {
  const TaskCheckCircle({super.key, required this.task, this.enabled = true});

  final Task task;
  final bool enabled;

  @override
  ConsumerState<TaskCheckCircle> createState() => _TaskCheckCircleState();
}

class _TaskCheckCircleState extends ConsumerState<TaskCheckCircle> {
  bool _busy = false;

  Future<void> _toggle() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await toggleComplete(context, ref, widget.task);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final color = palette.priority[(task.priority.clamp(1, 4)) - 1];
    return Tooltip(
      message: task.isCompleted ? l10n.reopenTask : l10n.completeTask,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: widget.enabled ? _toggle : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 4),
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: task.isCompleted ? palette.textSecondary : null,
              border: Border.all(
                color: task.isCompleted ? palette.textSecondary : color,
                width: 1.5,
              ),
            ),
            child: task.isCompleted
                ? Icon(Icons.check, size: 12, color: palette.background)
                : null,
          ),
        ),
      ),
    );
  }
}

/// Текст строки задачи: название, первая строка описания и чипы — счётчик
/// подзадач, срок, дедлайн, метки.
class TaskText extends ConsumerWidget {
  const TaskText({
    super.key,
    required this.task,
    required this.ws,
    this.onToggleCollapse,
  });

  final Task task;
  final Workspace ws;

  /// Клик по счётчику подзадач; `null` — счётчик не нажимается.
  final VoidCallback? onToggleCollapse;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final today = ref.watch(todayProvider);
    final progress = ws.subtaskProgress(task.id);
    final due = task.due;
    final deadline = task.deadline;
    final small = TextStyle(fontSize: 12, color: palette.textSecondary);
    final chips = <Widget>[
      if (progress.total > 0)
        _Chip(
          icon: Icons.account_tree_outlined,
          text: '${progress.done}/${progress.total}',
          color: palette.textSecondary,
          // Как в Todoist: клик по счётчику раскрывает и сворачивает подзадачи.
          onTap: onToggleCollapse,
        ),
      if (due != null) ...[
        for (final label in [dueLabel(context, due.date, due.time, today)])
          _Chip(
            icon: Icons.calendar_today_outlined,
            text: label.text,
            color: label.color,
          ),
      ],
      if (deadline != null) ...[
        for (final label in [dueLabel(context, deadline, null, today)])
          _Chip(
            icon: Icons.outlined_flag,
            text: label.text,
            color: label.color,
          ),
      ],
      for (final id in task.labelIds)
        if (ws.label(id) case final label?)
          _Chip(
            icon: Icons.sell_outlined,
            text: label.name,
            color: projectColor(label.color),
          ),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            task.content,
            style: TextStyle(
              fontSize: 14,
              color: task.isCompleted
                  ? palette.textSecondary
                  : palette.textPrimary,
              decoration: task.isCompleted ? TextDecoration.lineThrough : null,
            ),
          ),
          if (task.description.isNotEmpty)
            Text(
              task.description.split('\n').first,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: small,
            ),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(spacing: 12, runSpacing: 4, children: chips),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.text,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String text;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final chip = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 3),
        Text(text, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
    if (onTap == null) return chip;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: chip,
    );
  }
}
