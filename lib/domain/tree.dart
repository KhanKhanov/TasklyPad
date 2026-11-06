/// Действующие родители: id → id родителя или `null` (элемент — корень).
///
/// [parentOf] — записанные родители всех живых элементов. Родитель, которого
/// нет среди ключей (удалён или ещё не пришёл с другого устройства), не
/// действует: элемент становится корнем, а не пропадает.
///
/// Параллельные переносы на двух устройствах (A: X под Y, B: Y под X) дают
/// цикл. Он разрывается одинаково на всех устройствах: корнем становится
/// элемент цикла с наименьшим id. Результат — чистая функция от [parentOf].
Map<String, String?> resolveParents(Map<String, String?> parentOf) {
  final result = <String, String?>{
    for (final MapEntry(:key, :value) in parentOf.entries)
      key: parentOf.containsKey(value) ? value : null,
  };
  // 0 — не посещён, 1 — на текущем пути, 2 — проверен.
  final state = <String, int>{};
  for (final start in result.keys) {
    if (state[start] == 2) continue;
    final path = <String>[];
    String? node = start;
    while (node != null && state[node] != 2) {
      if (state[node] == 1) {
        final cycle = path.sublist(path.indexOf(node));
        final root = cycle.reduce((a, b) => a.compareTo(b) <= 0 ? a : b);
        result[root] = null;
        break;
      }
      state[node] = 1;
      path.add(node);
      node = result[node];
    }
    for (final visited in path) {
      state[visited] = 2;
    }
  }
  return result;
}

/// Элемент дерева в порядке показа (обход в глубину): значение, глубина
/// (0 — корень) и число видимых прямых потомков.
final class TreeItem<T> {
  const TreeItem(this.value, this.depth, this.childCount);

  final T value;
  final int depth;
  final int childCount;

  @override
  String toString() => 'TreeItem($value, depth: $depth, children: $childCount)';
}

/// Куда встанет элемент, брошенный на линию перед [index] плоского дерева
/// [items] (показанные строки без самих переносимых): родитель, сосед слева и
/// глубина. [wantedDepth] — глубина, которую просит указатель; она зажимается
/// между глубиной следующей строки (её родитель не меняется) и глубиной
/// предыдущей плюс один, а сверху — пределом [maxLevels] с учётом высоты
/// переносимого поддерева [movedHeight]. [baseDepth] — глубина корней списка
/// (подзадачи в окне задачи). `null` — места нет: предел уровней.
({String? parentId, String? afterId, int depth})? treeDropPlace<T>(
  List<TreeItem<T>> items,
  String Function(T item) idOf, {
  required int index,
  required int wantedDepth,
  required int movedHeight,
  required int maxLevels,
  int baseDepth = 0,
}) {
  final previous = index > 0 ? items[index - 1] : null;
  final next = index < items.length ? items[index] : null;
  final lowest = next?.depth ?? baseDepth;
  final highest = previous == null ? baseDepth : previous.depth + 1;
  final limit = maxLevels - movedHeight;
  final top = highest < limit ? highest : limit;
  if (top < lowest) return null;
  final depth = wantedDepth < lowest
      ? lowest
      : wantedDepth > top
      ? top
      : wantedDepth;
  String? parentId;
  String? afterId;
  for (var i = index - 1; i >= 0; i--) {
    final item = items[i];
    if (item.depth == depth && afterId == null) afterId = idOf(item.value);
    if (item.depth < depth) {
      parentId = idOf(item.value);
      break;
    }
  }
  return (parentId: parentId, afterId: afterId, depth: depth);
}

/// Разложить [roots] и их потомков ([childrenOf] — уже упорядоченные дети)
/// в список для показа. Потомки элемента, для которого [collapsed] вернул
/// `true`, не выводятся, но учитываются в [TreeItem.childCount].
List<TreeItem<T>> flattenTree<T>(
  Iterable<T> roots,
  List<T> Function(T item) childrenOf, {
  bool Function(T item)? collapsed,
}) {
  final out = <TreeItem<T>>[];
  void visit(T item, int depth) {
    final children = childrenOf(item);
    out.add(TreeItem(item, depth, children.length));
    if (collapsed != null && collapsed(item)) return;
    for (final child in children) {
      visit(child, depth + 1);
    }
  }

  for (final root in roots) {
    visit(root, 0);
  }
  return out;
}
