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

  group('treeDropPlace', () {
    // a
    //   b
    //     c
    // d
    const items = [
      TreeItem('a', 0, 1),
      TreeItem('b', 1, 1),
      TreeItem('c', 2, 0),
      TreeItem('d', 0, 0),
    ];
    ({String? parentId, String? afterId, int depth})? place(
      int index,
      int depth, {
      int height = 1,
      int max = 4,
    }) => treeDropPlace(
      items,
      (String s) => s,
      index: index,
      wantedDepth: depth,
      movedHeight: height,
      maxLevels: max,
    );

    final cases =
        <(String, int, int, ({String? parentId, String? afterId, int depth})?)>[
          (
            'в начало — корень',
            0,
            0,
            (parentId: null, afterId: null, depth: 0),
          ),
          (
            'глубже первой строки нельзя',
            0,
            3,
            (parentId: null, afterId: null, depth: 0),
          ),
          (
            'под a первым — следующая b держит глубину 1',
            1,
            0,
            (parentId: 'a', afterId: null, depth: 1),
          ),
          ('после c вровень', 3, 2, (parentId: 'b', afterId: 'c', depth: 2)),
          ('после c под c', 3, 3, (parentId: 'c', afterId: null, depth: 3)),
          ('после c корнем', 3, 0, (parentId: null, afterId: 'a', depth: 0)),
          ('в конец корнем', 4, 0, (parentId: null, afterId: 'd', depth: 0)),
          ('в конец под d', 4, 1, (parentId: 'd', afterId: null, depth: 1)),
        ];
    for (final (name, index, depth, want) in cases) {
      test(name, () => expect(place(index, depth), want));
    }

    test('предел уровней зажимает глубину', () {
      expect(place(3, 3, max: 3), (parentId: 'b', afterId: 'c', depth: 2));
      expect(place(3, 3, height: 2), (parentId: 'b', afterId: 'c', depth: 2));
    });

    test('места нет: следующая строка глубже предела', () {
      expect(place(2, 2, height: 3), isNull);
    });

    test('baseDepth — подзадачи в окне задачи не выходят выше', () {
      const sub = [TreeItem('x', 1, 0), TreeItem('y', 1, 0)];
      final result = treeDropPlace(
        sub,
        (String s) => s,
        index: 2,
        wantedDepth: 0,
        movedHeight: 1,
        maxLevels: 4,
        baseDepth: 1,
      );
      expect(result, (parentId: null, afterId: 'y', depth: 1));
    });
  });
}
