import 'package:oplog_sync/oplog_sync.dart';
import 'package:test/test.dart';

// base, детекция и разрешение конфликтов поверх хранилища — в контрактных
// сценариях (lib/testing.dart, прогон в op_store_contract_test.dart).
void main() {
  test('Op JSON — base туда и обратно, отсутствие base → null', () {
    const hlc = Hlc(wallMs: 1761110400000, counter: 2, nodeId: 'a');
    const base = Hlc(wallMs: 1761110400000, counter: 1, nodeId: 'b');
    const op = Op(
      opId: 'op-1',
      nodeId: 'a',
      hlc: hlc,
      entityType: 'task',
      entityId: 't1',
      field: 'title',
      value: 'x',
      base: base,
    );
    expect(Op.fromJson(op.toJson()).base, base);
    final legacy = op.toJson()..remove('base');
    expect(Op.fromJson(legacy).base, isNull);
    expect(() => Op.fromJson(op.toJson()..['base'] = 5), throwsFormatException);
  });

  group('conflictId', () {
    const x = Hlc(wallMs: 1, counter: 0, nodeId: 'a');
    const y = Hlc(wallMs: 2, counter: 0, nodeId: 'b');

    const edit = ConflictKind.edit;

    test('не зависит от порядка аргументов', () {
      expect(
        conflictId('t1', edit, 'title', x, y),
        conflictId('t1', edit, 'title', y, x),
      );
    });

    test('формат UUID версии 8', () {
      expect(
        conflictId('t1', edit, 'title', x, y),
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-8[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
    });

    test('разные поля — разные id', () {
      expect(
        conflictId('t1', edit, 'title', x, y),
        isNot(conflictId('t1', edit, 'priority', x, y)),
      );
    });

    test('разные виды — разные id', () {
      expect(
        conflictId('t1', edit, 'title', x, y),
        isNot(conflictId('t1', ConflictKind.delete, 'title', x, y)),
      );
    });
  });

  test('jsonEquals — списки и карты сравниваются по содержимому', () {
    expect(jsonEquals(['a', 1], ['a', 1]), isTrue);
    expect(jsonEquals({'x': 1, 'y': 2}, {'y': 2, 'x': 1}), isTrue);
    expect(jsonEquals({'x': 1}, {'x': 2}), isFalse);
    expect(jsonEquals([1, 2], [2, 1]), isFalse);
  });
}
