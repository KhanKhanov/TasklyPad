import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/data_providers.dart';
import '../../../domain/undo.dart';
import '../../../domain/workspace.dart';
import '../../../l10n/app_localizations.dart';
import '../../common/ui/ui_kit.dart';
import '../state/selection.dart';
import 'deadline_dialog.dart';
import 'scheduler_dialog.dart';
import 'task_actions.dart';
import 'task_edits.dart';
import 'task_pickers.dart';

// Действия панели выделения (help «Add or manage multiple tasks», решение 9
// плана M4). Каждое берёт выделенные в порядке вида, пишет одной командой и
// снимает выделение; срок, перенос и выполнение — с тостом «Отменить», как
// одиночные.

/// Выделенные задачи, видимые в виде, в его порядке; снимок данных.
(List<String>, Workspace)? _selected(WidgetRef ref) {
  final ws = ref.read(workspaceProvider).value;
  if (ws == null) return null;
  final ids = ref.read(taskSelectionProvider).live(ws);
  return ids.isEmpty ? null : (ids, ws);
}

/// Действие без «Отменить»; выделение снимается, только если оно удалось.
Future<void> _apply(
  BuildContext context,
  WidgetRef ref,
  Future<void> Function() action,
) async {
  final ok = await runGuarded(
    ScaffoldMessenger.of(context),
    AppLocalizations.of(context),
    action,
  );
  if (ok) ref.read(taskSelectionProvider.notifier).clear();
}

/// Действие с тостом «Отменить» [message].
Future<void> _applyWithUndo(
  BuildContext context,
  WidgetRef ref,
  String message,
  Future<UndoAction> Function() action,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppLocalizations.of(context);
  UndoAction? undo;
  final ok = await runGuarded(messenger, l10n, () async {
    undo = await action();
  });
  if (!ok) return;
  ref.read(taskSelectionProvider.notifier).clear();
  if (undo case final done? when !done.isEmpty && messenger.mounted) {
    showUndoToast(messenger, l10n, message, done);
  }
}

/// «Срок»: решение 1А «Ход M4.8» — у [BulkTaskCommands.setDue].
Future<void> selectionDue(BuildContext context, WidgetRef ref) async {
  final (ids, _) = _selected(ref) ?? (null, null);
  if (ids == null) return;
  final picked = await pickDue(context, ref, null);
  if (picked == null || !context.mounted) return;
  await _applyWithUndo(
    context,
    ref,
    AppLocalizations.of(context).tasksDueChanged(ids.length),
    () => ref.read(bulkTaskCommandsProvider).setDue(ids, picked.due),
  );
}

/// «Перенести в…».
Future<void> selectionMove(BuildContext context, WidgetRef ref) async {
  final (ids, ws) = _selected(ref) ?? (null, null);
  if (ids == null || ws == null) return;
  final target = await pickPlace(context, ws);
  if (target == null || !context.mounted) return;
  await _applyWithUndo(
    context,
    ref,
    AppLocalizations.of(context).tasksMoved(ids.length),
    () => ref
        .read(bulkTaskCommandsProvider)
        .move(ids, target.projectId, target.sectionId),
  );
}

/// «Метки» — добавляют отмеченные (help: «Adds a label»).
Future<void> selectionLabels(BuildContext context, WidgetRef ref) async {
  final (ids, ws) = _selected(ref) ?? (null, null);
  if (ids == null || ws == null) return;
  final picked = await pickLabels(context, ws, const []);
  if (picked == null || picked.isEmpty || !context.mounted) return;
  await _apply(
    context,
    ref,
    () => ref.read(bulkTaskCommandsProvider).addLabels(ids, picked),
  );
}

/// «Удалить» — после подтверждения, без «Отменить» (`Shift+Delete` тоже).
Future<void> selectionDelete(BuildContext context, WidgetRef ref) async {
  final (ids, _) = _selected(ref) ?? (null, null);
  if (ids == null) return;
  final l10n = AppLocalizations.of(context);
  final ok = await confirmAction(
    context,
    title: l10n.deleteTasksTitle,
    body: l10n.deleteTasksBody(ids.length),
    action: l10n.actionDelete,
    danger: true,
  );
  if (!ok || !context.mounted) return;
  await _apply(
    context,
    ref,
    () => ref.read(bulkTaskCommandsProvider).delete(ids),
  );
}

/// «Приоритет» из «⋯».
Future<void> selectionPriority(BuildContext context, WidgetRef ref) async {
  final (ids, _) = _selected(ref) ?? (null, null);
  if (ids == null) return;
  final p = await pickPriority(context);
  if (p == null || !context.mounted) return;
  await _apply(
    context,
    ref,
    () => ref.read(bulkTaskCommandsProvider).setPriority(ids, p),
  );
}

/// «Дедлайн» из «⋯».
Future<void> selectionDeadline(BuildContext context, WidgetRef ref) async {
  final (ids, _) = _selected(ref) ?? (null, null);
  if (ids == null) return;
  final picked = await pickDeadline(context, ref, null);
  if (picked == null || !context.mounted) return;
  await _apply(
    context,
    ref,
    () => ref.read(bulkTaskCommandsProvider).setDeadline(ids, picked.date),
  );
}

/// «Выполнить» или «Вернуть» (у одних выполненных) из «⋯».
Future<void> selectionComplete(
  BuildContext context,
  WidgetRef ref, {
  required bool uncomplete,
}) async {
  final (ids, _) = _selected(ref) ?? (null, null);
  if (ids == null) return;
  final commands = ref.read(bulkTaskCommandsProvider);
  if (uncomplete) {
    await _apply(context, ref, () => commands.uncomplete(ids));
  } else {
    await _applyWithUndo(
      context,
      ref,
      AppLocalizations.of(context).tasksCompleted(ids.length),
      () => commands.complete(ids),
    );
  }
}

/// «Дублировать» из «⋯».
Future<void> selectionDuplicate(BuildContext context, WidgetRef ref) async {
  final (ids, _) = _selected(ref) ?? (null, null);
  if (ids == null) return;
  await _apply(
    context,
    ref,
    () => ref.read(bulkTaskCommandsProvider).duplicate(ids),
  );
}
