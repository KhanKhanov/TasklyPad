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

  test('FixedClock.wallOf — момент UTC со сдвигом wallOffset, как nowWall', () {
    final c = FixedClock(
      DateTime.utc(2026, 11, 13, 12),
      wallOffset: const Duration(hours: -11),
    );
    expect(
      c.wallOf(DateTime.utc(2026, 11, 13, 10, 30)),
      DateTime.utc(2026, 11, 12, 23, 30),
    );
    expect(c.wallOf(c.nowUtc()), c.nowWall());
  });

  test('SystemClock.wallOf — цифры местного времени момента в UTC-обёртке', () {
    final at = DateTime.utc(2026, 7, 1, 21, 15);
    final local = at.toLocal();
    final wall = const SystemClock().wallOf(at);
    expect(wall.isUtc, isTrue);
    expect(
      (wall.year, wall.month, wall.day, wall.hour, wall.minute),
      (local.year, local.month, local.day, local.hour, local.minute),
    );
  });
}
