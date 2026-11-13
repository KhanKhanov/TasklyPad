import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/data_providers.dart';
import '../../../app/theme/app_palette.dart';
import '../../../domain/models.dart';
import '../../../l10n/app_localizations.dart';
import '../../common/ui/ui_kit.dart';
import '../../../domain/rules.dart';
import 'scheduler_dialog.dart';
import 'task_actions.dart';
import 'task_pickers.dart';

// Правки задачи с выбором значения — общие для полей панели и клавиш строки
// (`t`, `Shift+T`, `v`, `l`, `y`; help «Use keyboard shortcuts»).

/// Срок: выбрать в планировщике; смена и «Отложить» — с тостом «Отменить».
/// Длительность из окна «Время» пишется отдельно, без тоста, как из поля
/// панели; срок без изменений после этого окна не пишется.
Future<void> editDue(
  BuildContext context,
  WidgetRef ref,
  Task task, {
  ScaffoldMessengerState? messenger,
}) async {
  final picked = await pickDue(
    context,
    ref,
    task.due,
    canPostpone: !task.isCompleted,
    duration: task.duration,
    withDuration: true,
  );
  if (picked == null || !context.mounted) return;
  final commands = ref.read(taskCommandsProvider);
  if (picked.duration case (:final value)) {
    // В минутах: `1 day` из Todoist окно вернёт как 1440 минут.
    final before = task.duration;
    final same = value == null || before == null
        ? value == before
        : durationInMinutes(value) == durationInMinutes(before);
    if (!same) {
      await runCommand(
        context,
        () => commands.setDuration(task.id, value),
        messenger: messenger,
      );
      if (!context.mounted) return;
    }
    if (picked.due == task.due) return;
  }
  await runWithUndo(
    context,
    AppLocalizations.of(context).dueChanged,
    () => picked.postpone
        ? commands.postpone(task.id)
        : commands.setDue(task.id, picked.due),
    messenger: messenger,
  );
}

/// `Shift+T`: убрать срок — с тостом «Отменить».
Future<void> removeDue(
  BuildContext context,
  WidgetRef ref,
  Task task, {
  ScaffoldMessengerState? messenger,
}) async {
  if (task.due == null) return;
  await runWithUndo(
    context,
    AppLocalizations.of(context).dueChanged,
    () => ref.read(taskCommandsProvider).setDue(task.id, null),
    messenger: messenger,
  );
}

/// Перенести в проект или раздел — с тостом «Отменить».
Future<void> moveTaskTo(BuildContext context, WidgetRef ref, Task task) =>
    moveTaskWith(
      context,
      ProviderScope.containerOf(context, listen: false),
      task,
    );

/// [moveTaskTo] с контейнером провайдеров: для вызова после закрытия меню,
/// когда `ref` пункта меню уже не живёт.
Future<void> moveTaskWith(
  BuildContext context,
  ProviderContainer container,
  Task task, {
  ScaffoldMessengerState? messenger,
}) async {
  final ws = container.read(workspaceProvider).value;
  if (ws == null) return;
  final target = await pickPlace(context, ws);
  if (target == null || !context.mounted) return;
  await runWithUndo(
    context,
    AppLocalizations.of(context).taskMoved,
    () => container
        .read(taskCommandsProvider)
        .move(
          task.id,
          projectId: target.projectId,
          sectionId: target.sectionId,
        ),
    messenger: messenger,
  );
}

/// Метки: отметить или создать новую.
Future<void> editLabels(
  BuildContext context,
  WidgetRef ref,
  Task task, {
  ScaffoldMessengerState? messenger,
}) async {
  final ws = ref.read(workspaceProvider).value;
  if (ws == null) return;
  final picked = await pickLabels(context, ws, task.labelIds);
  if (picked == null || !context.mounted) return;
  await runCommand(
    context,
    () => ref.read(taskCommandsProvider).setLabels(task.id, picked),
    messenger: messenger,
  );
}

/// `y`: выбрать приоритет.
Future<void> editPriority(
  BuildContext context,
  WidgetRef ref,
  Task task,
) async {
  final p = await pickPriority(context);
  if (p == null || !context.mounted) return;
  await runCommand(
    context,
    () => ref.read(taskCommandsProvider).setPriority(task.id, p),
  );
}

/// Окно выбора приоритета: 1 (P1) … 4; `null` — закрыли.
Future<int?> pickPriority(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  final palette = AppPalette.of(context);
  return showDialog<int>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(l10n.fieldPriority),
      children: [
        for (var p = 1; p <= 4; p++)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, p),
            child: Row(
              children: [
                Icon(Icons.flag, size: 16, color: palette.priority[p - 1]),
                const SizedBox(width: 8),
                Text(l10n.priorityN(p)),
              ],
            ),
          ),
      ],
    ),
  );
}
