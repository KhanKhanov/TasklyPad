import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../../nlp/scanner.dart';

/// Нажатие по подсвеченному участку поля ввода внутри [child]: [onTap] с
/// участком — клик по подсветке отменяет разбор (help «Use Task Quick Add»).
/// Протяжка (выделение мышью) и правый клик (меню поля) не считаются.
class HighlightTapRegion extends StatefulWidget {
  const HighlightTapRegion({
    super.key,
    required this.spans,
    required this.onTap,
    required this.child,
  });

  /// Подсвеченные участки сейчас.
  final List<Span> Function() spans;
  final void Function(Span span) onTap;
  final Widget child;

  @override
  State<HighlightTapRegion> createState() => _HighlightTapRegionState();
}

class _HighlightTapRegionState extends State<HighlightTapRegion> {
  Offset? _down;

  void _onPointerUp(PointerUpEvent event) {
    final down = _down;
    _down = null;
    if (down == null || (event.position - down).distance > kTouchSlop) return;
    final editable = _renderEditable();
    if (editable == null) return;
    final local = editable.globalToLocal(event.position);
    for (final s in widget.spans()) {
      final boxes = editable.getBoxesForSelection(
        TextSelection(baseOffset: s.start, extentOffset: s.end),
      );
      if (boxes.any((b) => b.toRect().contains(local))) {
        widget.onTap(s);
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

    final root = context.findRenderObject();
    if (root != null) visit(root);
    return found;
  }

  @override
  Widget build(BuildContext context) => Listener(
    // Только основная кнопка: правый клик открывает меню поля.
    onPointerDown: (e) =>
        _down = e.buttons & kPrimaryButton != 0 ? e.position : null,
    onPointerUp: _onPointerUp,
    child: widget.child,
  );
}
