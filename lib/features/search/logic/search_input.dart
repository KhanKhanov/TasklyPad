import '../../../domain/filter_query.dart';
import '../../../domain/search.dart';
import '../../../nlp/filter_parser.dart';

// Что значит строка поиска (решение 5А plans/m5 «Решения M5.4»): язык
// фильтров разбирает её без ошибки — это запрос фильтра (help: в строке
// поиска работают `p3`, `tomorrow`, `14 days`; `%метка` «runs the search as
// a filter»), иначе — слова. Здесь, а не в domain: domain не знает nlp.

/// Разобранная строка поиска.
sealed class SearchInput {
  const SearchInput();
}

/// Пустая строка — экран до ввода.
final class EmptySearch extends SearchInput {
  const EmptySearch();
}

/// Поиск словами.
final class WordSearch extends SearchInput {
  const WordSearch(this.query);
  final SearchQuery query;
}

/// Строка — запрос фильтра; [text] — как введён, без пробелов по краям.
final class FilterSearch extends SearchInput {
  const FilterSearch(this.query, this.text);
  final FilterQuery query;
  final String text;
}

/// Разобрать строку поиска [text] в момент [now] — стенное время устройства
/// в UTC-обёртке (`AppClock.nowWall`).
SearchInput classifySearch(String text, {required DateTime now}) {
  final trimmed = text.trim();
  final words = SearchQuery.parse(trimmed);
  if (words.isEmpty) return const EmptySearch();
  try {
    return FilterSearch(parseFilterQuery(trimmed, now: now), trimmed);
  } on FilterSyntaxError {
    return WordSearch(words);
  }
}

/// Запрос фильтра для «Сохранить как фильтр»: запрос фильтра — как есть,
/// слова — `search: …` (без этого слова не разберутся как фильтр); знаки
/// операторов и обратная косая черта в словах экранируются ею же
/// (TODOIST_SYNTAX §4), иначе `молоко, хлеб` стал бы двумя списками.
String filterQueryToSave(SearchInput input) => switch (input) {
  EmptySearch() => '',
  WordSearch(:final query) =>
    // `*` в слове — подстановка (help), не экранируется.
    'search: ${[for (final w in query.words) escapeFilterText(w.text)].join(' ')}',
  FilterSearch(:final text) => text,
};
