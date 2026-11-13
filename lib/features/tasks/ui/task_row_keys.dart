import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/data_providers.dart';
import '../../../domain/models.dart';
import '../../../domain/workspace.dart';
import '../../common/ui/ui_kit.dart';
import '../state/selection.dart';
import 'task_actions.dart';
import 'task_edits.dart';

/// Выделены задачи, видимые в виде: `Shift+Delete` относится к ним.
bool _hasLiveSelection(WidgetRef ref) {
  final ws = ref.read(workspaceProvider).value;
  return ws != null && ref.read(taskSelectionProvider).live(ws).isNotEmpty;
}

/// Клавиши строки задачи в фокусе, которые меняют задачу или выделение (help
/// «Use keyboard shortcuts», docs/TODOIST_PARITY.md §10): `e`, `1–4`, `t`,
/// `Shift+T`, `l`, `v`, `y`, `.`, `x`, `Shift+Delete`, `Ctrl+]` / `Ctrl+[`
/// (при [hierarchy]). Строка проверяет до вызова, что задачу можно менять.
/// `Shift+Delete` при выделении — не задача в фокусе, а выделенные: клавишу
/// забирает оболочка (`SelectionKeys`). У невыделяемой строки ([selectable]
/// `false`: подзадача в окне задачи) выделение списка — не её дело: клавиша
/// удаляет её задачу.
KeyEventResult taskRowEditKey({
  required BuildContext context,
  required WidgetRef ref,
  required Task task,
  required LogicalKeyboardKey key,
  required bool hierarchy,
  required VoidCallback complete,
  required VoidCallback openMenu,
  required VoidCallback toggleSelected,
  bool selectable = true,
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
      case LogicalKeyboardKey.delete
          when !selectable || !_hasLiveSelection(ref):
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

/// `Ctrl+E` и `Alt+E` (Windows, help «Use keyboard shortcuts»: «Edit task») —
/// у задачи в фокусе то же, что «Редактировать» в меню строки.
bool isEditShortcut(LogicalKeyboardKey key) {
  final keys = HardwareKeyboard.instance;
  return key == LogicalKeyboardKey.keyE &&
      !keys.isShiftPressed &&
      !keys.isMetaPressed &&
      keys.isControlPressed != keys.isAltPressed;
}

/// Клик по строке задачи (help «Use keyboard shortcuts», «Add or manage
/// multiple tasks»): `Ctrl+Shift` — диапазон от прошлой выделенной, `Ctrl`
/// или `Shift` — выделить; в режиме выделения на телефоне касание выделяет;
/// обычный клик снимает выделение и открывает панель (решение 2А «Ход
/// M4.8»). [canSelect] `false` — только открыть; [order] — порядок соседей
/// списка для диапазона.
void taskRowTap({
  required WidgetRef ref,
  required Task task,
  required Workspace ws,
  required bool canSelect,
  required List<String> Function(Workspace ws)? order,
  required VoidCallback toggleSelected,
  required VoidCallback open,
}) {
  final keys = HardwareKeyboard.instance;
  final ctrl = keys.isControlPressed;
  final shift = keys.isShiftPressed;
  if (canSelect && ctrl && shift) {
    ref
        .read(taskSelectionProvider.notifier)
        .selectRange(task.id, ws, order: order);
  } else if (canSelect &&
      (ctrl || shift || ref.read(taskSelectionProvider).touchMode)) {
    toggleSelected();
  } else {
    open();
  }
}
