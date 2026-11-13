import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../common/ui/ui_kit.dart';
import '../../tasks/ui/task_actions.dart';

/// Хоткеи оболочки, как в Todoist: `q` и `Ctrl+N` — быстрое добавление;
/// `Ctrl+S` — синхронизация; `j`/`↓` и `k`/`↑` без задачи в фокусе — к
/// первой и последней задаче списка; `m` —
/// сайдбар; `g`, затем буква — переход: `i` «Входящие», `t` «Сегодня», `u`
/// «Предстоящее», `p` «Мои проекты», `v` и `l` «Фильтры и метки»; `o` `s` —
/// «Настройки», `o` `t` — «Тема»; `Ctrl+1/2/3/4/5` — «Входящие», «Сегодня»,
/// «Предстоящее», «Проекты», «Фильтры и метки»; `Alt+←` / `Alt+→` — назад и вперёд по экранам. Переход `h`
/// появится вместе с «Главной». Пока печатают в поле — клавиши уходят в поле.
class ShellKeys extends StatefulWidget {
  const ShellKeys({
    super.key,
    required this.onToggleSidebar,
    required this.onQuickAdd,
    required this.onSync,
    required this.onBack,
    required this.onForward,
    required this.child,
  });

  final VoidCallback onToggleSidebar;
  final VoidCallback onQuickAdd;

  /// `Ctrl+S` — «Синхронизировать».
  final VoidCallback onSync;

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

  static final Map<LogicalKeyboardKey, Map<LogicalKeyboardKey, String>>
  _routes = {
    LogicalKeyboardKey.keyG: {
      LogicalKeyboardKey.keyI: '/',
      LogicalKeyboardKey.keyT: '/today',
      LogicalKeyboardKey.keyU: '/upcoming',
      LogicalKeyboardKey.keyP: '/projects',
      LogicalKeyboardKey.keyV: '/filters-labels',
      LogicalKeyboardKey.keyL: '/filters-labels',
    },
    // `o t` — «Настройки», открытые на «Теме».
    LogicalKeyboardKey.keyO: {
      LogicalKeyboardKey.keyS: '/settings',
      LogicalKeyboardKey.keyT: '/settings?section=theme',
    },
  };

  /// `Ctrl+1/2/3` — «Перейти во Входящие / Сегодня / Предстоящее», `Ctrl+4/5` —
  /// «Проекты» и «Фильтры и метки» (help «Use keyboard shortcuts»: строки
  /// таблицы «mobile keyboard»; у нас на всех платформах, как `Ctrl+1/2/3`;
  /// решение 2А «Ход M4.13»).
  static final Map<LogicalKeyboardKey, String> _ctrlRoutes = {
    LogicalKeyboardKey.digit1: '/',
    LogicalKeyboardKey.digit2: '/today',
    LogicalKeyboardKey.digit3: '/upcoming',
    LogicalKeyboardKey.digit4: '/projects',
    LogicalKeyboardKey.digit5: '/filters-labels',
  };

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
    // `Ctrl+N` — «Открыть быстрое добавление задачи», `Ctrl+S` —
    // «Синхронизировать» (help «Use keyboard shortcuts», Windows).
    final ctrlOnly =
        keys.isControlPressed &&
        !keys.isShiftPressed &&
        !keys.isAltPressed &&
        !keys.isMetaPressed;
    if (ctrlOnly && key == LogicalKeyboardKey.keyN) {
      widget.onQuickAdd();
      return KeyEventResult.handled;
    }
    if (ctrlOnly && key == LogicalKeyboardKey.keyS) {
      widget.onSync();
      return KeyEventResult.handled;
    }
    if (_ctrlRoutes[key] case final path? when ctrlOnly) {
      navigate(context, path);
      return KeyEventResult.handled;
    }
    final altOnly =
        keys.isAltPressed &&
        !keys.isControlPressed &&
        !keys.isShiftPressed &&
        !keys.isMetaPressed;
    if (altOnly && key == LogicalKeyboardKey.arrowLeft) {
      widget.onBack();
      return KeyEventResult.handled;
    }
    if (altOnly && key == LogicalKeyboardKey.arrowRight) {
      widget.onForward();
      return KeyEventResult.handled;
    }
    if (keys.isControlPressed || keys.isAltPressed || keys.isMetaPressed) {
      return KeyEventResult.ignored;
    }
    if (prefix != null) {
      final path = _routes[prefix]?[key];
      if (path == null) return KeyEventResult.ignored;
      navigate(context, path);
      return KeyEventResult.handled;
    }
    if (keys.isShiftPressed) return KeyEventResult.ignored;
    switch (key) {
      case LogicalKeyboardKey.keyG || LogicalKeyboardKey.keyO:
        _prefix = key;
        _sinceGo.start();
      case LogicalKeyboardKey.keyM:
        widget.onToggleSidebar();
      case LogicalKeyboardKey.keyQ:
        widget.onQuickAdd();
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
