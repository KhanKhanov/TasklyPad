import 'package:oplog_sync/oplog_sync.dart';

/// Тестовый узел: движок + его хранилище + управляемые часы.
final class Node {
  Node(String id, {int startMs = 1761110400000, Set<String>? silentFields})
    : store = MemoryOpStore(),
      _now = startMs {
    engine = MergeEngine(
      nodeId: id,
      store: store,
      nowMs: () => _now,
      newOpId: () => '$id-${++_seq}',
      silentFields: silentFields ?? const {},
    );
  }

  final MemoryOpStore store;
  late final MergeEngine engine;
  int _now;
  int _seq = 0;

  /// Сдвинуть часы узла вперёд.
  void advance(int ms) => _now += ms;

  Map<String, Object?>? task(String id) => store.entity('task', id);

  /// Отдать все свои ops другому узлу (имитация транспорта).
  Future<ApplyReport> pushTo(Node other) =>
      other.engine.applyAll(store.opsOf(engine.nodeId));

  /// Отдать весь свой журнал, включая чужие ops (узел как ретранслятор).
  Future<ApplyReport> pushAllTo(Node other) async =>
      other.engine.applyAll(await store.allOps());

  /// Конфликты узла, упорядоченные по id — удобно сравнивать между узлами.
  Future<List<Conflict>> conflicts() async =>
      (await store.conflicts())..sort((x, y) => x.id.compareTo(y.id));
}

Future<void> syncBoth(Node a, Node b) async {
  await a.pushTo(b);
  await b.pushTo(a);
}
