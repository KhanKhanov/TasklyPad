import 'dart:math';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/core/ids.dart';

void main() {
  test('next — канонический формат UUIDv7 (версия 7, вариант RFC 4122)', () {
    final id = IdGenerator().next();
    expect(id, matches(uuidV7Pattern));
  });

  test('next — первые 48 бит равны времени из clock', () {
    final fixed = DateTime.utc(2026, 1, 15, 10, 0, 0);
    final id = withClock(Clock.fixed(fixed), () => IdGenerator().next());
    final msHex = fixed.millisecondsSinceEpoch
        .toRadixString(16)
        .padLeft(12, '0');
    expect(id.replaceAll('-', '').substring(0, 12), msHex);
  });

  test('next — внутри одной миллисекунды ID строго возрастают', () {
    final fixed = DateTime.utc(2026, 1, 15);
    final ids = withClock(Clock.fixed(fixed), () {
      final gen = IdGenerator(random: Random(1));
      return List.generate(500, (_) => gen.next());
    });
    for (var i = 1; i < ids.length; i++) {
      expect(ids[i].compareTo(ids[i - 1]), greaterThan(0), reason: 'i=$i');
    }
  });

  test('next — 10 000 ID без повторов', () {
    final gen = IdGenerator();
    final ids = {for (var i = 0; i < 10000; i++) gen.next()};
    expect(ids, hasLength(10000));
  });

  test('next — более позднее время даёт больший ID', () {
    final gen = IdGenerator(random: Random(7));
    final a = withClock(Clock.fixed(DateTime.utc(2026, 1, 15)), gen.next);
    final b = withClock(Clock.fixed(DateTime.utc(2026, 1, 16)), gen.next);
    expect(b.compareTo(a), greaterThan(0));
  });
}
