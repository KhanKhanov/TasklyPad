import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../common/ui/ui_kit.dart';
import '../../tasks/ui/task_actions.dart';

/// Хоткеи оболочки, как в Todoist: `m` — сайдбар; `g`, затем буква —
/// переход: `i` «Входящие», `p` «Мои проекты». Остальные переходы (`h`, `t`,
/// `u`, `v`, `l`) появятся вместе с их экранами. Пока печатают в поле —
/// клавиши уходят в поле.
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
}

class _ShellKeysState extends State<ShellKeys> {
  /// Когда нажата `g` (время события клавиатуры): следующая клавиша в
  /// пределах [_goWindow] выбирает экран. Срок в help не указан — допущение.
  Duration? _goAt;

  static const Duration _goWindow = Duration(milliseconds: 1500);

  static final Map<LogicalKeyboardKey, String> _routes = {
    LogicalKeyboardKey.keyI: '/',
    LogicalKeyboardKey.keyP: '/projects',
  };

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || isTypingInTextField()) {
      return KeyEventResult.ignored;
    }
    final keys = HardwareKeyboard.instance;
    final goAt = _goAt;
    _goAt = null; // любая клавиша после `g` завершает сочетание
    if (keys.isControlPressed || keys.isAltPressed || keys.isMetaPressed) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (goAt != null && event.timeStamp - goAt <= _goWindow) {
      final path = _routes[key];
      if (path == null) return KeyEventResult.ignored;
      navigate(context, path);
      return KeyEventResult.handled;
    }
    if (keys.isShiftPressed) return KeyEventResult.ignored;
    switch (key) {
      case LogicalKeyboardKey.keyG:
        _goAt = event.timeStamp;
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
