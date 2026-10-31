/// Слово, число или знак строки с позицией в исходном тексте — единица, с
/// которой работает грамматика дат.
final class Token {
  const Token(this.text, this.start, this.end, {required this.glued});

  /// Нормализованный вид: нижний регистр, «ё» → «е», `’` → `'`.
  final String text;

  /// Позиция в исходной строке: [start] включительно, [end] — нет.
  final int start;
  final int end;

  /// Стоит вплотную к предыдущему токену: `every!`, `!14:00`.
  final bool glued;

  @override
  String toString() => 'Token($text, $start..$end)';
}

/// Участок строки: [start] включительно, [end] — нет.
final class Span {
  const Span(this.start, this.end);
  final int start;
  final int end;

  bool overlaps(Span other) => start < other.end && other.start < end;

  @override
  bool operator ==(Object other) =>
      other is Span && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'Span($start, $end)';
}

/// Сначала составные числа (даты, время), потом число с буквами (`27th`,
/// `7pm`, `27-е`), слово (с апострофом и дефисом: `year's`,
/// `когда-нибудь`), любой другой знак — по одному.
final RegExp _tokenPattern = RegExp(
  r'\d{4}[-/]\d{1,2}[-/]\d{1,2}'
  r'|\d{1,2}[./]\d{1,2}(?:[./]\d{2,4})?'
  r'|\d{1,2}:\d{2}'
  r'|\+?\d+(?:-?\p{L}+)?'
  r"|\p{L}+(?:['’-]\p{L}+)*"
  r'|[^\s\p{L}\d]',
  unicode: true,
);

/// Токены строки [text]. Пробелы — разделители, поэтому заменённый пробелами
/// участок (уже разобранный токен быстрого добавления) токенов не даёт, а
/// позиции остальных не сдвигаются.
List<Token> scan(String text) {
  final tokens = <Token>[];
  var previousEnd = -1;
  for (final m in _tokenPattern.allMatches(text)) {
    tokens.add(
      Token(normalize(m[0]!), m.start, m.end, glued: m.start == previousEnd),
    );
    previousEnd = m.end;
  }
  return tokens;
}

/// Нижний регистр, «ё» → «е», типографский апостроф → обычный.
String normalize(String word) =>
    word.toLowerCase().replaceAll('ё', 'е').replaceAll('’', "'");
