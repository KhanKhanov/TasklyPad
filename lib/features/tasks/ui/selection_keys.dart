import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/data_providers.dart';
import '../../shell/ui/shell_keys.dart';
import '../state/selection.dart';
import 'selection_actions.dart';
import 'task_actions.dart';

/// Клавиши выделения (help «Use keyboard shortcuts»): `,` — фокус на панель
/// выделения ([toolbarFocus]), `Shift+Delete` — удалить выделенные с
/// подтверждением, `Esc` — снять выделение (в help `Esc` — «Dismiss/Cancel»,
/// о выделении не сказано — допущение О-69). Действуют при выделении, пока не
/// печатают в поле и не ждут второй клавиши после `g` / `o`; клавиши приходят
/// от фокуса внутри оболочки — окна поверх неё их не отдают.
class SelectionKeys extends ConsumerWidget {
  const SelectionKeys({
    super.key,
    required this.toolbarFocus,
    required this.child,
  });

  final FocusNode toolbarFocus;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Focus(
    canRequestFocus: false,
    onKeyEvent: (node, event) {
      final selection = ref.read(taskSelectionProvider);
      if (event is! KeyDownEvent ||
          !selection.active ||
          isTypingInTextField() ||
          ShellKeys.sequencePending(context)) {
        return KeyEventResult.ignored;
      }
      final ws = ref.read(workspaceProvider).value;
      final live = ws != null && selection.live(ws).isNotEmpty;
      final keys = HardwareKeyboard.instance;
      if (keys.isControlPressed || keys.isAltPressed || keys.isMetaPressed) {
        return KeyEventResult.ignored;
      }
      switch (event.logicalKey) {
        case LogicalKeyboardKey.escape when !keys.isShiftPressed:
          ref.read(taskSelectionProvider.notifier).clear();
        case LogicalKeyboardKey.comma when !keys.isShiftPressed:
          toolbarFocus.requestFocus();
        // Без видимых выделенных `Shift+Delete` удаляет задачу в фокусе —
        // клавишу обрабатывает строка.
        case LogicalKeyboardKey.delete when keys.isShiftPressed && live:
          selectionDelete(context, ref);
        default:
          return KeyEventResult.ignored;
      }
      return KeyEventResult.handled;
    },
    child: child,
  );
}
