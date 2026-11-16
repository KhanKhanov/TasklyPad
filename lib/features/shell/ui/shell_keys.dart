import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../tasks/ui/task_actions.dart';
import '../logic/shell_commands.dart';

/// Хоткеи оболочки, как в Todoist: команды — таблица [shellCommands]
/// (переходы `g`, `o`, `Ctrl+1…5`, быстрое добавление `q` и `Ctrl+N`,
/// `Ctrl+S`, `m`, `Ctrl+Shift+F`, поиск `/`, `f`, `Ctrl+F`, `Ctrl+K`) —
/// уходят в [onCommand]; `j`/`↓` и `k`/`↑` без задачи в фокусе — к первой
/// и последней задаче списка; `Esc` — «назад», когда закрывать нечего;
/// `Alt+←` / `Alt+→` — назад и вперёд по экранам. Переход `h` появится
/// вместе с «Главной». Пока печатают в поле — клавиши уходят в поле.
class ShellKeys extends StatefulWidget {
  const ShellKeys({
    super.key,
    required this.onCommand,
    required this.onBack,
    required this.onForward,
    required this.child,
  });

  /// Команда таблицы [shellCommands] по её клавише.
  final ValueChanged<ShellCommandId> onCommand;

  /// `Alt+←` и `Alt+→` — «Назад» и «Вперёд» (help «Use keyboard shortcuts»,
  /// Windows).
  final VoidCallback onBack;
  final VoidCallback onForward;
  final Widget child;

  @override
  State<ShellKeys> createState() => _ShellKeysState();

  /// Нажата `g` или `o` и ждётся вторая клавиша: строка задачи и клавиши
  /// экрана её не забирают (`g v` — экран, а не «Перенести»; `o s` —
  /// «Настройки», а не «Добавить раздел»).
  static bool sequencePending(BuildContext context) =>
      context.findAncestorStateOfType<_ShellKeysState>()?._pending ?? false;
}

/// Фокус строки списка (строка задачи): в такие строки `j`/`↓` и `k`/`↑`
/// заводят фокус, когда ни одна не выбрана.
class ListRowFocusNode extends FocusNode {}

class _ShellKeysState extends State<ShellKeys> {
  /// Нажата `g` или `o` ([_prefix]): следующая клавиша в пределах [_goWindow]
  /// выбирает экран.
  /// Срок в help не указан — допущение О-24. Время — свой секундомер, а не
  /// время события: на Android оно без перерисовки экрана не растёт.
  final Stopwatch _sinceGo = Stopwatch();
  LogicalKeyboardKey? _prefix;

  static const Duration _goWindow = Duration(milliseconds: 1500);

  bool get _pending => _sinceGo.isRunning && _sinceGo.elapsed <= _goWindow;

  /// `j`/`↓` (`k`/`↑`) без строки в фокусе — к первой (последней) видимой
  /// строке списка на экране: help «Use keyboard shortcuts» — «Move focus
  /// down (J or ↓)»; иначе `t`, `e` и прочие клавиши задачи было не к чему
  /// применить без мыши. Строка в фокусе обрабатывает эти клавиши сама.
  /// Строки экрана под другим (под «Конфликтами») и прокрученные за край
  /// списка не выбираются: клавиши задачи сработали бы на невидимой.
  bool _focusRow(FocusNode shell, {required bool first}) {
    final rows =
        shell.traversalDescendants
            .whereType<ListRowFocusNode>()
            .where((n) => n.canRequestFocus && _visible(n))
            .toList()
          ..sort((a, b) => a.rect.top.compareTo(b.rect.top));
    if (rows.isEmpty) return false;
    final row = first ? rows.first : rows.last;
    row.requestFocus();
    // Строка видна частично — прокрутить её целиком.
    unawaited(Scrollable.ensureVisible(row.context!));
    return true;
  }

  /// Строка на текущем экране и хотя бы частью в окне своего списка.
  static bool _visible(FocusNode row) {
    final context = row.context;
    if (context == null) return false;
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return false;
    final list = Scrollable.maybeOf(context)?.context.findRenderObject();
    if (list is! RenderBox || !list.hasSize) return true;
    return (list.localToGlobal(Offset.zero) & list.size).overlaps(row.rect);
  }

  /// Ничего не выбрано: фокус на экране или области (у узла есть свои
  /// фокусируемые потомки), а не на кнопке. Только тогда стрелки ведут к
  /// строке, иначе они двигают фокус между кнопками.
  static bool get _nothingFocused {
    final focus = FocusManager.instance.primaryFocus;
    return focus == null ||
        focus is FocusScopeNode ||
        focus.descendants.isNotEmpty;
  }

  /// Есть что закрыть по `Esc`: от элемента в фокусе вверх найдено включённое
  /// действие «закрыть» ([DismissIntent]). Меню регистрирует его, только пока
  /// открыто; у экрана оно выключено. Поиск — как у [ShortcutManager].
  static bool get _canDismiss {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null) return false;
    final action = Actions.maybeFind<DismissIntent>(context);
    return action != null && action.isEnabled(const DismissIntent());
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final prefix = _pending ? _prefix : null;
    // Любая клавиша после `g` или `o` завершает сочетание, в том числе в поле.
    _sinceGo
      ..stop()
      ..reset();
    if (isTypingInTextField()) return KeyEventResult.ignored;
    final keys = HardwareKeyboard.instance;
    final key = event.logicalKey;
    final ctrl = keys.isControlPressed;
    final shift = keys.isShiftPressed;
    final alt = keys.isAltPressed;
    final meta = keys.isMetaPressed;
    if (ctrl && !alt && !meta) {
      final command = shellCommandFor(key: key, ctrl: true, shift: shift);
      if (command == null) return KeyEventResult.ignored;
      widget.onCommand(command.id);
      return KeyEventResult.handled;
    }
    final altOnly = alt && !ctrl && !shift && !meta;
    if (altOnly && key == LogicalKeyboardKey.arrowLeft) {
      widget.onBack();
      return KeyEventResult.handled;
    }
    if (altOnly && key == LogicalKeyboardKey.arrowRight) {
      widget.onForward();
      return KeyEventResult.handled;
    }
    if (ctrl || alt || meta) return KeyEventResult.ignored;
    if (prefix != null) {
      final command = shellCommandFor(prefix: prefix, key: key);
      if (command == null) return KeyEventResult.ignored;
      widget.onCommand(command.id);
      return KeyEventResult.handled;
    }
    // Клавиша без модификаторов или символ. `/` — и по положению клавиши
    // (в русской раскладке она печатает `.`, как буквы сочетаний — по
    // положению), и по символу (в русской раскладке `/` — Shift+`\`).
    final slashKey = !shift && event.physicalKey == PhysicalKeyboardKey.slash;
    final command = shellCommandFor(
      key: key,
      character: slashKey ? '/' : event.character,
      shift: shift,
    );
    if (command != null) {
      widget.onCommand(command.id);
      return KeyEventResult.handled;
    }
    if (shift) return KeyEventResult.ignored;
    if (shellPrefixes.contains(key)) {
      _prefix = key;
      _sinceGo.start();
      return KeyEventResult.handled;
    }
    switch (key) {
      // `Esc` — «назад», как `Alt+←`, когда закрывать нечего (отступление от
      // Todoist, где `Esc` только отменяет, — решение 1Б plans/m5 «Решения
      // проверки M5.3»). Поля, окна и меню «Отображение» обрабатывают `Esc`
      // раньше, выделение задач снимает [SelectionKeys]. Меню строки и
      // раздела, выдвижной сайдбар закрывает общее сочетание приложения выше
      // по дереву ([_canDismiss]) — ему `Esc` и уходит; видимую подсказку
      // `Esc` прячет.
      case LogicalKeyboardKey.escape:
        if (_canDismiss) return KeyEventResult.ignored;
        if (!Tooltip.dismissAllToolTips()) widget.onBack();
      case LogicalKeyboardKey.keyJ:
        if (!_focusRow(node, first: true)) return KeyEventResult.ignored;
      case LogicalKeyboardKey.keyK:
        if (!_focusRow(node, first: false)) return KeyEventResult.ignored;
      case LogicalKeyboardKey.arrowDown || LogicalKeyboardKey.arrowUp:
        if (!_nothingFocused ||
            !_focusRow(node, first: key == LogicalKeyboardKey.arrowDown)) {
          return KeyEventResult.ignored;
        }
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) =>
      Focus(canRequestFocus: false, onKeyEvent: _onKey, child: widget.child);
}
