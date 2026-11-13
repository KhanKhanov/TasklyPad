import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// `MenuAnchor`, который, пока открыт, не пропускает клавиши сквозь себя.
///
/// Меню, открытое мышью, фокус не забирает: он остаётся в списке, и буквы
/// шли бы туда — `q` открывало бы быстрое добавление, `d` меняло сортировку,
/// `j` уводило фокус. Поэтому при открытии фокус берёт сам виджет, а клавиши
/// без `Ctrl` / `Alt` / `Meta` (буквы и цифры, и с `Shift`) он поглощает.
/// Остальное работает как в меню: `Esc` закрывает его и возвращает фокус
/// туда, где он был; стрелка вниз (вверх) переводит фокус на первый
/// (последний) пункт, дальше стрелки и `Enter` ведёт само меню.
class ShieldedMenuAnchor extends StatefulWidget {
  const ShieldedMenuAnchor({
    super.key,
    required this.menuChildren,
    required this.builder,
  });

  final List<Widget> menuChildren;
  final Widget Function(
    BuildContext context,
    MenuController controller,
    Widget? child,
  )
  builder;

  @override
  State<ShieldedMenuAnchor> createState() => _ShieldedMenuAnchorState();
}

class _ShieldedMenuAnchorState extends State<ShieldedMenuAnchor> {
  final MenuController _controller = MenuController();
  final FocusNode _shield = FocusNode(
    debugLabel: 'ShieldedMenuAnchor',
    skipTraversal: true,
  );
  FocusNode? _before;
  bool _open = false;

  @override
  void dispose() {
    _shield.dispose();
    super.dispose();
  }

  void _onOpen() {
    _open = true;
    _before = FocusManager.instance.primaryFocus;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Мышь над пунктом уже могла отдать ему фокус — не отбираем.
      if (_open && mounted && !_shield.hasFocus) _shield.requestFocus();
    });
  }

  void _onClose() {
    _open = false;
    final before = _before;
    _before = null;
    if (_shield.hasPrimaryFocus && before != null && before.canRequestFocus) {
      before.requestFocus();
    }
  }

  /// Первый (последний) пункт меню: узел внутри `MenuItemButton`.
  void _focusItem({required bool first}) {
    final items = [
      for (final node in _shield.traversalDescendants)
        if (node.canRequestFocus &&
            node.context?.findAncestorWidgetOfExactType<MenuItemButton>() !=
                null)
          node,
    ];
    if (items.isEmpty) return;
    (first ? items.first : items.last).requestFocus();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!_open || event is KeyUpEvent) {
      return _open ? _modifierFree(event) : KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (_shield.hasPrimaryFocus) {
      if (key == LogicalKeyboardKey.escape) {
        _controller.close();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowDown ||
          key == LogicalKeyboardKey.arrowUp) {
        _focusItem(first: key == LogicalKeyboardKey.arrowDown);
        return KeyEventResult.handled;
      }
    }
    return _modifierFree(event);
  }

  /// Поглотить всё, что обрабатывает не само меню: буквы, цифры, `Home` /
  /// `End`, сочетания с `Ctrl` и `Shift+стрелка`. Меню отдаём `Tab` и
  /// `Shift+Tab`, `Esc`, стрелки без модификаторов, `Enter` и пробел. `Ctrl+Z`
  /// тоста «Отменить» не затронут: тост слушает `HardwareKeyboard`, а не дерево
  /// фокуса.
  KeyEventResult _modifierFree(KeyEvent event) {
    final keys = HardwareKeyboard.instance;
    final key = event.logicalKey;
    final plain =
        !keys.isControlPressed && !keys.isAltPressed && !keys.isMetaPressed;
    final menuKey =
        key == LogicalKeyboardKey.tab ||
        (plain &&
            !keys.isShiftPressed &&
            (key == LogicalKeyboardKey.escape ||
                key == LogicalKeyboardKey.arrowUp ||
                key == LogicalKeyboardKey.arrowDown ||
                key == LogicalKeyboardKey.arrowLeft ||
                key == LogicalKeyboardKey.arrowRight ||
                key == LogicalKeyboardKey.enter ||
                key == LogicalKeyboardKey.numpadEnter ||
                key == LogicalKeyboardKey.space));
    final modifier =
        key == LogicalKeyboardKey.controlLeft ||
        key == LogicalKeyboardKey.controlRight ||
        key == LogicalKeyboardKey.shiftLeft ||
        key == LogicalKeyboardKey.shiftRight ||
        key == LogicalKeyboardKey.altLeft ||
        key == LogicalKeyboardKey.altRight ||
        key == LogicalKeyboardKey.metaLeft ||
        key == LogicalKeyboardKey.metaRight;
    return menuKey || modifier
        ? KeyEventResult.ignored
        : KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) => Focus(
    focusNode: _shield,
    onKeyEvent: _onKey,
    child: MenuAnchor(
      controller: _controller,
      onOpen: _onOpen,
      onClose: _onClose,
      menuChildren: widget.menuChildren,
      builder: widget.builder,
    ),
  );
}
