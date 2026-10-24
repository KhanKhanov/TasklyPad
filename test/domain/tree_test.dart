import 'package:flutter_test/flutter_test.dart';
import 'package:planner/domain/tree.dart';

void main() {
  group('resolveParents', () {
    test('родитель есть — действует', () {
      expect(resolveParents({'a': null, 'b': 'a'}), {'a': null, 'b': 'a'});
    });

    test('родителя нет (удалён или не пришёл) — элемент корневой', () {
      expect(resolveParents({'b': 'a'}), {'b': null});
    });

    test('цикл из двух — корнем становится меньший id', () {
      expect(resolveParents({'x': 'y', 'y': 'x'}), {'x': null, 'y': 'x'});
    });

    test('цикл из трёх с хвостом — разрыв у меньшего id, хвост цел', () {
      final result = resolveParents({
        'c': 'a',
        'a': 'b',
        'b': 'c',
        'tail': 'b',
      });
      expect(result, {'a': null, 'b': 'c', 'c': 'a', 'tail': 'b'});
    });

    test('родитель сам себе — корневой', () {
      expect(resolveParents({'a': 'a'}), {'a': null});
    });

    test('результат не зависит от порядка ключей', () {
      final forward = resolveParents({'x': 'y', 'y': 'z', 'z': 'x'});
      final backward = resolveParents({'z': 'x', 'y': 'z', 'x': 'y'});
      expect(forward, backward);
    });
  });

  test('flattenTree — обход в глубину, свёрнутый узел скрывает потомков, но '
      'считает их', () {
    final children = {
      'a': ['a1', 'a2'],
      'a1': ['a11'],
    };
    final items = flattenTree<String>(
      ['a', 'b'],
      (id) => children[id] ?? const [],
      collapsed: (id) => id == 'a1',
    );
    expect(
      [for (final i in items) (i.value, i.depth, i.childCount)],
      [('a', 0, 2), ('a1', 1, 1), ('a2', 1, 0), ('b', 0, 0)],
    );
  });
}
