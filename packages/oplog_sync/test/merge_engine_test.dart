import 'package:oplog_sync/oplog_sync.dart';
import 'package:test/test.dart';

/// Тестовый узел: движок + его хранилище + управляемые часы.
final class Node {
  Node(String id, {int startMs = 1761110400000})
    : store = MemoryOpStore(),
      _now = startMs {
    engine = MergeEngine(
      nodeId: id,
      store: store,
      nowMs: () => _now,
      newOpId: () => '$id-${++_seq}',
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
}

Future<void> syncBoth(Node a, Node b) async {
  await a.pushTo(b);
  await b.pushTo(a);
}

void main() {
  late Node a;
  late Node b;

  setUp(() {
    a = Node('a');
    b = Node('b');
  });

  test('mutate — создание задачи даёт op на каждое поле с одним hlc', () async {
    final ops = await a.engine.mutate('task', 't1', {
      'title': 'Купить молоко',
      'priority': 4,
    });
    expect(ops, hasLength(2));
    expect(ops.map((o) => o.hlc).toSet(), hasLength(1));
    expect(a.task('t1'), {'title': 'Купить молоко', 'priority': 4});
  });

  test('синхронизация — второй узел получает задачу целиком', () async {
    await a.engine.mutate('task', 't1', {'title': 'Отчёт', 'priority': 1});
    final report = await a.pushTo(b);
    expect(report.applied, 2);
    expect(b.task('t1'), a.task('t1'));
  });

  test('правка разных полей офлайн — сохраняются обе', () async {
    await a.engine.mutate('task', 't1', {'title': 'Отчёт', 'priority': 4});
    await syncBoth(a, b);

    a.advance(1000);
    b.advance(2000);
    await a.engine.mutate('task', 't1', {'title': 'Квартальный отчёт'});
    await b.engine.mutate('task', 't1', {'priority': 1});
    await syncBoth(a, b);

    final expected = {'title': 'Квартальный отчёт', 'priority': 1};
    expect(a.task('t1'), expected);
    expect(b.task('t1'), expected);
  });

  test('правка одного поля — побеждает более поздний HLC (LWW)', () async {
    await a.engine.mutate('task', 't1', {'title': 'v0'});
    await syncBoth(a, b);

    a.advance(1000);
    b.advance(5000); // b правит позже по часам
    await a.engine.mutate('task', 't1', {'title': 'от a'});
    await b.engine.mutate('task', 't1', {'title': 'от b'});
    await syncBoth(a, b);

    expect(a.task('t1')!['title'], 'от b');
    expect(b.task('t1')!['title'], 'от b');
  });

  test(
    'одинаковое время — ничью решает больший node_id, одинаково на обоих',
    () async {
      await a.engine.mutate('task', 't1', {'title': 'от a'});
      await b.engine.mutate('task', 't1', {'title': 'от b'});
      // Часы одинаковые → hlc равны по wall и counter, отличаются только node.
      await syncBoth(a, b);
      expect(a.task('t1')!['title'], 'от b');
      expect(b.task('t1')!['title'], 'от b');
    },
  );

  test('порядок доставки не важен — результат один', () async {
    await a.engine.mutate('task', 't1', {'title': 'v1'});
    a.advance(10);
    await a.engine.mutate('task', 't1', {'title': 'v2'});
    a.advance(10);
    await a.engine.mutate('task', 't1', {'title': 'v3'});

    final ops = a.store
        .opsOf('a')
        .reversed
        .toList(); // доставляем задом наперёд
    await b.engine.applyAll(ops);
    expect(b.task('t1')!['title'], 'v3');
  });

  test('повторная доставка — duplicate, состояние не меняется', () async {
    await a.engine.mutate('task', 't1', {'title': 'v1'});
    final first = await a.pushTo(b);
    final second = await a.pushTo(b);
    expect(first.applied, 1);
    expect(second.duplicate, 1);
    expect(second.applied, 0);
    expect(b.store.opCount, 1);
  });

  test('удаление vs правка — побеждает более позднее', () async {
    await a.engine.mutate('task', 't1', {'title': 'v0'});
    await syncBoth(a, b);

    a.advance(1000);
    b.advance(2000);
    await a.engine.delete('task', 't1');
    await b.engine.mutate('task', 't1', {'title': 'правка после удаления'});
    await syncBoth(a, b);

    // Удаление и правка — разные поля; tombstone остаётся, правка тоже.
    expect(a.task('t1')![Op.deletedField], true);
    expect(a.task('t1')!['title'], 'правка после удаления');
    expect(a.store.alive('task'), isEmpty);
    expect(b.store.alive('task'), isEmpty);
  });

  test('воскрешение — deleted=false позже tombstone', () async {
    await a.engine.mutate('task', 't1', {'title': 'v0'});
    await a.engine.delete('task', 't1');
    a.advance(100);
    await a.engine.mutate('task', 't1', {Op.deletedField: false});
    await a.pushTo(b);
    expect(b.store.alive('task').keys, ['t1']);
  });

  test('долгий офлайн — узел b догоняет сотню правок', () async {
    for (var i = 0; i < 100; i++) {
      a.advance(1);
      await a.engine.mutate('task', 't$i', {'title': 'задача $i', 'order': i});
    }
    final report = await a.pushTo(b);
    expect(report.applied, 200);
    expect(b.store.alive('task'), hasLength(100));
    expect(b.task('t99')!['order'], 99);
  });

  test('часы получателя подтягиваются: следующая правка позже чужой', () async {
    b.advance(60 * 1000); // b на минуту впереди
    await b.engine.mutate('task', 't1', {'title': 'от b'});
    await b.pushTo(a);
    await a.engine.mutate('task', 't1', {'title': 'от a после'});
    expect(a.engine.clock > b.engine.clock, isTrue);
    await a.pushTo(b);
    expect(b.task('t1')!['title'], 'от a после');
  });

  test('op из далёкого будущего — rejected, в журнал не попадает', () async {
    b.advance(2 * 60 * 60 * 1000); // часы b ушли на 2 часа вперёд
    await b.engine.mutate('task', 't1', {'title': 'из будущего'});
    final report = await b.pushTo(a);
    expect(report.rejected, 1);
    expect(a.store.opCount, 0);
    expect(a.task('t1'), isNull);
  });

  test('stale op — в журнале есть, проекцию не меняет', () async {
    await a.engine.mutate('task', 't1', {'title': 'старое'});
    a.advance(10);
    await a.engine.mutate('task', 't1', {'title': 'новое'});
    final ops = a.store.opsOf('a');
    await b.engine.apply(ops[1]);
    final result = await b.engine.apply(ops[0]);
    expect(result, ApplyResult.stale);
    expect(b.store.opCount, 2);
    expect(b.task('t1')!['title'], 'новое');
  });

  test('rebuild — проекции из журнала совпадают с инкрементальными', () async {
    await a.engine.mutate('task', 't1', {'title': 'v0', 'priority': 4});
    await a.engine.mutate('project', 'p1', {'name': 'Дом'});
    await syncBoth(a, b);
    a.advance(100);
    b.advance(200);
    await a.engine.mutate('task', 't1', {'title': 'v1'});
    await b.engine.mutate('task', 't1', {'priority': 1});
    await b.engine.delete('project', 'p1');
    await syncBoth(a, b);

    final before = {
      'task': a.store.alive('task'),
      'project': a.store.entity('project', 'p1'),
    };
    await a.engine.rebuild();
    expect(a.store.alive('task'), before['task']);
    expect(a.store.entity('project', 'p1'), before['project']);
    expect(a.store.alive('project'), isEmpty);
  });

  test('nodeId с двоеточием — ArgumentError', () {
    expect(
      () => MergeEngine(
        nodeId: 'a:b',
        store: MemoryOpStore(),
        nowMs: () => 0,
        newOpId: () => 'x',
      ),
      throwsArgumentError,
    );
  });

  test('Op — JSON туда и обратно', () {
    const hlc = Hlc(wallMs: 1761110400000, counter: 1, nodeId: 'a');
    const op = Op(
      opId: 'op-1',
      nodeId: 'a',
      hlc: hlc,
      entityType: 'task',
      entityId: 't1',
      field: 'labels',
      value: ['дом', 'срочно'],
    );
    final restored = Op.fromJson(op.toJson());
    expect(restored.opId, 'op-1');
    expect(restored.hlc, hlc);
    expect(restored.value, ['дом', 'срочно']);
    expect(() => Op.fromJson({'op_id': 'x'}), throwsFormatException);
  });
}
