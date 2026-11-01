import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_palette.dart';
import '../../../domain/workspace.dart';
import '../../../l10n/app_localizations.dart';
import '../../common/ui/ui_kit.dart';
import '../../tasks/state/today.dart';
import '../../tasks/ui/due_ui.dart';
import '../../tasks/ui/scheduler_dialog.dart';
import '../../tasks/ui/task_pickers.dart';
import '../state/quick_add_controller.dart';

/// Чипы окна быстрого добавления: срок, приоритет, метки, дедлайн. Чип
/// показывает действующее значение — распознанное в тексте или выбранное;
/// выбор чипом убирает распознанный участок (решение 4А «Ход M3.6»).
class QuickAddChips extends ConsumerWidget {
  const QuickAddChips({super.key, required this.controller, required this.ws});

  final QuickAddController controller;
  final Workspace ws;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final today = ref.watch(todayProvider);
    final d = controller.draft;
    final due = d?.due;
    final dueText = due == null
        ? null
        : dueLabel(context, due.date, due.time, today);
    final deadline = d?.deadline;
    final labelNames = [
      for (final id in d?.labelIds ?? const <String>{})
        if (ws.label(id) case final label?) label.name,
      ...?d?.newLabels,
    ];
    final priority = d?.priority ?? 4;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _Chip(
          icon: due?.isRecurring ?? false ? Icons.repeat : Icons.event_outlined,
          text: dueText?.text ?? l10n.fieldDue,
          color: dueText?.color,
          onTap: () async {
            final picked = await pickDue(context, ref, due);
            if (picked != null) controller.pickDue(picked.due);
          },
        ),
        PopupMenuButton<int>(
          tooltip: l10n.fieldPriority,
          onSelected: controller.pickPriority,
          itemBuilder: (context) => [
            for (var p = 1; p <= 4; p++)
              PopupMenuItem(
                value: p,
                child: Row(
                  children: [
                    Icon(Icons.flag, size: 16, color: palette.priority[p - 1]),
                    const SizedBox(width: 8),
                    Text(l10n.priorityN(p)),
                  ],
                ),
              ),
          ],
          child: _Chip(
            icon: priority == 4 ? Icons.outlined_flag : Icons.flag,
            iconColor: priority == 4 ? null : palette.priority[priority - 1],
            text: priority == 4 ? l10n.fieldPriority : l10n.priorityN(priority),
          ),
        ),
        _Chip(
          icon: Icons.sell_outlined,
          text: labelNames.isEmpty ? l10n.fieldLabels : labelNames.join(', '),
          onTap: () async {
            final picked = await pickLabels(context, ws, [...?d?.labelIds]);
            if (picked != null) controller.pickLabels(picked);
          },
        ),
        _Chip(
          icon: Icons.outlined_flag,
          text: deadline == null
              ? l10n.fieldDeadline
              : dueLabel(context, deadline, null, today).text,
          onTap: () async {
            final picked = await pickDeadline(context, ref, deadline);
            if (picked != null) controller.pickDeadline(picked.date);
          },
        ),
      ],
    );
  }
}

/// Кнопка проекта в нижней строке окна: «Входящие», проект или раздел, куда
/// попадёт задача; новый проект из «Создать …» — его именем.
class QuickAddProjectButton extends StatelessWidget {
  const QuickAddProjectButton({
    super.key,
    required this.controller,
    required this.ws,
  });

  final QuickAddController controller;
  final Workspace ws;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final d = controller.draft;
    final project = d?.projectId == null ? null : ws.project(d!.projectId!);
    final section = d?.sectionId == null ? null : ws.section(d!.sectionId!);
    final name = project == null
        ? d?.newProject ?? l10n.inbox
        : projectTitle(l10n, project);
    return TextButton.icon(
      onPressed: () async {
        final place = await pickPlace(context, ws);
        if (place != null) {
          controller.pickPlace(place.projectId, place.sectionId);
        }
      },
      icon: project == null || project.isInbox
          ? const Icon(Icons.inbox_outlined, size: 18)
          : ProjectHash(color: project.color, size: 15),
      label: Text(
        section == null ? name : '$name / ${section.name}',
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.text,
    this.color,
    this.iconColor,
    this.onTap,
  });

  final IconData icon;
  final String text;
  final Color? color;
  final Color? iconColor;

  /// `null` — нажатие ловит обёртка (меню приоритета).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(color: palette.outline),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: iconColor ?? color ?? palette.textSecondary,
          ),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color ?? palette.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: content,
    );
  }
}
