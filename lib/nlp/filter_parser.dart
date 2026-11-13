import '../domain/filter_query.dart';
import '../domain/text_fold.dart';
import 'date_grammar.dart';
import 'filter_lexer.dart';
import 'parse_context.dart';
import 'scanner.dart';

// Разбор запроса фильтра (TODOIST_SYNTAX §4) — рекурсивный спуск по токенам
// лексера: `!` связывает сильнее `&`, `&` — сильнее `|` (допущение, О-69),
// `,` — только на верхнем уровне. Ключевые слова русского и английского
// работают при любом языке интерфейса (решение 7А plans/m5): запрос
// синхронизируется текстом. Даты считаются от [now] грамматикой дат в режиме
// фильтра.

/// Разобрать запрос [query] в момент [now] — стенное время устройства в
/// UTC-обёртке (`AppClock.nowWall`). Ошибка — [FilterSyntaxError] с местом.
FilterQuery parseFilterQuery(String query, {required DateTime now}) =>
    _Parser(query, lexFilter(query), now).parse();

final class _Parser {
  _Parser(this.query, this.tokens, this.now);

  final String query;
  final List<FilterToken> tokens;
  final DateTime now;
  var _pos = 0;

  FilterToken? get _peek => _pos < tokens.length ? tokens[_pos] : null;

  bool _at(FilterTokenType type) => _peek?.type == type;

  FilterQuery parse() {
    final parts = <FilterPart>[];
    for (;;) {
      final first = _peek;
      if (first == null || first.type == FilterTokenType.comma) {
        // Пустой запрос или пустая часть: `, p1`, `p1,`, `p1,,p2`.
        final at = first?.start ?? query.length;
        throw FilterSyntaxError(
          FilterErrorKind.empty,
          at,
          first?.end ?? query.length,
        );
      }
      final node = _or();
      final last = tokens[_pos - 1];
      parts.add(
        FilterPart(query.substring(first.start, last.end).trim(), node),
      );
      final next = _peek;
      if (next == null) return FilterQuery(parts);
      if (next.type != FilterTokenType.comma) {
        throw FilterSyntaxError(
          FilterErrorKind.unexpected,
          next.start,
          next.end,
        );
      }
      _pos++;
    }
  }

  FilterNode _or() {
    var left = _and();
    while (_at(FilterTokenType.or)) {
      _pos++;
      left = OrNode(left, _and());
    }
    return left;
  }

  FilterNode _and() {
    var left = _unary();
    while (_at(FilterTokenType.and)) {
      _pos++;
      left = AndNode(left, _unary());
    }
    return left;
  }

  FilterNode _unary() {
    final token = _peek;
    if (token == null) {
      // Оператор в конце: `p1 &`, `!` — подсвечивается он.
      final dangling = _pos > 0 ? tokens[_pos - 1] : null;
      throw FilterSyntaxError(
        dangling == null ? FilterErrorKind.empty : FilterErrorKind.unexpected,
        dangling?.start ?? 0,
        dangling?.end ?? query.length,
      );
    }
    switch (token.type) {
      case FilterTokenType.not:
        _pos++;
        return NotNode(_unary());
      case FilterTokenType.open:
        _pos++;
        if (_peek == null) {
          throw FilterSyntaxError(
            FilterErrorKind.unclosed,
            token.start,
            token.end,
          );
        }
        if (_at(FilterTokenType.close)) {
          throw FilterSyntaxError(
            FilterErrorKind.empty,
            token.start,
            _peek!.end,
          );
        }
        final node = _or();
        final close = _peek;
        if (close?.type == FilterTokenType.close) {
          _pos++;
          return node;
        }
        if (close?.type == FilterTokenType.comma) {
          throw FilterSyntaxError(
            FilterErrorKind.commaInGroup,
            close!.start,
            close.end,
          );
        }
        throw FilterSyntaxError(
          FilterErrorKind.unclosed,
          token.start,
          token.end,
        );
      case FilterTokenType.term:
        _pos++;
        return _term(token);
      case FilterTokenType.and ||
          FilterTokenType.or ||
          FilterTokenType.close ||
          FilterTokenType.comma:
        throw FilterSyntaxError(
          FilterErrorKind.unexpected,
          token.start,
          token.end,
        );
    }
  }

  // --- Условия ---------------------------------------------------------------

  FilterNode _term(FilterToken token) {
    final raw = token.text;
    FilterSyntaxError error(FilterErrorKind kind) =>
        FilterSyntaxError(kind, token.start, token.end);

    // Имена: проект, раздел, метка — до разбора слов, `\` в них значим.
    for (final (prefix, build) in _namePrefixes) {
      if (!raw.startsWith(prefix)) continue;
      final name = _pattern(raw.substring(prefix.length));
      if (name == null) throw error(FilterErrorKind.unknown);
      return build(name);
    }

    final text = _words(_unescape(raw));
    if (_unsupported.hasMatch(text) || _unsupportedWords.contains(text)) {
      throw error(FilterErrorKind.unsupported);
    }
    final search = _search.firstMatch(text);
    if (search != null) {
      final colon = _unescape(raw).indexOf(':');
      final words = _unescape(raw)
          .substring(colon + 1)
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .toList();
      if (words.isEmpty) throw error(FilterErrorKind.unknown);
      return SearchNode(words);
    }
    final dated = _dated.firstMatch(text);
    if (dated != null) {
      final field = _fields[dated[1]!]!;
      final relation = switch (dated[2]) {
        'before' || 'до' => DateRelation.before,
        'after' || 'после' => DateRelation.after,
        _ => DateRelation.on,
      };
      final value = _date(dated[3]!, past: field == DateField.created);
      if (value == null) throw error(FilterErrorKind.badDate);
      return DateNode(field, relation, value);
    }
    final keyword = _keywords[text];
    if (keyword != null) return keyword;
    final days = _days.firstMatch(text);
    if (days != null) {
      final n = int.parse(days[1]!);
      if (n >= 1 && n <= 9999) return NextDaysNode(n);
    }
    // Дата без слова — задачи на этот день (help: `Jan 3`, `today`).
    final day = _date(text, past: false);
    if (day != null) return DateNode(DateField.scheduled, DateRelation.on, day);
    throw error(FilterErrorKind.unknown);
  }

  /// Дата [text] на русском или английском — вся строка, без повторения.
  FilterDate? _date(String text, {required bool past}) {
    final value = text.trim();
    if (value.isEmpty) return null;
    for (final lang in ParseContext.supportedLanguages) {
      final grammar = DateGrammar(
        scan(value),
        ParseContext(now: now, lang: lang),
        filterMode: past ? FilterDateMode.past : FilterDateMode.future,
      );
      final match = grammar.matchAt(0);
      final due = match?.due;
      if (match == null || due == null || due.isRecurring) continue;
      if (match.start != 0 || match.end != value.length) continue;
      final time = due.time;
      return FilterDate(
        due.date,
        time == null
            ? null
            : int.parse(time.substring(0, 2)) * 60 +
                  int.parse(time.substring(3, 5)),
      );
    }
    return null;
  }

  /// Имя с подстановкой `*`; `\` делает следующий символ буквальным.
  /// Пустое имя — `null`.
  static NamePattern? _pattern(String text) {
    // Пробелы после знака (`# Работа`) — не часть имени; в конце их уже
    // убрал лексер. Экранированный пробел (`#\ Работа`) остаётся.
    final raw = text.trimLeft();
    final parts = <String>[];
    final current = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      final char = raw[i];
      if (char == r'\' && i + 1 < raw.length) {
        current.write(raw[++i]);
      } else if (char == '*') {
        parts.add(current.toString());
        current.clear();
      } else {
        current.write(char);
      }
    }
    parts.add(current.toString());
    if (parts.every((p) => p.isEmpty) && parts.length == 1) return null;
    return NamePattern(parts);
  }

  static String _unescape(String raw) =>
      raw.replaceAllMapped(RegExp(r'\\(.)'), (m) => m[1]!);

  /// Свёртка регистра и «ё», пробелы — по одному.
  static String _words(String text) =>
      foldText(text).trim().replaceAll(RegExp(r'\s+'), ' ');
}

final List<(String, FilterNode Function(NamePattern))> _namePrefixes = [
  ('##', (n) => ProjectNode(n, withSubprojects: true)),
  ('#', (n) => ProjectNode(n, withSubprojects: false)),
  ('/', SectionNode.new),
  ('%', LabelNode.new),
  // `@` — до конца 2026, как в быстром добавлении (help).
  ('@', LabelNode.new),
];

final RegExp _search = RegExp(r'^(search|поиск)\s*:');

const Map<String, DateField> _fields = {
  'date': DateField.scheduled,
  'срок': DateField.scheduled,
  'due': DateField.scheduledOrDeadline,
  'к выполнению': DateField.scheduledOrDeadline,
  'deadline': DateField.deadline,
  'дедлайн': DateField.deadline,
  'created': DateField.created,
  'создано': DateField.created,
};

final RegExp _dated = RegExp(
  r'^(date|due|deadline|created|срок|к выполнению|дедлайн|создано)'
  r'(?: (before|after|до|после))? ?: ?(.*)$',
);

final RegExp _days = RegExp(
  r'^(?:next |следующие )?(\d{1,4}) (?:days?|день|дня|дней)$',
);

final RegExp _unsupported = RegExp(
  r'^(assigned to|assigned by|added by|workspace|назначено для|назначил|'
  r'добавил|рабочее пространство) ?:',
);

const Set<String> _unsupportedWords = {
  'assigned',
  'shared',
  'назначено',
  'общие',
};

final Map<String, FilterNode> _keywords = {
  for (final w in ['view all', 'all', 'показать все', 'все'])
    w: const AllNode(),
  for (final w in ['subtask', 'subtasks', 'подзадача', 'подзадачи'])
    w: const SubtaskNode(),
  for (final w in ['overdue', 'over due', 'od', 'просрочено', 'просроченные'])
    w: const OverdueNode(),
  for (final w in ['no date', 'без даты', 'без срока']) w: const NoDateNode(),
  for (final w in ['no time', 'без времени']) w: const NoTimeNode(),
  for (final w in ['recurring', 'повторяющиеся']) w: const RecurringNode(),
  for (final w in ['no deadline', 'без дедлайна']) w: const NoDeadlineNode(),
  for (final w in ['no labels', 'без меток']) w: const NoLabelsNode(),
  for (final w in ['no priority', 'без приоритета']) w: const PriorityNode(4),
  for (var p = 1; p <= 4; p++) 'p$p': PriorityNode(p),
  for (final w in ['uncompletable', 'незавершаемые'])
    w: const UncompletableNode(),
};
