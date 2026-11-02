import 'package:flutter/services.dart';

import '../../../nlp/scanner.dart';

/// Место правки [old] → [next] в старой строке по курсору: набор или вставка
/// на месте выделения, Backspace, Delete. `null` — не распознано (тогда
/// [shiftSpans] ищет место по общему началу и концу строк).
Span? editRange(TextEditingValue old, TextEditingValue next) {
  final o = old.selection;
  final n = next.selection;
  if (!o.isValid || !n.isValid || !n.isCollapsed) return null;
  final delta = next.text.length - old.text.length;
  bool same(int start, int end, int inserted) =>
      start >= 0 &&
      end <= old.text.length &&
      start + inserted <= next.text.length &&
      next.text.startsWith(old.text.substring(0, start)) &&
      next.text.substring(start + inserted) == old.text.substring(end);
  // Набор или вставка вместо выделения [o.start, o.end).
  final inserted = delta + (o.end - o.start);
  if (inserted >= 0 &&
      n.baseOffset == o.start + inserted &&
      same(o.start, o.end, inserted)) {
    return Span(o.start, o.end);
  }
  if (o.isCollapsed && delta < 0) {
    final c = o.baseOffset;
    // Backspace: курсор ушёл влево на число стёртых знаков.
    if (n.baseOffset == c + delta && same(c + delta, c, 0)) {
      return Span(c + delta, c);
    }
    // Delete: курсор на месте.
    if (n.baseOffset == c && same(c, c - delta, 0)) return Span(c, c - delta);
  }
  return null;
}

/// Help «Turn smart date recognition on or off»: Backspace сразу после
/// распознанной даты (Delete — перед ней) превращает её в текст, а не
/// стирает знак. Участок даты из [dates] или `null` — правка обычная.
Span? dateDismissedByDelete(
  TextEditingValue old,
  TextEditingValue next,
  Iterable<Span> dates,
) {
  final cursor = old.selection;
  // Пока IME собирает слово, подсветки на экране нет — Backspace стирает
  // знак, как обычно.
  if (old.composing.isValid ||
      !cursor.isCollapsed ||
      next.text.length != old.text.length - 1) {
    return null;
  }
  final c = cursor.baseOffset;
  for (final s in dates) {
    final backspace =
        s.end == c &&
        c > 0 &&
        next.text == old.text.replaceRange(c - 1, c, '') &&
        next.selection.baseOffset == c - 1;
    final delete =
        s.start == c &&
        c < old.text.length &&
        next.text == old.text.replaceRange(c, c + 1, '');
    if (backspace || delete) return s;
  }
  return null;
}
