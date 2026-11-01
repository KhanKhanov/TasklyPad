import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/app_palette.dart';
import '../../../l10n/app_localizations.dart';
import '../../../nlp/quick_add.dart';
import '../logic/suggestions.dart';
import '../state/quick_add_controller.dart';
import 'paste_lines.dart';
import 'quick_add_suggestions.dart';

/// Поле названия быстрого добавления: подсветка разобранного, клик по
/// подсветке отменяет разбор участка, список автодополнения по `#`, `/`,
/// `%`, `@` (help «Use Task Quick Add»). `Enter` — [onSubmit], `↓` при
/// закрытом списке — [onArrowDown] (описание), вставка нескольких строк —
/// [onPasteLines].
class QuickAddField extends StatefulWidget {
  const QuickAddField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
    required this.onPasteLines,
    this.onArrowDown,
    this.errorText,
  });

  final QuickAddController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmit;
  final PasteLinesCallback onPasteLines;
  final VoidCallback? onArrowDown;
  final String? errorText;

  @override
  State<QuickAddField> createState() => _QuickAddFieldState();
}

class _QuickAddFieldState extends State<QuickAddField> {
  final LayerLink _link = LayerLink();
  final OverlayPortalController _portal = OverlayPortalController();
  final GlobalKey _fieldKey = GlobalKey();
  int _selected = 0;

  /// Токен, список которого закрыт `Esc`: снова откроется, когда текст
  /// токена изменится.
  String? _closedFor;
  Offset? _down;

  late final PasteLinesFormatter _paste = PasteLinesFormatter(
    (lines, joined) => widget.onPasteLines(lines, joined),
  );

  @override
  void initState() {
    super.initState();
    // Слой списка открыт всегда; пустой список — пустой виджет: показ и
    // скрытие слоя посреди сборки поля не понадобятся.
    _portal.show();
  }

  TokenQuery? get _query {
    final c = widget.controller;
    final selection = c.selection;
    if (!widget.focusNode.hasFocus || !selection.isCollapsed) return null;
    return tokenQueryAt(c.text, selection.baseOffset);
  }

  List<Suggestion> _suggestions(TokenQuery? q) {
    final c = widget.controller;
    final resolver = c.resolver;
    if (q == null || resolver == null || _key(q) == _closedFor) return const [];
    // В описании после `//` токенов нет; в подзадаче `#` и `/` — текст.
    final inDescription = c.highlights.any(
      (h) => h.kind == HighlightKind.description && h.start < q.start,
    );
    final placeLocked =
        c.defaults.parentId != null && q.kind != TokenKind.label;
    if (inDescription || placeLocked) return const [];
    return suggestionsFor(
      q,
      resolver,
      inboxTitle: AppLocalizations.of(context).inbox,
      sectionProjectId: c.draft?.projectId ?? c.defaults.projectId,
    );
  }

  String _key(TokenQuery q) => '${q.start}:${q.sign}${q.query}';

  void _pick(TokenQuery q, Suggestion s) {
    widget.controller.applySuggestion(q, s);
    _selected = 0;
    widget.focusNode.requestFocus();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final keys = HardwareKeyboard.instance;
    final key = event.logicalKey;
    final q = _query;
    final items = _suggestions(q);
    if (items.isNotEmpty && q != null) {
      switch (key) {
        case LogicalKeyboardKey.arrowDown:
          setState(() => _selected = (_selected + 1) % items.length);
          return KeyEventResult.handled;
        case LogicalKeyboardKey.arrowUp:
          setState(
            () => _selected = (_selected - 1 + items.length) % items.length,
          );
          return KeyEventResult.handled;
        case LogicalKeyboardKey.enter ||
            LogicalKeyboardKey.numpadEnter ||
            LogicalKeyboardKey.tab:
          _pick(q, items[_selected.clamp(0, items.length - 1)]);
          return KeyEventResult.handled;
        case LogicalKeyboardKey.escape:
          setState(() => _closedFor = _key(q));
          return KeyEventResult.handled;
      }
    }
    if (keys.isShiftPressed || keys.isControlPressed || keys.isAltPressed) {
      return KeyEventResult.ignored;
    }
    switch (key) {
      case LogicalKeyboardKey.enter || LogicalKeyboardKey.numpadEnter:
        widget.onSubmit();
        return KeyEventResult.handled;
      // Только с курсором в конце: в длинном названии на несколько строк
      // `↓` двигает курсор вниз.
      case LogicalKeyboardKey.arrowDown
          when widget.onArrowDown != null &&
              widget.controller.selection.isCollapsed &&
              widget.controller.selection.baseOffset ==
                  widget.controller.text.length:
        widget.onArrowDown!();
        return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Нажатие, а не протяжка: по точке ищется подсвеченный участок.
  void _onPointerUp(PointerUpEvent event) {
    final down = _down;
    _down = null;
    if (down == null || (event.position - down).distance > kTouchSlop) return;
    final editable = _renderEditable();
    if (editable == null) return;
    final local = editable.globalToLocal(event.position);
    for (final h in widget.controller.highlights) {
      final boxes = editable.getBoxesForSelection(
        TextSelection(baseOffset: h.start, extentOffset: h.end),
      );
      if (boxes.any((b) => b.toRect().contains(local))) {
        widget.controller.dismissAt(h.start);
        return;
      }
    }
  }

  RenderEditable? _renderEditable() {
    RenderEditable? found;
    void visit(RenderObject o) {
      if (found != null) return;
      if (o is RenderEditable) {
        found = o;
      } else {
        o.visitChildren(visit);
      }
    }

    final root = _fieldKey.currentContext?.findRenderObject();
    if (root != null) visit(root);
    return found;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([widget.controller, widget.focusNode]),
      builder: (context, _) {
        final q = _query;
        final items = _suggestions(q);
        if (_closedFor != null && (q == null || _key(q) != _closedFor)) {
          _closedFor = null;
        }
        if (_selected >= items.length) _selected = 0;
        return CompositedTransformTarget(
          link: _link,
          child: OverlayPortal(
            controller: _portal,
            overlayChildBuilder: (context) => CompositedTransformFollower(
              link: _link,
              targetAnchor: Alignment.bottomLeft,
              offset: const Offset(0, 4),
              child: Align(
                alignment: Alignment.topLeft,
                child: q == null || items.isEmpty
                    ? const SizedBox.shrink()
                    : QuickAddSuggestions(
                        kind: q.kind,
                        items: items,
                        selected: _selected,
                        onPick: (s) => _pick(q, s),
                      ),
              ),
            ),
            child: Focus(
              canRequestFocus: false,
              skipTraversal: true,
              onKeyEvent: _onKey,
              child: Listener(
                // Только основная кнопка: правый клик открывает меню поля.
                onPointerDown: (e) =>
                    _down = e.buttons & kPrimaryButton != 0 ? e.position : null,
                onPointerUp: _onPointerUp,
                child: TextField(
                  key: _fieldKey,
                  controller: widget.controller,
                  focusNode: widget.focusNode,
                  // Многострочное поле: вставка отдаёт строки целиком, а не
                  // склеенными (однострочное вырезает переносы до разбора).
                  maxLines: null,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [_paste],
                  decoration: InputDecoration(
                    hintText: l10n.taskNameHint,
                    border: InputBorder.none,
                    errorText: widget.errorText,
                  ),
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  onSubmitted: (_) => widget.onSubmit(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
