import 'package:flutter/services.dart';

// Правки разметки в поле с markdown: `Ctrl+B` / `Ctrl+I` и панель
// форматирования (help «Format text in a Todoist task»; решения 7А и 1А
// «Ход M4.12» plans/m4). Каждая правка — список простых замен: поле
// применяет их по одной, чтобы контроллеры с отменёнными датами и токенами
// (`TitleDateController`, `QuickAddController`) видели место каждой.

/// Замена: на месте [at] убрать [remove] знаков и вставить [insert].
typedef MarkdownEdit = ({int at, int remove, String insert});

/// Замены [edits] — с конца строки к началу, чтобы позиции следующих не
/// сдвигались, — и выделение после них.
typedef MarkdownChange = ({List<MarkdownEdit> edits, TextSelection selection});

extension MarkdownChangeApply on MarkdownChange {
  /// Значение поля после всех замен.
  TextEditingValue apply(TextEditingValue value) {
    var text = value.text;
    for (final e in edits) {
      text = text.replaceRange(e.at, e.at + e.remove, e.insert);
    }
    return TextEditingValue(text: text, selection: selection);
  }
}

/// Обернуть выделение [value] знаком [marker] (`**`, `*`, `~~`, `` ` ``) или
/// снять его: знаки вокруг выделения или по краям выделенного. Курсив `*` не
/// снимается с половины жирного `**`. `null` — выделения нет.
MarkdownChange? markerToggle(TextEditingValue value, String marker) {
  final selection = value.selection;
  if (!selection.isValid) return null;
  final text = value.text;
  final (start, end) = (selection.start, selection.end);
  final m = marker.length;
  final inner = text.substring(start, end);

  bool star(int i) => i >= 0 && i < text.length && text[i] == '*';
  // Курсив с жирного курсива «***a***» — снимается одна звёздочка.
  if (marker == '*' &&
      start >= 3 &&
      end + 3 <= text.length &&
      text.substring(start - 3, start) == '***' &&
      text.substring(end, end + 3) == '***') {
    return (
      edits: [
        (at: end, remove: 1, insert: ''),
        (at: start - 1, remove: 1, insert: ''),
      ],
      selection: TextSelection(baseOffset: start - 1, extentOffset: end - 1),
    );
  }
  final around =
      start >= m &&
      end + m <= text.length &&
      text.substring(start - m, start) == marker &&
      text.substring(end, end + m) == marker &&
      !(marker == '*' && (star(start - m - 1) || star(end + m)));
  if (around) {
    return (
      edits: [
        (at: end, remove: m, insert: ''),
        (at: start - m, remove: m, insert: ''),
      ],
      selection: TextSelection(baseOffset: start - m, extentOffset: end - m),
    );
  }
  final edges =
      inner.length >= 2 * m &&
      inner.startsWith(marker) &&
      inner.endsWith(marker) &&
      !(marker == '*' && inner.startsWith('**') && inner.endsWith('**'));
  if (edges) {
    return (
      edits: [
        (at: end - m, remove: m, insert: ''),
        (at: start, remove: m, insert: ''),
      ],
      selection: TextSelection(baseOffset: start, extentOffset: end - 2 * m),
    );
  }
  return (
    edits: [
      (at: end, remove: 0, insert: marker),
      (at: start, remove: 0, insert: marker),
    ],
    selection: TextSelection(baseOffset: start + m, extentOffset: end + m),
  );
}

/// Значение [value] после [markerToggle]; без выделения — без изменений.
TextEditingValue toggleMarker(TextEditingValue value, String marker) =>
    markerToggle(value, marker)?.apply(value) ?? value;

/// Цитата для строк выделения (только описание: help — «Quote is available
/// in descriptions and comments only»): если все строки уже начинаются с
/// `> ` — знак снимается, иначе ставится у каждой. Выделение — строки целиком.
MarkdownChange? quoteToggle(TextEditingValue value) {
  final selection = value.selection;
  if (!selection.isValid) return null;
  final text = value.text;
  final first = selection.start == 0
      ? 0
      : text.lastIndexOf('\n', selection.start - 1) + 1;
  // Выделение кончается сразу после `\n` (строки выбраны `Shift+↓`) —
  // следующая строка не выделена.
  final end =
      !selection.isCollapsed &&
          selection.end > first &&
          text[selection.end - 1] == '\n'
      ? selection.end - 1
      : selection.end;
  var last = text.indexOf('\n', end);
  if (last < 0) last = text.length;
  final starts = [
    first,
    for (var i = first; i < last; i++)
      if (text[i] == '\n') i + 1,
  ];
  final quoted = starts.every((s) => text.startsWith('> ', s));
  final edits = [
    for (final s in starts.reversed)
      quoted
          ? (at: s, remove: 2, insert: '')
          : (at: s, remove: 0, insert: '> '),
  ];
  final delta = (quoted ? -2 : 2) * starts.length;
  return (
    edits: edits,
    selection: TextSelection(baseOffset: first, extentOffset: last + delta),
  );
}

/// Ссылка `[текст](адрес)` в строке: где она стоит и из чего состоит.
typedef MarkdownLink = ({int start, int end, String text, String url});

/// Адрес — с одним уровнем парных скобок, как разбирает CommonMark:
/// `https://en.wikipedia.org/wiki/Foo_(bar)`.
final RegExp _link = RegExp(r'\[([^\]\n]*)\]\(((?:[^()\s]|\([^()\s]*\))*)\)');

/// Ссылка, внутри которой (или на которой целиком) стоит выделение
/// [selection]; `null` — выделение не в ссылке.
MarkdownLink? linkAt(String text, TextSelection selection) {
  for (final m in _link.allMatches(text)) {
    if (m.start <= selection.start && selection.end <= m.end) {
      return (start: m.start, end: m.end, text: m[1]!, url: m[2]!);
    }
  }
  return null;
}

/// Сделать выделение ссылкой на [url] или сменить адрес ссылки, в которой
/// оно стоит. Выделение после — текст ссылки. `null` — ссылку здесь не
/// поставить: выделение задевает другую ссылку, содержит `[`, `]` или
/// перевод строки — разметка вышла бы битой.
MarkdownChange? linkChange(TextEditingValue value, String url) {
  final selection = value.selection;
  final link = linkAt(value.text, selection);
  if (link != null) {
    final urlAt = link.start + 1 + link.text.length + 2;
    return (
      edits: [(at: urlAt, remove: link.url.length, insert: url)],
      selection: TextSelection(
        baseOffset: link.start + 1,
        extentOffset: link.start + 1 + link.text.length,
      ),
    );
  }
  final (start, end) = (selection.start, selection.end);
  final inner = value.text.substring(start, end);
  if (inner.contains(RegExp(r'[\[\]\n]')) ||
      _link.allMatches(value.text).any((m) => m.start < end && start < m.end)) {
    return null;
  }
  return (
    edits: [
      (at: end, remove: 0, insert: ']($url)'),
      (at: start, remove: 0, insert: '['),
    ],
    selection: TextSelection(baseOffset: start + 1, extentOffset: end + 1),
  );
}

/// Убрать ссылку [link], оставив её текст (help: «Link» → значок корзины).
MarkdownChange unlinkChange(MarkdownLink link) {
  final textEnd = link.start + 1 + link.text.length;
  return (
    edits: [
      (at: textEnd, remove: link.end - textEnd, insert: ''),
      (at: link.start, remove: 1, insert: ''),
    ],
    selection: TextSelection(
      baseOffset: link.start,
      extentOffset: link.start + link.text.length,
    ),
  );
}
