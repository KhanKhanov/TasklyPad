import 'package:flutter_test/flutter_test.dart';
import 'package:planner/domain/models.dart';
import 'package:planner/nlp/rule_text.dart';

// Текст правила для окончания, которого нет: пришло испорченным из папки.
void main() {
  RecurrenceRule rule(String line) =>
      RecurrenceRule(rrule: [line], fromCompletion: false);

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
