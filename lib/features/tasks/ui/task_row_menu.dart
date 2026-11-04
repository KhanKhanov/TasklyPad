import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/data_providers.dart';
import '../../../app/theme/app_palette.dart';
import '../../../domain/models.dart';
import '../../../l10n/app_localizations.dart';
import '../../common/ui/ui_kit.dart';
import '../logic/due_dates.dart';
import '../state/today.dart';
import 'scheduler_layout.dart';
import 'task_actions.dart';
import 'task_edits.dart';
import 'task_panel.dart';

/// Кнопка «⋯» строки задачи: меню задачи (help «Set a priority»: «Click the
/// three dots icon next to the task name. This opens the task menu»).
class TaskRowMenuButton extends ConsumerWidget {
  const TaskRowMenuButton({super.key, required this.task});

  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) => IconButton(
    tooltip: AppLocalizations.of(context).moreActions,
    iconSize: 20,
    icon: const Icon(Icons.more_horiz),
    onPressed: () => showTaskRowMenu(context, ref, task),
  );
}

/// Меню строки задачи — «⋯», клавиша `.` и правый клик (решение 12А плана M4,
/// решения 1А и 2А «Ход M4.7»): «Редактировать», срок, приоритет,
/// «Перенести в…», «Метки», «Дублировать», «Удалить». Меню встаёт под
/// [context] (кнопкой «⋯») или у точки [at] (правый клик).
Future<void> showTaskRowMenu(
  BuildContext context,
  WidgetRef ref,
  Task task, {
  Offset? at,
}) async {
  final l10n = AppLocalizations.of(context);
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  final Rect anchor;
  if (at != null) {
    // Точка клика — в координатах окна, а меню встаёт в слое экрана справа
    // от сайдбара и под верхней строкой.
    anchor = overlay.globalToLocal(at) & Size.zero;
  } else {
    final box = context.findRenderObject()! as RenderBox;
    anchor = box.localToGlobal(Offset.zero, ancestor: overlay) & box.size;
  }
  final picked = await showMenu<_Pick>(
    context: context,
    position: RelativeRect.fromRect(anchor, Offset.zero & overlay.size),
    constraints: const BoxConstraints(minWidth: 264, maxWidth: 320),
    items: [
      _item(const _Do(_Action.edit), l10n.actionEdit, Icons.edit_outlined),
      const PopupMenuDivider(),
      _IconsEntry(
        title: l10n.fieldDue,
        icons: [
          for (final (quick, icon, label) in quickDueOptions(l10n))
            (_Date(quick), icon, label, null),
          (const _Date(null), Icons.block, l10n.noDue, null),
          (const _Do(_Action.scheduler), Icons.more_horiz, l10n.pickDate, null),
        ],
      ),
      _IconsEntry(
        title: l10n.fieldPriority,
        icons: [
          for (var p = 1; p <= 4; p++)
            (_Priority(p), Icons.flag, l10n.priorityN(p), p),
        ],
        selected: _Priority(task.priority),
      ),
      const PopupMenuDivider(),
      _item(
        const _Do(_Action.moveTo),
        l10n.actionMoveTo,
        Icons.drive_file_move_outline,
      ),
      _item(const _Do(_Action.labels), l10n.fieldLabels, Icons.label_outline),
      _item(
        const _Do(_Action.duplicate),
        l10n.actionDuplicate,
        Icons.copy_outlined,
      ),
      const PopupMenuDivider(),
      _item(const _Do(_Action.delete), l10n.actionDelete, Icons.delete_outline),
    ],
  );
  if (picked == null || !context.mounted) return;
  final commands = ref.read(taskCommandsProvider);
  switch (picked) {
    case _Do(action: _Action.edit):
      await showTaskDialog(context, task.id);
    case _Do(action: _Action.scheduler):
      await editDue(context, ref, task);
    case _Do(action: _Action.moveTo):
      await moveTaskTo(context, ref, task);
    case _Do(action: _Action.labels):
      await editLabels(context, ref, task);
    case _Do(action: _Action.duplicate):
      await runCommand(context, () => commands.duplicate(task.id));
    case _Do(action: _Action.delete):
      await deleteTask(context, ref, task);
    case _Date(quick: null):
      await removeDue(context, ref, task);
    case _Date(quick: final quick?):
      // Как быстрый вариант планировщика: время, пояс и правило остаются,
      // у повторяющейся задачи переносится только вхождение.
      final day = isoDate(quickDueDate(quick, ref.read(todayProvider)));
      await runWithUndo(
        context,
        l10n.dueChanged,
        () => commands.setDue(task.id, dueOnDate(task.due, day)),
      );
    case _Priority(:final priority):
      // Как клавиши `1–4`: без тоста.
      await runCommand(context, () => commands.setPriority(task.id, priority));
  }
}

PopupMenuItem<_Pick> _item(_Pick value, String text, IconData icon) =>
    PopupMenuItem(
      value: value,
      child: Row(
        children: [Icon(icon, size: 18), const SizedBox(width: 12), Text(text)],
      ),
    );

enum _Action { edit, scheduler, moveTo, labels, duplicate, delete }

/// Выбор в меню: действие, срок или приоритет.
sealed class _Pick {
  const _Pick();
}

final class _Do extends _Pick {
  const _Do(this.action);
  final _Action action;
}

/// Быстрый срок; `null` — «Без срока».
final class _Date extends _Pick {
  const _Date(this.quick);
  final QuickDue? quick;
}

final class _Priority extends _Pick {
  const _Priority(this.priority);
  final int priority;

  @override
  bool operator ==(Object other) =>
      other is _Priority && other.priority == priority;

  @override
  int get hashCode => priority.hashCode;
}

/// Раздел меню с подписью и рядом значков, как «Срок» и «Приоритет» в меню
/// задачи Todoist. Четвёртое поле значка — приоритет его цвета.
class _IconsEntry extends PopupMenuEntry<_Pick> {
  const _IconsEntry({required this.title, required this.icons, this.selected});

  final String title;
  final List<(_Pick, IconData, String, int?)> icons;

  /// Текущее значение — значок отмечен фоном.
  final _Pick? selected;

  @override
  double get height => 76;

  @override
  bool represents(_Pick? value) => false;

  @override
  State<_IconsEntry> createState() => _IconsEntryState();
}

class _IconsEntryState extends State<_IconsEntry> {
  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 2),
            child: Text(
              widget.title,
              style: TextStyle(color: palette.textSecondary, fontSize: 12),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (value, icon, label, priority) in widget.icons)
                IconButton(
                  tooltip: label,
                  iconSize: 20,
                  // Шесть значков срока — в ширину меню.
                  visualDensity: VisualDensity.compact,
                  isSelected: value == widget.selected,
                  style: IconButton.styleFrom(
                    backgroundColor: value == widget.selected
                        ? palette.selected
                        : null,
                  ),
                  color: priority == null
                      ? palette.textSecondary
                      : palette.priority[priority - 1],
                  icon: Icon(icon),
                  onPressed: () => Navigator.pop(context, value),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
