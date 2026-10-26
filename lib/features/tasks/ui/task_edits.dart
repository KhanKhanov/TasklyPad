import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/data_providers.dart';
import '../../../app/theme/app_palette.dart';
import '../../../domain/models.dart';
import '../../../l10n/app_localizations.dart';
import '../../common/ui/ui_kit.dart';
import 'due_ui.dart';
import 'task_actions.dart';
import 'task_pickers.dart';

// Правки задачи с выбором значения — общие для полей панели и клавиш строки
// (`t`, `Shift+T`, `v`, `l`, `y`; help «Use keyboard shortcuts»).

/// Срок: выбрать; смена — с тостом «Отменить».
Future<void> editDue(BuildContext context, WidgetRef ref, Task task) async {
  final picked = await pickDue(context, ref, task.due);
  if (picked == null || !context.mounted) return;
  await runWithUndo(
    context,
    AppLocalizations.of(context).dueChanged,
    () => ref.read(taskCommandsProvider).setDue(task.id, picked.due),
  );
}

/// `Shift+T`: убрать срок — с тостом «Отменить».
Future<void> removeDue(BuildContext context, WidgetRef ref, Task task) async {
  if (task.due == null) return;
  await runWithUndo(
    context,
    AppLocalizations.of(context).dueChanged,
    () => ref.read(taskCommandsProvider).setDue(task.id, null),
  );
}

/// Перенести в проект или раздел — с тостом «Отменить».
Future<void> moveTaskTo(BuildContext context, WidgetRef ref, Task task) async {
  final ws = ref.read(workspaceProvider).value;
  if (ws == null) return;
  final target = await pickPlace(context, ws);
  if (target == null || !context.mounted) return;
  await runWithUndo(
    context,
    AppLocalizations.of(context).taskMoved,
    () => ref
        .read(taskCommandsProvider)
        .move(
          task.id,
          projectId: target.projectId,
          sectionId: target.sectionId,
        ),
  );
}

/// Метки: отметить или создать новую.
Future<void> editLabels(BuildContext context, WidgetRef ref, Task task) async {
  final ws = ref.read(workspaceProvider).value;
  if (ws == null) return;
  final picked = await pickLabels(context, ws, task.labelIds);
  if (picked == null || !context.mounted) return;
  await runCommand(
    context,
    () => ref.read(taskCommandsProvider).setLabels(task.id, picked),
  );
}

/// `y`: выбрать приоритет.
Future<void> editPriority(
  BuildContext context,
  WidgetRef ref,
  Task task,
) async {
  final l10n = AppLocalizations.of(context);
  final palette = AppPalette.of(context);
  final p = await showDialog<int>(
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
  if (p == null || !context.mounted) return;
  await runCommand(
    context,
    () => ref.read(taskCommandsProvider).setPriority(task.id, p),
  );
}
