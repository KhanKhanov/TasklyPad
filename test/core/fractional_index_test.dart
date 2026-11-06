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

  test(
    'keysBetween — N возрастающих ключей строго между соседями, короткие',
    () {
      final cases = <(String?, String?, int)>[
        (null, null, 1),
        (null, null, 50),
        ('a', 'b', 7),
        ('a', 'a1', 30),
        (null, '1', 10),
        ('zz', null, 100),
      ];
      for (final (lo, hi, count) in cases) {
        final keys = keysBetween(lo, hi, count);
        final reason = '$lo,$hi,$count → $keys';
        expect(keys, hasLength(count), reason: reason);
        for (final (i, key) in keys.indexed) {
          expect(key.endsWith('0'), isFalse, reason: reason);
          final prev = i == 0 ? lo : keys[i - 1];
          if (prev != null) {
            expect(prev.compareTo(key), lessThan(0), reason: reason);
          }
        }
        if (hi != null) {
          expect(keys.last.compareTo(hi), lessThan(0), reason: reason);
        }
      }
      // Делением пополам: 100 ключей между соседями — не длиннее 9 символов.
      expect(
        keysBetween(
          'a',
          'b',
          100,
        ).map((k) => k.length).reduce((a, b) => a > b ? a : b),
        lessThanOrEqualTo(9),
      );
      expect(keysBetween('a', 'b', 0), isEmpty);
    },
  );

  test('a >= b или ключ на "0" — ArgumentError', () {
    expect(() => between('b', 'a'), throwsArgumentError);
    expect(() => between('a', 'a'), throwsArgumentError);
    expect(() => between('a0', 'b'), throwsArgumentError);
  });

  group('keyForInsert', () {
    test('в начало, середину и конец — строго между соседями', () {
      const keys = ['a1', 'a3'];
      expect(keyForInsert(keys, 0).compareTo('a1'), lessThan(0));
      final mid = keyForInsert(keys, 1);
      expect((mid.compareTo('a1') > 0, mid.compareTo('a3') < 0), (true, true));
      expect(keyForInsert(keys, 2).compareTo('a3'), greaterThan(0));
      expect(keyAtEnd(const []), between(null, null));
    });

    test('совпавшие ключи: после всех равных левому соседу, но до следующего '
        'большего — [a1, a1, a1V], вставка после первого', () {
      final key = keyForInsert(const ['a1', 'a1', 'a1V'], 1);
      expect(key.compareTo('a1'), greaterThan(0));
      expect(key.compareTo('a1V'), lessThan(0));
    });

    test('пустой и неверный ключи пропускаются', () {
      final key = keyForInsert(const ['', 'a1', 'b0'], 3);
      expect(key.compareTo('a1'), greaterThan(0));
      expect(keyForInsert(const ['', 'b'], 1).compareTo('b'), lessThan(0));
    });
  });

  group('rekeyInOrder', () {
    List<String> apply(List<String> keys) => [
      for (final (i, k) in rekeyInOrder(keys).indexed) k ?? keys[i],
    ];

    void expectIncreasing(List<String> keys) {
      for (var i = 1; i < keys.length; i++) {
        expect(keys[i].compareTo(keys[i - 1]), greaterThan(0), reason: '$keys');
      }
    }

    test('уже строго возрастают — ничего не меняется', () {
      expect(rekeyInOrder(const ['a', 'b', 'c']), [null, null, null]);
    });

    test('совпавшие ключи — меняется минимум, порядок строго возрастает', () {
      final result = rekeyInOrder(const ['a1', 'b', 'a1']);
      expect(result.where((k) => k != null), hasLength(1));
      expectIncreasing(apply(const ['a1', 'b', 'a1']));
      expectIncreasing(apply(const ['x', 'x', 'x', 'y']));
    });

    test('пустые и неверные ключи получают новые', () {
      expectIncreasing(apply(const ['', 'a0', 'b']));
    });
  });

  group('insertionKeys', () {
    void expectIncreasing(List<String> keys) {
      for (var i = 1; i < keys.length; i++) {
        expect(keys[i].compareTo(keys[i - 1]) > 0, isTrue, reason: '$keys');
      }
    }

    List<String> apply(
      List<String> keys,
      int index,
      ({List<String> inserted, List<String?> rekeyed}) place,
    ) => [
      for (var i = 0; i < index; i++) place.rekeyed[i] ?? keys[i],
      ...place.inserted,
      for (var i = index; i < keys.length; i++) place.rekeyed[i] ?? keys[i],
    ];

    test('обычное место — соседи не меняются', () {
      final keys = sequence(4);
      for (var index = 0; index <= keys.length; index++) {
        for (final count in [1, 2, 10]) {
          final place = insertionKeys(keys, index, count);
          expect(place.inserted, hasLength(count));
          expect(place.rekeyed.every((k) => k == null), isTrue);
          expectIncreasing(apply(keys, index, place));
        }
      }
    });

    test('равные соседи — можно встать на любое место, порядок строгий', () {
      const keys = ['V', 'V', 'V', 'X'];
      for (var index = 0; index <= keys.length; index++) {
        final place = insertionKeys(keys, index, 2);
        expectIncreasing(apply(keys, index, place));
      }
    });

    test(
      'неверные ключи (пустой, на 0) получают новый; верный хвост — нет',
      () {
        const keys = ['V', '', 'W0', 'X', 'Y'];
        final place = insertionKeys(keys, 1, 1);
        expectIncreasing(apply(keys, 1, place));
        expect(place.rekeyed[3], isNull);
        expect(place.rekeyed[4], isNull);
      },
    );

    test('пустой список', () {
      final place = insertionKeys(const [], 0, 3);
      expect(place.rekeyed, isEmpty);
      expectIncreasing(place.inserted);
    });
  });
}
