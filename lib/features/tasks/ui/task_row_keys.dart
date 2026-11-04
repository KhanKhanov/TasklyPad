import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/data_providers.dart';
import '../../../domain/models.dart';
import '../../common/ui/ui_kit.dart';
import '../state/selection.dart';
import 'task_actions.dart';
import 'task_edits.dart';

/// Клавиши строки задачи в фокусе, которые меняют задачу или выделение (help
/// «Use keyboard shortcuts», docs/TODOIST_PARITY.md §10): `e`, `1–4`, `t`,
/// `Shift+T`, `l`, `v`, `y`, `.`, `x`, `Shift+Delete`, `Ctrl+]` / `Ctrl+[`
/// (при [hierarchy]). Строка проверяет до вызова, что задачу можно менять.
/// `Shift+Delete` при выделении — не задача в фокусе, а выделенные: клавишу
/// забирает оболочка (`SelectionKeys`).
/// Выделены задачи, видимые в виде: `Shift+Delete` относится к ним.
bool _hasLiveSelection(WidgetRef ref) {
  final ws = ref.read(workspaceProvider).value;
  return ws != null && ref.read(taskSelectionProvider).live(ws).isNotEmpty;
}

KeyEventResult taskRowEditKey({
  required BuildContext context,
  required WidgetRef ref,
  required Task task,
  required LogicalKeyboardKey key,
  required bool hierarchy,
  required VoidCallback complete,
  required VoidCallback openMenu,
  required VoidCallback toggleSelected,
}) {
  final keys = HardwareKeyboard.instance;
  final commands = ref.read(taskCommandsProvider);
  void run(Future<void> Function() action) =>
      runCommand(context, () async => action());
  if (keys.isControlPressed) {
    if (!hierarchy) return KeyEventResult.ignored;
    switch (key) {
      case LogicalKeyboardKey.bracketRight:
        run(() => commands.indent(task.id));
      case LogicalKeyboardKey.bracketLeft:
        run(() => commands.outdent(task.id));
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }
  if (keys.isShiftPressed) {
    switch (key) {
      case LogicalKeyboardKey.delete when !_hasLiveSelection(ref):
        deleteTask(context, ref, task);
      case LogicalKeyboardKey.keyT:
        removeDue(context, ref, task);
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }
  switch (key) {
    case LogicalKeyboardKey.keyE:
      complete();
    case LogicalKeyboardKey.digit1 ||
        LogicalKeyboardKey.digit2 ||
        LogicalKeyboardKey.digit3 ||
        LogicalKeyboardKey.digit4:
      final p = int.parse(key.keyLabel);
      run(() => commands.setPriority(task.id, p));
    case LogicalKeyboardKey.keyT:
      editDue(context, ref, task);
    case LogicalKeyboardKey.keyL:
      editLabels(context, ref, task);
    case LogicalKeyboardKey.keyV:
      moveTaskTo(context, ref, task);
    case LogicalKeyboardKey.keyY:
      editPriority(context, ref, task);
    case LogicalKeyboardKey.period:
      openMenu();
    case LogicalKeyboardKey.keyX:
      toggleSelected();
    default:
      return KeyEventResult.ignored;
  }
  return KeyEventResult.handled;
}
