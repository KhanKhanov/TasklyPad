import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/data_providers.dart';
import '../../../domain/models.dart';
import '../../../l10n/app_localizations.dart';
import '../../common/ui/ui_kit.dart';
import '../logic/due_dates.dart';
import '../state/today.dart';
import 'scheduler_layout.dart';
import 'task_actions.dart';
import 'task_edits.dart';
import 'task_panel.dart';
import 'task_row_menu_entries.dart';

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
///
/// Срок, приоритет и «Метки» меню не закрывают: их окна открываются поверх
/// него, и после выбора можно сразу поменять ещё что-то; меню закрывают `Esc`,
/// щелчок вне его, «Редактировать», «Перенести в…», «Дублировать» и
/// «Удалить» (решение 2А «M4.10a» plans/m4, уточнение пользователя 12.11.2026:
/// после переноса задача уходит в другой проект, после дубликата рядом
/// появляется копия — открытое меню показывало бы их неверно). Действия выполняются из пунктов
/// меню, а не из строки: строка могла уйти из списка, пока меню открыто.
/// Меню показывает задачу такой, какая она сейчас, и закрывается, если её
/// удалили.
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
  final id = task.id;
  // Строка, откуда открыли меню: её список даёт панели соседей для `J`/`K`.
  final rowContext = context;
  await showMenu<void>(
    context: context,
    position: RelativeRect.fromRect(anchor, Offset.zero & overlay.size),
    constraints: const BoxConstraints(minWidth: 264, maxWidth: 320),
    items: [
      TaskMenuEntry(
        id: id,
        text: l10n.actionEdit,
        icon: Icons.edit_outlined,
        act: (context, ref, task) {
          final root = Navigator.of(context, rootNavigator: true).context;
          closeTaskMenu(context);
          // Строка ушла из списка, пока меню было открыто, — панель без
          // соседей.
          return showTaskDialog(
            rowContext.mounted ? rowContext : root,
            task.id,
          );
        },
      ),
      const PopupMenuDivider(),
      TaskMenuIcons(
        id: id,
        title: l10n.fieldDue,
        icons: (task) => [
          for (final (quick, icon, label) in quickDueOptions(l10n))
            (icon, label, null, false, _quickDue(quick)),
          (Icons.block, l10n.noDue, null, false, removeDue),
          (Icons.more_horiz, l10n.pickDate, null, false, editDue),
        ],
      ),
      TaskMenuIcons(
        id: id,
        title: l10n.fieldPriority,
        icons: (task) => [
          for (var p = 1; p <= 4; p++)
            (
              Icons.flag,
              l10n.priorityN(p),
              p,
              task.priority == p,
              _priority(p),
            ),
        ],
      ),
      const PopupMenuDivider(),
      TaskMenuEntry(
        id: id,
        text: l10n.actionMoveTo,
        icon: Icons.drive_file_move_outline,
        act: _afterClose(moveTaskWith),
      ),
      TaskMenuEntry(
        id: id,
        text: l10n.fieldLabels,
        icon: Icons.label_outline,
        act: editLabels,
      ),
      TaskMenuEntry(
        id: id,
        text: l10n.actionDuplicate,
        icon: Icons.copy_outlined,
        act: _afterClose(
          (context, container, task) => runCommand(
            context,
            () => container.read(taskCommandsProvider).duplicate(task.id),
          ),
        ),
      ),
      const PopupMenuDivider(),
      TaskMenuEntry(
        id: id,
        text: l10n.actionDelete,
        icon: Icons.delete_outline,
        // Подтверждение — поверх меню; после него меню закрывается в любом
        // случае (удалённая задача закрывает его и сама).
        act: (context, ref, task) async {
          await deleteTask(context, ref, task);
          if (context.mounted) closeTaskMenu(context);
        },
      ),
    ],
  );
}

/// Быстрый срок — как быстрый вариант планировщика: время, пояс и правило
/// остаются, у повторяющейся задачи переносится только вхождение.
TaskMenuAct _quickDue(QuickDue quick) => (context, ref, task) {
  final day = isoDate(quickDueDate(quick, ref.read(todayProvider)));
  return runWithUndo(
    context,
    AppLocalizations.of(context).dueChanged,
    () => ref
        .read(taskCommandsProvider)
        .setDue(task.id, dueOnDate(task.due, day)),
  );
};

/// Приоритет — как клавиши `1–4`: без тоста.
TaskMenuAct _priority(int p) =>
    (context, ref, task) => runCommand(
      context,
      () => ref.read(taskCommandsProvider).setPriority(task.id, p),
    );

/// Действие после закрытия меню: окна и тост — от корневого навигатора, а
/// данные — через контейнер провайдеров, потому что пункт меню закрывается
/// вместе с ним.
TaskMenuAct _afterClose(
  Future<void> Function(
    BuildContext context,
    ProviderContainer container,
    Task task,
  )
  action,
) => (context, ref, task) {
  final root = Navigator.of(context, rootNavigator: true).context;
  final container = ProviderScope.containerOf(context, listen: false);
  closeTaskMenu(context);
  return action(root, container, task);
};
