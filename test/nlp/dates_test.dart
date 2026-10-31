import 'package:flutter_test/flutter_test.dart';
import 'package:planner/nlp/quick_add.dart';

import 'fixtures.dart';

// Табличный тест дат: строки — test/fixtures/dates.json (`source` — страница
// help или «допущение О-57»). Ввод — дата целиком: в названии ничего не
// остаётся, подсвечен весь ввод; `"mode": "field"` — строка поля срока.

void main() {
  final rows = loadRows('dates.json');

  test('fixtures — у каждой строки есть источник', () {
    for (final row in rows) {
      expect(row['source'], isA<String>(), reason: nameOf(row));
    }
  });

  for (final row in rows) {
    test('${nameOf(row)} — ${row['source']}', () {
      final input = row['input']! as String;
      final ctx = contextOf(row);
      final expected = expectOf(row);
      if (row['mode'] == 'field') {
        final match = parseDueText(input, ctx);
        if (expected['none'] == true) {
          expect(match, isNull);
          return;
        }
        expect(match?.due?.date, expected['date']);
        expect(match?.due?.time, expected['time']);
        return;
      }

      final result = parseQuickAdd(input, ctx);
      if (expected['none'] == true) {
        expect((result.due, result.noDate, result.title), (null, false, input));
        return;
      }
      expect(result.title, '', reason: 'дата целиком убрана из названия');
      expect(result.highlights.map((h) => (h.start, h.end, h.kind)), [
        (0, input.length, HighlightKind.due),
      ]);
      if (expected['no_date'] == true) {
        expect((result.due, result.noDate), (null, true));
        return;
      }
      final due = result.due;
      expect(due, isNotNull);
      expect(
        (due!.date, due.time, due.rule, due.string, due.lang),
        (expected['date'], expected['time'], null, input, row['lang']),
      );
    });
  }
}
