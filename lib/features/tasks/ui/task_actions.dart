import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/data_providers.dart';
import '../../../domain/models.dart';
import '../../../domain/undo.dart';
import '../../../l10n/app_localizations.dart';
import '../../common/ui/ui_kit.dart';

/// Длительность тоста «Отменить»: в help Todoist — «несколько секунд»,
/// точнее нигде нет (docs/plans/m2-core-app.md «Сверка с Todoist»).
const Duration undoToastDuration = Duration(seconds: 5);

/// Тост с кнопкой «Отменить», как в Todoist: слева внизу, несколько секунд.
/// Отмена работает и когда строки уже нет (выполненная задача скрылась),
/// поэтому берёт [messenger], а не `context`.
///
/// Пока тост виден, `Ctrl+Z` делает то же, что кнопка (help «Use keyboard
/// shortcuts»: «Click Undo or press Ctrl+Z before the message closes»), кроме
/// поля ввода — там это отмена правки текста. Клавишу слушает содержимое
/// тоста ([_UndoShortcut]): обработчик живёт, пока тост на экране, и
/// снимается и при закрытии окна задачи вместе с её `ScaffoldMessenger`.
void showUndoToast(
  ScaffoldMessengerState messenger,
  AppLocalizations l10n,
  String message,
  UndoAction undo,
) {
  var used = false;
  late final bool Function() undoByKey;
  void run() {
    if (used) return;
    used = true;
    if (identical(_currentUndoToast[messenger], undoByKey)) {
      _currentUndoToast[messenger] = null;
    }
    unawaited(runGuarded(messenger, l10n, undo.call));
  }

  undoByKey = () {
    run();
    messenger.hideCurrentSnackBar();
    return true;
  };
  _currentUndoToast[messenger] = undoByKey;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: _UndoShortcut(
          // Уходящий прежний тост ещё на экране, пока новый ждёт очереди:
          // `Ctrl+Z` отменяет последнее действие, а не то, чей тост виден.
          onUndo: () => _currentUndoToast[messenger]?.call() ?? false,
          child: Text(message),
        ),
        duration: undoToastDuration,
        // Тост с кнопкой во Flutter по умолчанию не закрывается сам
        // (`persist = action != null`); в Todoist он уходит через секунды.
        persist: false,
        behavior: SnackBarBehavior.floating,
        width: 360,
        action: SnackBarAction(label: l10n.actionUndo, onPressed: run),
      ),
    );
}

/// Отмена последнего действия с тостом у каждого `ScaffoldMessenger`:
/// `Ctrl+Z` относится только к нему. Ключ — сам мессенджер, поэтому запись
/// уходит вместе с ним (окно задачи закрыто — запись собрана сборщиком).
final Expando<bool Function()> _currentUndoToast = Expando('тост «Отменить»');

/// Содержимое тоста, которое слушает `Ctrl+Z`, пока стоит на экране.
class _UndoShortcut extends StatefulWidget {
  const _UndoShortcut({required this.onUndo, required this.child});

  /// `true` — клавиша обработана.
  final bool Function() onUndo;
  final Widget child;

  @override
  State<_UndoShortcut> createState() => _UndoShortcutState();
}

class _UndoShortcutState extends State<_UndoShortcut> {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    final keys = HardwareKeyboard.instance;
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.keyZ ||
        !keys.isControlPressed ||
        keys.isShiftPressed ||
        keys.isAltPressed ||
        keys.isMetaPressed ||
        isTypingInTextField()) {
      return false;
    }
    return widget.onUndo();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Выполнить или вернуть в работу. Выполнение — с тостом «Отменить».
Future<void> toggleComplete(BuildContext context, WidgetRef ref, Task task) {
  final commands = ref.read(taskCommandsProvider);
  if (task.isCompleted) {
    return runCommand(context, () => commands.uncomplete(task.id));
  }
  return runWithUndo(
    context,
    AppLocalizations.of(context).taskCompleted,
    () => commands.complete(task.id),
  );
}

/// Удалить после подтверждения — без «Отменить», как в Todoist.
Future<void> deleteTask(BuildContext context, WidgetRef ref, Task task) async {
  final l10n = AppLocalizations.of(context);
  final ok = await confirmAction(
    context,
    title: l10n.deleteTaskTitle,
    body: l10n.deleteTaskBody(task.content),
    action: l10n.actionDelete,
    danger: true,
  );
  if (!ok || !context.mounted) return;
  await runCommand(
    context,
    () => ref.read(taskCommandsProvider).delete(task.id),
  );
}

/// Действие с отменой (выполнение, перенос, смена срока): тост после
/// успеха. Действие ничего не изменило (повторное нажатие) — тоста нет:
/// иначе пустая отмена заменила бы тост первого нажатия.
Future<void> runWithUndo(
  BuildContext context,
  String message,
  Future<UndoAction> Function() action,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppLocalizations.of(context);
  UndoAction? undo;
  await runGuarded(messenger, l10n, () async => undo = await action());
  final done = undo;
  if (done != null && !done.isEmpty && messenger.mounted) {
    showUndoToast(messenger, l10n, message, done);
  }
}

/// Пользователь сейчас печатает в поле: однобуквенные хоткеи не действуют.
bool isTypingInTextField() {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null) return false;
  return context.widget is EditableText ||
      context.findAncestorWidgetOfExactType<EditableText>() != null;
}

/// Действие хоткея, которое не срабатывает (и не съедает клавишу), пока
/// пользователь печатает: буква уходит в поле ввода. [blocked] — ещё одно
/// условие пропустить клавишу: после `g` или `o` она нужна оболочке
/// (`o s` — «Настройки», а не «Добавить раздел»).
class HotkeyAction<T extends Intent> extends Action<T> {
  HotkeyAction(this.onInvoke, {this.blocked});

  final void Function() onInvoke;
  final bool Function()? blocked;

  @override
  bool isEnabled(T intent) =>
      !isTypingInTextField() && !(blocked?.call() ?? false);

  @override
  Object? invoke(T intent) {
    onInvoke();
    return null;
  }
}

/// Хоткеи Todoist в списке и на экране (docs/TODOIST_PARITY.md §10).
class AddTaskBottomIntent extends Intent {
  const AddTaskBottomIntent();
}

class AddTaskTopIntent extends Intent {
  const AddTaskTopIntent();
}

class AddSectionIntent extends Intent {
  const AddSectionIntent();
}

const Map<ShortcutActivator, Intent> projectShortcuts = {
  SingleActivator(LogicalKeyboardKey.keyA): AddTaskBottomIntent(),
  SingleActivator(LogicalKeyboardKey.keyA, shift: true): AddTaskTopIntent(),
  SingleActivator(LogicalKeyboardKey.keyS): AddSectionIntent(),
};
