import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/data_providers.dart';
import '../../../app/theme/app_palette.dart';
import '../../../domain/models.dart';
import '../../../domain/tree.dart';
import '../../../domain/workspace.dart';
import '../../../l10n/app_localizations.dart';
import '../../tasks/ui/scheduler_dialog.dart';
import '../../tasks/ui/task_actions.dart';
import '../../tasks/ui/task_row.dart';

/// Блок «Просрочено» в «Сегодня» и «Предстоящем»: заголовок, справа
/// «Перенести», задачи плоским списком с проектом. Порядок — умный без
/// ручного порядка дня (help «Default sorting order»: «Overdue tasks can't be
/// manually sorted»).
class OverdueBlock extends StatelessWidget {
  const OverdueBlock({super.key, required this.tasks, required this.ws});

  final List<Task> tasks;
  final Workspace ws;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: palette.divider)),
          ),
          height: 40,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  AppLocalizations.of(context).groupOverdue,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              RescheduleButton(ids: [for (final t in tasks) t.id]),
            ],
          ),
        ),
        for (final task in tasks)
          TaskRow(
            key: ValueKey('overdue/${task.id}'),
            item: TreeItem(task, 0, 0),
            ws: ws,
            collapsible: false,
            showProject: true,
            hierarchy: false,
          ),
      ],
    );
  }
}

/// «Перенести» (решение 10 плана M4): планировщик, затем все просроченные
/// [ids] — на выбранную дату одним действием с тостом «Отменить».
class RescheduleButton extends ConsumerWidget {
  const RescheduleButton({super.key, required this.ids});

  final List<String> ids;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return TextButton(
      style: TextButton.styleFrom(
        foregroundColor: AppPalette.of(context).accent,
      ),
      onPressed: ids.isEmpty
          ? null
          : () async {
              final picked = await pickDue(context, ref, null, dateOnly: true);
              if (picked == null || !context.mounted) return;
              await runWithUndo(
                context,
                l10n.dueChanged,
                () => ref
                    .read(taskCommandsProvider)
                    .rescheduleOverdue(ids, picked.due?.date),
              );
            },
      child: Text(l10n.reschedule),
    );
  }
}
