import 'package:oplog_sync/oplog_sync.dart';
import 'package:test/test.dart';

import 'support/test_node.dart';

void main() {
  late Node a;
  late Node b;

  setUp(() {
    a = Node('a');
    b = Node('b');
  });

  /// Задача t1 создана на a и доставлена на b; часы обоих сдвинуты по-разному,
  /// чтобы следующие правки были «параллельными» и упорядоченными: a раньше b.
  Future<void> sharedTask() async {
    await a.engine.mutate('task', 't1', {'title': 'v0', 'priority': 4});
    await syncBoth(a, b);
    a.advance(1000);
    b.advance(2000);
  }

  group('base', () {
    test('mutate — свои ops в base не учитываются', () async {
      final created = await a.engine.mutate('task', 't1', {'title': 'v0'});
      a.advance(10);
      final edited = await a.engine.mutate('task', 't1', {'title': 'v1'});
      expect(created.single.base, isNull);
      expect(edited.single.base, isNull);
    });

    test(
      'mutate — base = макс. HLC чужих ops сущности, общий на все поля',
      () async {
        await sharedTask();
        final fromB = await b.engine.mutate('task', 't1', {'priority': 1});
        await b.pushTo(a);
        final ops = await a.engine.mutate('task', 't1', {
          'title': 'от a',
          'priority': 2,
        });
        expect(ops.map((o) => o.base).toSet(), {fromB.single.hlc});
      },
    );

    test('tombstone — base = максимальный HLC правок с других узлов', () async {
      await sharedTask();
      final edit = await b.engine.mutate('task', 't1', {'title': 'от b'});
      await b.pushTo(a);
      final tombstone = await a.engine.delete('task', 't1');
      expect(tombstone.single.base, edit.single.hlc);
    });

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
      expect(
        () => Op.fromJson(op.toJson()..['base'] = 5),
        throwsFormatException,
      );
    });
  });

  group('детекция', () {
    test(
      'параллельная правка одного поля — один конфликт с одним id на обоих',
      () async {
        await sharedTask();
        await a.engine.mutate('task', 't1', {'title': 'от a'});
        await b.engine.mutate('task', 't1', {'title': 'от b'});
        final toB = await a.pushTo(b);
        await b.pushTo(a);

        final onA = await a.conflicts();
        expect(onA, hasLength(1));
        expect(await b.conflicts(), onA);
        expect(toB.conflicts, onA);
        final c = onA.single;
        expect(c.kind, ConflictKind.edit);
        expect(c.field, 'title');
        expect(c.olderOpId, 'a-3'); // a-1, a-2 — создание (title, priority)
        expect(c.newerOpId, 'b-1');
        expect(c.resolved, isFalse);
        // LWW действует до выбора пользователя.
        expect(a.task('t1')!['title'], 'от b');
        expect(b.task('t1')!['title'], 'от b');
      },
    );

    test(
      'последовательная правка (b видел правку a) — конфликта нет',
      () async {
        await sharedTask();
        await a.engine.mutate('task', 't1', {'title': 'от a'});
        await a.pushTo(b);
        await b.engine.mutate('task', 't1', {'title': 'от b'});
        await syncBoth(a, b);
        expect(await a.conflicts(), isEmpty);
        expect(await b.conflicts(), isEmpty);
      },
    );

    test('параллельная правка одинаковым значением — конфликта нет', () async {
      await sharedTask();
      await a.engine.mutate('task', 't1', {'title': 'одно и то же'});
      await b.engine.mutate('task', 't1', {'title': 'одно и то же'});
      await syncBoth(a, b);
      expect(await a.conflicts(), isEmpty);
      expect(await b.conflicts(), isEmpty);
    });

    test('параллельная правка разных полей — конфликта нет', () async {
      await sharedTask();
      await a.engine.mutate('task', 't1', {'title': 'от a'});
      await b.engine.mutate('task', 't1', {'priority': 1});
      await syncBoth(a, b);
      expect(await a.conflicts(), isEmpty);
      expect(await b.conflicts(), isEmpty);
    });

    test('поле из silentFields — конфликта нет, LWW работает', () async {
      a = Node('a', silentFields: {'order_key'});
      b = Node('b', silentFields: {'order_key'});
      await sharedTask();
      await a.engine.mutate('task', 't1', {'order_key': 'a0'});
      await b.engine.mutate('task', 't1', {'order_key': 'b0'});
      await syncBoth(a, b);
      expect(await a.conflicts(), isEmpty);
      expect(a.task('t1')!['order_key'], 'b0');
    });

    test(
      'правка vs удаление — конфликт вида delete с одним id на обоих',
      () async {
        await sharedTask();
        await a.engine.delete('task', 't1');
        await b.engine.mutate('task', 't1', {'title': 'правка'});
        await syncBoth(a, b);

        final onA = await a.conflicts();
        expect(onA, hasLength(1));
        expect(await b.conflicts(), onA);
        expect(onA.single.kind, ConflictKind.delete);
        expect(onA.single.field, 'title');
      },
    );

    test('удаление после того, как увидел правку, — конфликта нет', () async {
      await sharedTask();
      await b.engine.mutate('task', 't1', {'title': 'правка'});
      await b.pushTo(a);
      await a.engine.delete('task', 't1');
      await syncBoth(a, b);
      expect(await a.conflicts(), isEmpty);
      expect(await b.conflicts(), isEmpty);
    });

    test(
      'воскрешение после увиденного удаления и правка — конфликта нет',
      () async {
        await sharedTask();
        await a.engine.delete('task', 't1');
        await a.pushTo(b);
        await b.engine.mutate('task', 't1', {
          Op.deletedField: false,
          'title': 'вернул',
        });
        await syncBoth(a, b);
        expect(await a.conflicts(), isEmpty);
        expect(await b.conflicts(), isEmpty);
        expect(a.store.alive('task').keys, ['t1']);
      },
    );

    test(
      'порядок доставки не важен — одинаковые конфликты на всех узлах',
      () async {
        final c = Node('c');
        final d = Node('d');
        await a.engine.mutate('task', 't1', {'title': 'v0'});
        await a.pushTo(b); // b правит задачу, которую уже получил
        a.advance(1000);
        b.advance(2000);
        await a.engine.mutate('task', 't1', {'title': 'от a'});
        await b.engine.mutate('task', 't1', {'title': 'от b'});

        final opsA = a.store.opsOf('a');
        final opsB = b.store.opsOf('b');
        await c.engine.applyAll([...opsA, ...opsB]);
        await d.engine.applyAll([...opsB.reversed, ...opsA.reversed]);

        final onC = await c.conflicts();
        expect(onC, hasLength(1));
        expect(await d.conflicts(), onC);
      },
    );

    test('повторная доставка — конфликт не дублируется', () async {
      await sharedTask();
      await a.engine.mutate('task', 't1', {'title': 'от a'});
      await b.engine.mutate('task', 't1', {'title': 'от b'});
      await syncBoth(a, b);
      final again = await a.pushTo(b);
      expect(again.conflicts, isEmpty);
      expect(await b.conflicts(), hasLength(1));
    });

    test(
      'отмена удаления → синхронизация → чужая правка — конфликта нет',
      () async {
        await sharedTask();
        await a.engine.delete('task', 't1');
        a.advance(100);
        await a.engine.mutate('task', 't1', {Op.deletedField: false});
        await syncBoth(a, b);
        await b.engine.mutate('task', 't1', {'title': 'после синка'});
        final report = await b.pushTo(a);
        expect(report.conflicts, isEmpty);
        expect(await a.conflicts(), isEmpty);
        expect(await b.conflicts(), isEmpty);
      },
    );

    for (final restoreFirst in [true, false]) {
      test('воскрешение и правка одной группой (restore '
          '${restoreFirst ? 'первым' : 'вторым'}) — конфликта нет, '
          'инкрементально == rebuild', () async {
        await sharedTask();
        await a.engine.delete('task', 't1');
        await a.pushTo(b);
        final fields = restoreFirst
            ? {Op.deletedField: false, 'title': 'вернул'}
            : {'title': 'вернул', Op.deletedField: false};
        await b.engine.mutate('task', 't1', fields);
        await syncBoth(a, b);
        for (final node in [a, b]) {
          expect(await node.conflicts(), isEmpty);
          await node.engine.rebuild();
          expect(await node.conflicts(), isEmpty);
        }
      });
    }

    test('удаление и правка одной группой против чужой правки — '
        'два конфликта разных видов, одинаково при любом порядке', () async {
      final c = Node('c');
      final d = Node('d');
      await a.engine.mutate('task', 't1', {'title': 'v0'});
      await a.pushTo(b);
      a.advance(1000);
      b.advance(2000);
      await a.engine.mutate('task', 't1', {
        Op.deletedField: true,
        'title': 'от a',
      });
      await b.engine.mutate('task', 't1', {'title': 'от b'});

      final opsA = a.store.opsOf('a');
      final opsB = b.store.opsOf('b');
      await c.engine.applyAll([...opsA, ...opsB]);
      await d.engine.applyAll([...opsB, ...opsA.reversed]);

      final onC = await c.conflicts();
      expect(onC.map((x) => x.kind).toSet(), {
        ConflictKind.edit,
        ConflictKind.delete,
      });
      expect(onC.map((x) => x.id).toSet(), hasLength(2));
      expect(await d.conflicts(), onC);
      await d.engine.rebuild();
      expect(await d.conflicts(), onC);
    });
  });

  group('разрешение', () {
    Future<Conflict> parallelTitles() async {
      await sharedTask();
      await a.engine.mutate('task', 't1', {'title': 'от a'});
      await b.engine.mutate('task', 't1', {'title': 'от b'});
      await syncBoth(a, b);
      return (await a.conflicts()).single;
    }

    test('выбор на одном узле закрывает конфликт на другом', () async {
      final conflict = await parallelTitles();
      await a.engine.resolveConflict(conflict.id, {'title': 'от a'});
      await syncBoth(a, b);

      for (final node in [a, b]) {
        expect(node.task('t1')!['title'], 'от a');
        final list = await node.conflicts();
        expect(list, hasLength(1), reason: 'выбор не создаёт новый конфликт');
        expect(list.single.resolved, isTrue);
      }
    });

    test(
      'узел, заметивший конфликт позже, не переоткрывает разрешённый',
      () async {
        await sharedTask();
        await a.engine.mutate('task', 't1', {'title': 'от a'});
        await b.engine.mutate('task', 't1', {'title': 'от b'});
        await b.pushTo(a);
        final conflict = (await a.conflicts()).single;
        await a.engine.resolveConflict(conflict.id, {'title': 'от a'});

        b.advance(30 * 60 * 1000); // часы b далеко впереди — не должно влиять
        final report = await a.pushTo(b);
        expect(report.conflicts, isEmpty, reason: 'уведомлять не о чем');
        final onB = await b.conflicts();
        expect(onB.single.id, conflict.id);
        expect(onB.single.resolved, isTrue);
        expect(b.task('t1')!['title'], 'от a');
      },
    );

    test(
      '«оставить как есть» — пустой выбор только закрывает конфликт',
      () async {
        final conflict = await parallelTitles();
        final ops = await a.engine.resolveConflict(conflict.id, {});
        expect(ops.single.entityType, conflictEntityType);
        expect(a.task('t1')!['title'], 'от b');
        expect((await a.conflicts()).single.resolved, isTrue);
      },
    );

    test('выбор «восстановить» при удалении → синхронизация → новая правка '
        'с другого узла — новых конфликтов нет', () async {
      await sharedTask();
      await a.engine.delete('task', 't1');
      await b.engine.mutate('task', 't1', {'title': 'правка'});
      await syncBoth(a, b);
      final conflict = (await a.conflicts()).single;
      expect(conflict.kind, ConflictKind.delete);

      await a.engine.resolveConflict(conflict.id, {Op.deletedField: false});
      await syncBoth(a, b);
      await b.engine.mutate('task', 't1', {'title': 'ещё'});
      await syncBoth(a, b);

      for (final node in [a, b]) {
        final list = await node.conflicts();
        expect(list, hasLength(1));
        expect(list.single.resolved, isTrue);
        expect(node.store.alive('task').keys, ['t1']);
      }
    });

    test(
      'повторный выбор по разрешённому конфликту — ops не создаются',
      () async {
        final conflict = await parallelTitles();
        await a.engine.resolveConflict(conflict.id, {'title': 'от a'});
        expect(
          await a.engine.resolveConflict(conflict.id, {'title': 'x'}),
          isEmpty,
        );
        expect(a.task('t1')!['title'], 'от a');
      },
    );

    test('неизвестный id — ArgumentError', () async {
      expect(() => a.engine.resolveConflict('нет', {}), throwsArgumentError);
    });

    test('rebuild восстанавливает конфликты и отметку resolved', () async {
      final conflict = await parallelTitles();
      await a.engine.mutate('task', 't2', {'title': 'x'});
      await a.engine.resolveConflict(conflict.id, {'title': 'от a'});
      final before = await a.conflicts();
      await a.engine.rebuild();
      expect(await a.conflicts(), before);
      expect(a.task('t1')!['title'], 'от a');
    });
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
