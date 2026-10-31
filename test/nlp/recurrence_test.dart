import 'package:flutter_test/flutter_test.dart';
import 'package:planner/domain/models.dart';
import 'package:planner/domain/recurrence.dart';
import 'package:planner/nlp/quick_add.dart';
import 'package:planner/nlp/rule_text.dart';

import 'fixtures.dart';

// Табличный тест повторений: строки — test/fixtures/recurrence.json.
// Каждое правило разбора проходит строгую проверку `nextOccurrence`
// (SYNC_DESIGN «Проекции»), а текст правила на ru и en разбирается обратно в
// то же правило («туда и обратно»).

void main() {
  final rows = loadRows('recurrence.json');

  test('fixtures — у каждой строки есть источник', () {
    for (final row in rows) {
      expect(row['source'], isA<String>(), reason: nameOf(row));
    }
  });

  for (final row in rows) {
    final expected = expectOf(row);
    final input = row['input']! as String;

    test('${nameOf(row)} — ${row['source']}', () {
      final result = parseQuickAdd(input, contextOf(row));
      if (expected['none'] == true) {
        expect((result.due, result.title), (null, input));
        return;
      }
      expect(result.title, '', reason: 'повторение целиком убрано из названия');
      final due = result.due;
      expect(due, isNotNull);
      expect(
        (due!.date, due.time, due.rule, due.string, due.lang),
        (
          expected['date'],
          expected['time'],
          RecurrenceRule(
            rrule: (expected['rrule']! as List<Object?>).cast<String>(),
            fromCompletion: expected['from_completion']! as bool,
          ),
          input,
          row['lang'],
        ),
      );
    });

    if (expected['none'] == true) continue;
    final rule = RecurrenceRule(
      rrule: (expected['rrule']! as List<Object?>).cast<String>(),
      fromCompletion: expected['from_completion']! as bool,
    );

    test('${nameOf(row)} — правило проходит nextOccurrence', () {
      final due = Due(
        date: expected['date']! as String,
        time: expected['time'] as String?,
        rule: rule,
      );
      final ctx = contextOf(row);
      expect(() => nextOccurrence(due, completedAt: ctx.now), returnsNormally);
    });

    for (final lang in ['ru', 'en']) {
      test('${nameOf(row)} — текст правила $lang туда и обратно', () {
        final text = ruleText(rule, lang);
        expect(text, isNotNull, reason: rule.rrule.join(' | '));
        final back = parseDueText(text!, contextOf(row, lang: lang));
        expect(back?.due?.rule, rule, reason: text);
      });
    }
  }

  test('текст правила: формы ru и en', () {
    const weekly = RecurrenceRule(
      rrule: ['FREQ=WEEKLY;BYDAY=MO,FR'],
      fromCompletion: false,
    );
    expect(ruleText(weekly, 'ru'), 'каждый пн, пт');
    expect(ruleText(weekly, 'en'), 'every mon, fri');
    const fromCompletion = RecurrenceRule(
      rrule: ['FREQ=DAILY;INTERVAL=3;UNTIL=20270803'],
      fromCompletion: true,
    );
    expect(ruleText(fromCompletion, 'ru'), 'каждые! 3 дня до 3 авг 2027');
    expect(ruleText(fromCompletion, 'en'), 'every! 3 days until aug 3 2027');
  });

  test('текст правила без формы текстом — null', () {
    const rule = RecurrenceRule(
      rrule: ['FREQ=MONTHLY;INTERVAL=2;BYMONTHDAY=15'],
      fromCompletion: false,
    );
    expect(ruleText(rule, 'ru'), isNull);
  });
}
