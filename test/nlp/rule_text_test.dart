import 'package:flutter_test/flutter_test.dart';
import 'package:planner/domain/models.dart';
import 'package:planner/nlp/rule_text.dart';

// Текст правила, пришедшего испорченным из папки: текст есть только у
// правила, которое принимает расчёт.
void main() {
  RecurrenceRule rule(String line) =>
      RecurrenceRule(rrule: [line], fromCompletion: false);

  // (строки правила, текст ru, текст en); `null` — текста нет.
  const cases = <(List<String>, String?, String?)>[
    (['FREQ=MONTHLY;BYMONTHDAY=2,15'], 'каждое 2, 15', 'every 2nd, 15th'),
    (['FREQ=MONTHLY;BYDAY=-1FR'], 'каждую последнюю пт', 'every last fri'),
    (['FREQ=DAILY;INTERVAL=3'], 'каждые 3 дня', 'every 3 days'),
    (
      [
        'FREQ=YEARLY;BYMONTH=1;BYMONTHDAY=14',
        'FREQ=YEARLY;BYMONTH=7;BYMONTHDAY=1',
      ],
      'каждое 14 янв, 1 июл',
      'every jan 14, jul 1',
    ),
    // Части вне допустимого — расчёт отвергает (О-67).
    (['FREQ=MONTHLY;BYMONTHDAY=40'], null, null),
    (['FREQ=MONTHLY;BYMONTHDAY=2,x'], null, null),
    (['FREQ=DAILY;INTERVAL=0'], null, null),
    (['FREQ=WEEKLY;INTERVAL=1001'], null, null),
    (['FREQ=MONTHLY;BYDAY=0FR'], null, null),
    (['FREQ=MONTHLY;BYDAY=5FR'], null, null),
    // Одна битая строка из нескольких — текста нет у всего правила.
    (
      [
        'FREQ=YEARLY;BYMONTH=1;BYMONTHDAY=14',
        'FREQ=YEARLY;BYMONTH=2;BYMONTHDAY=30',
      ],
      null,
      null,
    ),
    (<String>[], null, null),
  ];
  for (final (lines, ru, en) in cases) {
    test('правило $lines — текст ${ru ?? 'нет'}', () {
      final r = RecurrenceRule(rrule: lines, fromCompletion: false);
      expect(ruleText(r, 'ru'), ru);
      expect(ruleText(r, 'en'), en);
    });
  }

  test('окончание серии — настоящий день: текст с датой; дня нет — текста '
      'нет, без падения (решение 1А «Ход M3.8»)', () {
    expect(
      ruleText(rule('FREQ=DAILY;UNTIL=20261103'), 'ru'),
      'каждый день до 3 ноя 2026',
    );
    for (final bad in ['20271301', '20261131', '20260001']) {
      expect(ruleText(rule('FREQ=DAILY;UNTIL=$bad'), 'ru'), isNull);
      expect(ruleText(rule('FREQ=DAILY;UNTIL=$bad'), 'en'), isNull);
    }
  });
}
