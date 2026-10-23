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
