import 'package:flutter_test/flutter_test.dart';
import 'package:planner/domain/rrule_parts.dart';

void main() {
  test('rruleUntilDay — только дата без времени и только существующий день '
      '(решение 1А «Ход M3.8»)', () {
    expect(rruleUntilDay('20261103'), (year: 2026, month: 11, day: 3));
    expect(rruleUntilDay('20280229'), (year: 2028, month: 2, day: 29));
    for (final bad in [
      '20271301',
      '20261131',
      '20260229',
      '20261100',
      '20261103T235959Z',
      '2026-11-03',
    ]) {
      expect(rruleUntilDay(bad), isNull, reason: bad);
    }
  });

  test('rruleUntilDate и rruleParts', () {
    expect(rruleUntilDate(DateTime(2026, 11, 3)), '20261103');
    expect(rruleParts('FREQ=DAILY;UNTIL=20261103'), {
      'FREQ': 'DAILY',
      'UNTIL': '20261103',
    });
    expect(rruleParts('FREQ=DAILY;FREQ=WEEKLY'), isNull);
    expect(rruleParts('FREQ=DAILY;X'), isNull);
  });
}
