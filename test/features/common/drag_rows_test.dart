import 'package:flutter_test/flutter_test.dart';
import 'package:planner/features/common/state/drag_session.dart';
import 'package:planner/features/common/ui/drag_rows.dart';

// Общий расчёт места броска в списке (О-82): строки a, b, c, d; тащат b.
void main() {
  const rows = ['a', 'b', 'c', 'd'];
  bool keeps(String id) => id != 'b';

  group('dropIndex — сколько оставшихся строк перед местом', () {
    final cases = <({int row, bool upper, int index})>[
      (row: 0, upper: true, index: 0),
      (row: 0, upper: false, index: 1),
      (row: 2, upper: true, index: 1),
      (row: 2, upper: false, index: 2),
      (row: 3, upper: false, index: 3),
    ];
    for (final c in cases) {
      test('строка ${rows[c.row]}, ${c.upper ? 'верх' : 'низ'} → '
          '${c.index}', () {
        expect(dropIndex(rows, c.row, upper: c.upper, keeps: keeps), c.index);
      });
    }
  });

  test('afterIdAt — первым или после предыдущей оставшейся', () {
    const others = ['a', 'c', 'd'];
    expect(afterIdAt(others, 0), isNull);
    expect(afterIdAt(others, 2), 'c');
    expect(afterIdAt(others, 3), 'd');
  });

  group('lineBefore — линия места', () {
    test('перед первой — над ней', () {
      expect(
        lineBefore(['a', 'c'], 0, indent: 8),
        const DropIndicator(owner: 'a', mark: DropMark.above, indent: 8),
      );
    });
    test('дальше — под предыдущей', () {
      expect(
        lineBefore(['a', 'c'], 2),
        const DropIndicator(owner: 'c', mark: DropMark.below),
      );
    });
    test('пустой список — у конца списка', () {
      expect(
        lineBefore(const [], 0, endOwner: 'end'),
        const DropIndicator(owner: 'end', mark: DropMark.above),
      );
    });
  });
}
