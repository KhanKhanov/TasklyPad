import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/data_providers.dart';
import '../../../domain/markdown_text.dart';
import '../../../domain/models.dart';
import '../../../domain/undo.dart';
import '../../../l10n/app_localizations.dart';
import '../../common/ui/app_toast.dart';
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
/// поля ввода — там это отмена правки текста. Видимые тосты (оболочки и окна
/// задачи) — один общий стек: клавиша отменяет последнее показанное действие,
/// а не все сразу. Запись живёт, пока тост на экране ([_UndoShortcut]).
void showUndoToast(
  ScaffoldMessengerState messenger,
  AppLocalizations l10n,
  String message,
  UndoAction undo,
) {
  var used = false;
  void run() {
    if (used) return;
    used = true;
    unawaited(runGuarded(messenger, l10n, undo.call));
  }

  late final AppToast toast;
  final entry = _UndoEntry(messenger, () {
    run();
    toast.dismiss();
  });
  // Уходящий прежний тост этого же мессенджера ещё на экране, пока новый
  // ждёт очереди: `Ctrl+Z` отменяет последнее действие, а не то, чей тост
  // виден.
  _visibleUndos.removeWhere((e) => identical(e.messenger, messenger));
  _visibleUndos.add(entry);
  messenger.hideCurrentSnackBar();
  toast = showAppToast(
    messenger,
    text: message,
    duration: undoToastDuration,
    action: (label: l10n.actionUndo, onPressed: run),
    wrap: (body) => _UndoShortcut(entry: entry, child: body),
  );
}

/// Тост «Отменить», видимый сейчас: что сделает нажатие `Ctrl+Z`.
class _UndoEntry {
  _UndoEntry(this.messenger, this.fire);

  final ScaffoldMessengerState messenger;
  final VoidCallback fire;

  /// Сколько экземпляров содержимого тоста на экране: эффект «джин» рисует
  /// его несколько раз (полосками), и запись уходит, когда не осталось ни
  /// одного.
  int live = 0;
}

/// Видимые тосты «Отменить» всего приложения, последний — самый новый.
final List<_UndoEntry> _visibleUndos = [];

/// Событие `Ctrl+Z`, которое уже обработано, и результат: обработчик есть у
/// каждого видимого тоста, а отменить нужно одно действие на одно нажатие.
KeyEvent? _lastUndoEvent;
bool _lastUndoHandled = false;

bool _undoLast(KeyEvent event) {
  if (identical(_lastUndoEvent, event)) return _lastUndoHandled;
  _lastUndoEvent = event;
  _visibleUndos.removeWhere((e) => !e.messenger.mounted);
  if (_visibleUndos.isEmpty) return _lastUndoHandled = false;
  _visibleUndos.removeLast().fire();
  return _lastUndoHandled = true;
}

/// Содержимое тоста, которое слушает `Ctrl+Z`, пока стоит на экране.
class _UndoShortcut extends StatefulWidget {
  const _UndoShortcut({required this.entry, required this.child});

  final _UndoEntry entry;
  final Widget child;

  @override
  State<_UndoShortcut> createState() => _UndoShortcutState();
}

class _UndoShortcutState extends State<_UndoShortcut> {
  @override
  void initState() {
    super.initState();
    widget.entry.live++;
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    if (--widget.entry.live == 0) _visibleUndos.remove(widget.entry);
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
    return _undoLast(event);
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

/// «Выполнить окончательно» повторяющуюся задачу — с тостом «Отменить»
/// (help «Complete a task with a recurring date»).
Future<void> completeForever(BuildContext context, WidgetRef ref, Task task) =>
    runWithUndo(
      context,
      AppLocalizations.of(context).taskCompleted,
      () => ref.read(taskCommandsProvider).completeForever(task.id),
    );

/// «Выполнить и снова добавить подзадачи» — сброс подзадач и при выключенной
/// настройке (help «Reset a sub-task»), с тостом «Отменить».
Future<void> completeResettingSubtasks(
  BuildContext context,
  WidgetRef ref,
  Task task,
) => runWithUndo(
  context,
  AppLocalizations.of(context).taskCompleted,
  () => ref.read(taskCommandsProvider).complete(task.id, resetSubtasks: true),
);

/// Удалить после подтверждения — без «Отменить», как в Todoist.
Future<void> deleteTask(BuildContext context, WidgetRef ref, Task task) async {
  final l10n = AppLocalizations.of(context);
  final ok = await confirmAction(
    context,
    title: l10n.deleteTaskTitle,
    body: l10n.deleteTaskBody(plainText(task.content)),
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
/// иначе пустая отмена заменила бы тост первого нажатия. Результат — отмена
/// сделанного; `null`, если действие отказало или ничего не изменило.
/// [messenger] — где показать тост, если не там, где стоит [context]: пункты
/// меню лежат в корневом навигаторе, а тост нужен в окне задачи.
Future<UndoAction?> runWithUndo(
  BuildContext context,
  String message,
  Future<UndoAction> Function() action, {
  ScaffoldMessengerState? messenger,
}) async {
  messenger ??= ScaffoldMessenger.of(context);
  final l10n = AppLocalizations.of(context);
  UndoAction? undo;
  await runGuarded(messenger, l10n, () async => undo = await action());
  final done = undo;
  if (done == null || done.isEmpty) return null;
  if (messenger.mounted) showUndoToast(messenger, l10n, message, done);
  return done;
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

/// Клавиши проекта и «Входящих»: [projectShortcuts] и на Android ещё
/// `Ctrl+Shift+N` — то же, что `Shift+A` (help «Use keyboard shortcuts»: строка
/// таблицы «mobile keyboard», «only works inside projects»). На Windows её нет:
/// там `Ctrl+Shift+N` — «Открыть вид в новом окне» (M9, решение 2А «Ход
/// M4.13»).
Map<ShortcutActivator, Intent> projectScreenShortcuts() => {
  ...projectShortcuts,
  if (defaultTargetPlatform == TargetPlatform.android)
    const SingleActivator(LogicalKeyboardKey.keyN, control: true, shift: true):
        const AddTaskTopIntent(),
};
