import 'package:flutter_test/flutter_test.dart';
import 'package:planner/core/fractional_index.dart';

void main() {
  test('between(null, null) — середина алфавита', () {
    expect(between(null, null), 'V');
  });

  test('between — результат строго между соседями', () {
    final cases = <(String?, String?)>[
      (null, null),
      (null, 'V'),
      ('V', null),
      ('a', 'b'),
      ('a', 'a1'),
      ('aV', 'b'),
      ('Z', 'a'),
      ('zz', null),
      (null, '1'),
      ('0V', '1'),
    ];
    for (final (a, b) in cases) {
      final mid = between(a, b);
      expect(mid, isNotEmpty, reason: '$a,$b');
      expect(mid.endsWith('0'), isFalse, reason: '$a,$b → $mid');
      if (a != null) expect(a.compareTo(mid), lessThan(0), reason: '$a < $mid');
      if (b != null) expect(mid.compareTo(b), lessThan(0), reason: '$mid < $b');
    }
  });

  test('вставка в конец 200 раз — ключи растут медленно', () {
    String? prev;
    for (var i = 0; i < 200; i++) {
      final next = between(prev, null);
      if (prev != null) expect(prev.compareTo(next), lessThan(0));
      prev = next;
    }
    expect(prev!.length, lessThan(6));
  });

  test('вставка в начало 200 раз — порядок сохраняется', () {
    String? next;
    for (var i = 0; i < 200; i++) {
      final prev = between(null, next);
      if (next != null) expect(prev.compareTo(next), lessThan(0));
      next = prev;
    }
  });

  test('вставка между двумя соседями 100 раз подряд — порядок сохраняется', () {
    var lo = between(null, null);
    final hi = between(lo, null);
    for (var i = 0; i < 100; i++) {
      final mid = between(lo, hi);
      expect(lo.compareTo(mid), lessThan(0));
      expect(mid.compareTo(hi), lessThan(0));
      lo = mid;
    }
  });

  test('sequence — N возрастающих ключей после заданного', () {
    final keys = sequence(5, after: 'V');
    expect(keys, hasLength(5));
    for (var i = 0; i < keys.length; i++) {
      final prev = i == 0 ? 'V' : keys[i - 1];
      expect(prev.compareTo(keys[i]), lessThan(0));
    }
  });

  test('a >= b или ключ на "0" — ArgumentError', () {
    expect(() => between('b', 'a'), throwsArgumentError);
    expect(() => between('a', 'a'), throwsArgumentError);
    expect(() => between('a0', 'b'), throwsArgumentError);
  });
}
