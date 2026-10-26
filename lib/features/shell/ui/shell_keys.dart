import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../common/ui/ui_kit.dart';
import '../../tasks/ui/task_actions.dart';

/// Хоткеи оболочки, как в Todoist: `m` — сайдбар; `g`, затем буква —
/// переход: `i` «Входящие», `p` «Мои проекты», `v` и `l` «Фильтры и метки».
/// Остальные переходы (`h`, `t`, `u`) появятся вместе с их экранами. Пока
/// печатают в поле — клавиши уходят в поле.
class ShellKeys extends StatefulWidget {
  const ShellKeys({
    super.key,
    required this.onToggleSidebar,
    required this.child,
  });

  final VoidCallback onToggleSidebar;
  final Widget child;

  @override
  State<ShellKeys> createState() => _ShellKeysState();

  /// Нажата `g` и ждётся вторая клавиша: строка задачи в фокусе её не
  /// забирает (`g v` — экран, а не «Перенести»).
  static bool sequencePending(BuildContext context) =>
      context.findAncestorStateOfType<_ShellKeysState>()?._pending ?? false;
}

class _ShellKeysState extends State<ShellKeys> {
  /// Нажата `g`: следующая клавиша в пределах [_goWindow] выбирает экран.
  /// Срок в help не указан — допущение О-24. Время — свой секундомер, а не
  /// время события: на Android оно без перерисовки экрана не растёт.
  final Stopwatch _sinceGo = Stopwatch();

  static const Duration _goWindow = Duration(milliseconds: 1500);

  static final Map<LogicalKeyboardKey, String> _routes = {
    LogicalKeyboardKey.keyI: '/',
    LogicalKeyboardKey.keyP: '/projects',
    LogicalKeyboardKey.keyV: '/filters-labels',
    LogicalKeyboardKey.keyL: '/filters-labels',
  };

  bool get _pending => _sinceGo.isRunning && _sinceGo.elapsed <= _goWindow;

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final go = _pending;
    // Любая клавиша после `g` завершает сочетание, в том числе набранная в поле.
    _sinceGo
      ..stop()
      ..reset();
    if (isTypingInTextField()) return KeyEventResult.ignored;
    final keys = HardwareKeyboard.instance;
    if (keys.isControlPressed || keys.isAltPressed || keys.isMetaPressed) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (go) {
      final path = _routes[key];
      if (path == null) return KeyEventResult.ignored;
      navigate(context, path);
      return KeyEventResult.handled;
    }
    if (keys.isShiftPressed) return KeyEventResult.ignored;
    switch (key) {
      case LogicalKeyboardKey.keyG:
        _sinceGo.start();
      case LogicalKeyboardKey.keyM:
        widget.onToggleSidebar();
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) =>
      Focus(canRequestFocus: false, onKeyEvent: _onKey, child: widget.child);
}
