import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/data_providers.dart';
import '../../../app/theme/app_palette.dart';
import '../../../domain/models.dart';
import '../../../domain/tree.dart';
import '../../../domain/workspace.dart';
import '../../../l10n/app_localizations.dart';
import '../../common/ui/drag_rows.dart';
import '../../tasks/ui/scheduler_dialog.dart';
import '../../tasks/ui/task_actions.dart';
import '../../tasks/ui/task_drag.dart';
import '../../tasks/ui/task_row.dart';

/// Блок «Просрочено» в «Сегодня» и «Предстоящем»: заголовок, справа
/// «Перенести», задачи плоским списком с проектом. Порядок — умный без
/// ручного порядка дня (help «Default sorting order»: «Overdue tasks can't be
/// manually sorted»). Задачи блока можно только брать — на день, в зону «на
/// завтра» и на проект в сайдбаре (решение 3А «Ход M4.9»); перестановки нет.
class OverdueBlock extends StatelessWidget {
  const OverdueBlock({
    super.key,
    required this.tasks,
    required this.ws,
    this.draggable = true,
  });

  final List<Task> tasks;
  final Workspace ws;

  /// `false` — перетаскивание вида выключено (сортировка с направлением).
  final bool draggable;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final items = [for (final t in tasks) TreeItem(t, 0, 0)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DragGutter(
          child: Container(
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
        ),
        for (final item in items)
          TaskDragRow(
            key: ValueKey('overdue/${item.value.id}'),
            item: item,
            items: items,
            drop: draggable ? const OverdueDrop() : null,
            child: TaskRow(
              item: item,
              ws: ws,
              collapsible: false,
              showProject: true,
              hierarchy: false,
            ),
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
