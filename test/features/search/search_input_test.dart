import 'package:flutter_test/flutter_test.dart';
import 'package:planner/domain/filter_query.dart';
import 'package:planner/features/search/logic/search_input.dart';
import 'package:planner/nlp/filter_parser.dart';

import '../../nlp/fixtures.dart';

// Строка поиска — запрос фильтра или слова (решение 5А plans/m5 «Решения
// M5.4»): строки — test/fixtures/search_input.json. `expect.kind` — `filter`,
// `words` или `empty`; `words` — слова поиска; `save` — запрос «Сохранить как
// фильтр».
void main() {
  final rows = loadRows('search_input.json');

  test('fixtures — у каждой строки есть источник', () {
    for (final row in rows) {
      expect(row['source'], isA<String>(), reason: '${row['input']}');
    }
  });

  for (final row in rows) {
    final input = row['input']! as String;
    final expected = expectOf(row);
    test('«$input» — ${expected['kind']} (${row['source']})', () {
      final now = contextOf(row, lang: 'ru').now;
      final result = classifySearch(input, now: now);
      final kind = switch (result) {
        EmptySearch() => 'empty',
        WordSearch() => 'words',
        FilterSearch() => 'filter',
      };
      expect(kind, expected['kind']);
      if (expected['words'] case final List<Object?> words) {
        expect([
          for (final w in (result as WordSearch).query.words) w.text,
        ], words);
      }
      if (expected['save'] case final String save) {
        expect(filterQueryToSave(result), save);
      }
      // «Сохранить как фильтр» слов: запрос разбирается в те же слова.
      if (result case WordSearch(:final query)) {
        final saved = parseFilterQuery(filterQueryToSave(result), now: now);
        expect(saved.parts.single.node, isA<SearchNode>());
        expect((saved.parts.single.node as SearchNode).words, [
          for (final w in query.words) w.text,
        ]);
      }
    });
  }
}
