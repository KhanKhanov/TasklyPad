import '../../../nlp/scanner.dart';

// Участки строки быстрого добавления при правке текста: отменённые кликом
// участки едут вместе со своим текстом, а выбранное чипом убирается из поля.

/// Участки [spans] строки [before] после правки в [after]. Правка — один
/// сплошной кусок между общим началом и общим концом строк: участок до
/// куска остаётся, после — сдвигается, задетый правкой — пропадает (его
/// текст стал другой фразой, и разбор решает заново).
///
/// [changed] — место правки в [before], если известно по курсору
/// (`editRange` в QuickAddController): общее начало и конец строк неоднозначны, когда введённый
/// знак совпадает с соседним («з» перед «завтра»).
List<Span> shiftSpans(
  List<Span> spans,
  String before,
  String after, {
  Span? changed,
}) {
  if (spans.isEmpty || before == after) return spans;
  if (changed != null) {
    final delta = after.length - before.length;
    return [
      for (final s in spans)
        if (s.end <= changed.start)
          s
        else if (s.start >= changed.end)
          Span(s.start + delta, s.end + delta),
    ];
  }
  final shortest = before.length < after.length ? before.length : after.length;
  var prefix = 0;
  while (prefix < shortest && before[prefix] == after[prefix]) {
    prefix++;
  }
  var suffix = 0;
  while (suffix < shortest - prefix &&
      before[before.length - 1 - suffix] == after[after.length - 1 - suffix]) {
    suffix++;
  }
  final changedEnd = before.length - suffix;
  final delta = after.length - before.length;
  return [
    for (final s in spans)
      if (s.end <= prefix)
        s
      else if (s.start >= changedEnd)
        Span(s.start + delta, s.end + delta),
  ];
}

/// Строка [text] без участков [cut] — то, что выбрано чипом (решение 4А
/// «Ход M3.6»). Участки убираются с конца по одному, вместе с пробелом
/// рядом: «завтра купить» → «купить», «купить завтра» → «купить».
/// [dismissed] сдвигаются вместе с текстом.
({String text, List<Span> dismissed}) removeSpans(
  String text,
  List<Span> cut, {
  List<Span> dismissed = const [],
}) {
  final sorted = [...cut]..sort((a, b) => b.start.compareTo(a.start));
  var result = text;
  var kept = dismissed;
  var limit = text.length;
  for (final s in sorted) {
    if (s.end > limit) continue; // перекрывает уже убранный участок
    limit = s.start;
    var start = s.start;
    var end = s.end;
    if (end < result.length && result[end] == ' ') {
      end++;
    } else if (start > 0 && result[start - 1] == ' ') {
      start--;
    }
    final next = result.replaceRange(start, end, '');
    kept = shiftSpans(kept, result, next);
    result = next;
  }
  return (text: result, dismissed: kept);
}
