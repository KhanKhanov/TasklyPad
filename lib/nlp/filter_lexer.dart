// Лексер запроса фильтра (TODOIST_SYNTAX §4): операторы `|`, `&`, `!`, `(`,
// `)`, `,` и условия между ними. `\` отменяет смысл следующего символа —
// оператор или пробел становится частью имени (`#One \& Two`); сам `\`
// остаётся в тексте условия, его снимает разбор имени.

/// Вид токена запроса.
enum FilterTokenType { term, and, or, not, open, close, comma }

/// Токен запроса: оператор или условие с позицией в исходном тексте.
final class FilterToken {
  const FilterToken(this.type, this.text, this.start, this.end);

  final FilterTokenType type;

  /// Текст условия без пробелов по краям (экранирование `\` — как в
  /// запросе); у оператора — сам знак.
  final String text;

  /// Участок в запросе: [start] включительно, [end] — нет.
  final int start;
  final int end;

  @override
  String toString() => 'FilterToken(${type.name}, $text, $start..$end)';
}

const Map<String, FilterTokenType> _operators = {
  '&': FilterTokenType.and,
  '|': FilterTokenType.or,
  '!': FilterTokenType.not,
  '(': FilterTokenType.open,
  ')': FilterTokenType.close,
  ',': FilterTokenType.comma,
};

/// Токены запроса [query]. Участок из одних пробелов токена не даёт.
List<FilterToken> lexFilter(String query) {
  final tokens = <FilterToken>[];
  var termStart = 0;

  void flushTerm(int end) {
    var start = termStart;
    var stop = end;
    while (start < stop && _isSpace(query, start)) {
      start++;
    }
    // Пробел в конце, перед которым `\`, — часть имени.
    while (stop > start &&
        _isSpace(query, stop - 1) &&
        !_escaped(query, stop - 1)) {
      stop--;
    }
    if (stop > start) {
      tokens.add(
        FilterToken(
          FilterTokenType.term,
          query.substring(start, stop),
          start,
          stop,
        ),
      );
    }
  }

  for (var i = 0; i < query.length; i++) {
    final char = query[i];
    if (char == r'\') {
      i++;
      continue;
    }
    final type = _operators[char];
    if (type == null) continue;
    flushTerm(i);
    tokens.add(FilterToken(type, char, i, i + 1));
    termStart = i + 1;
  }
  flushTerm(query.length);
  return tokens;
}

bool _isSpace(String text, int i) => text[i].trim().isEmpty;

/// Символ [i] стоит после `\`, который сам не экранирован.
bool _escaped(String text, int i) {
  var slashes = 0;
  for (var k = i - 1; k >= 0 && text[k] == r'\'; k--) {
    slashes++;
  }
  return slashes.isOdd;
}
