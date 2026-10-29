import 'package:oplog_sync/oplog_sync.dart';
import 'package:test/test.dart';

// Поведение движка поверх хранилища — в контрактных сценариях
// (lib/testing.dart, прогон в op_store_contract_test.dart).
void main() {
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

  test('applyAll — действие на границе дрейфа часов, время идёт между ops → '
      'отклонено целиком', () async {
    // Часы получателя тикают на каждом вызове: при проверке по своему
    // времени для каждой op первая op действия отклонялась бы, вторая —
    // принималась, и действие разорвалось бы между проходами.
    const start = 1761110400000;
    var now = start;
    final engine = MergeEngine(
      nodeId: 'b',
      store: MemoryOpStore(),
      nowMs: () => now++,
      newOpId: () => 'x',
    );
    final hlc = Hlc(
      wallMs: start + Hlc.maxDrift.inMilliseconds + 1,
      counter: 0,
      nodeId: 'a',
    );
    Op op(String id, String field, Object? value) => Op(
      opId: id,
      nodeId: 'a',
      hlc: hlc,
      entityType: 'task',
      entityId: 't1',
      field: field,
      value: value,
    );
    final report = await engine.applyAll([
      op('a-1', 'label', 'x'),
      op('a-2', Op.deletedField, true),
    ]);
    expect(report.rejected, 2);
    expect(await engine.store.allOps(), isEmpty);
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
