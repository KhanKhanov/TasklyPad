import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/core/clock.dart';

void main() {
  test('SystemClock — подчиняется withClock из package:clock', () {
    final fixed = DateTime.utc(2026, 1, 15, 12);
    final now = withClock(Clock.fixed(fixed), const SystemClock().nowUtc);
    expect(now, fixed);
    expect(now.isUtc, isTrue);
  });

  test('FixedClock — стоит, пока не сдвинуть', () {
    final c = FixedClock(DateTime.utc(2026, 1, 15));
    expect(c.nowUtc(), c.nowUtc());
    c.advance(const Duration(minutes: 5));
    expect(c.nowUtc(), DateTime.utc(2026, 1, 15, 0, 5));
    expect(c.nowMs(), DateTime.utc(2026, 1, 15, 0, 5).millisecondsSinceEpoch);
  });

  test('FixedClock — локальное время приводится к UTC', () {
    final local = DateTime(2026, 1, 15, 12);
    expect(FixedClock(local).nowUtc(), local.toUtc());
  });
}
