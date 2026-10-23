/// Контрактные сценарии для реализаций [OpStore] и [SyncStateStore].
///
/// Один набор проверок для всех хранилищ: пакет прогоняет его на
/// [MemoryOpStore], приложение — на своей реализации поверх базы. Не зависит
/// от `package:test`: сценарий — обычная функция, которая при расхождении
/// бросает [ContractFailure]; тесты оборачивают каждый сценарий в `test()`.
library;

import 'dart:async';
import 'dart:convert';

import 'oplog_sync.dart';

// ---------------------------------------------------------------------------
// Проверки
// ---------------------------------------------------------------------------

/// Нарушение контракта: что проверяли, что ожидали и что получили.
final class ContractFailure implements Exception {
  ContractFailure(this.message);

  final String message;

  @override
  String toString() => 'ContractFailure: $message';
}

/// [actual] равно [expected]: списки и карты — по содержимому ([jsonEquals]),
/// остальное — через `==`.
void check(Object? actual, Object? expected, String what) {
  if (!jsonEquals(actual, expected)) {
    throw ContractFailure('$what: ожидал <$expected>, получил <$actual>');
  }
}

/// Условие [ok] выполнено.
void checkThat(bool ok, String what) {
  if (!ok) throw ContractFailure(what);
}

/// [action] бросает исключение типа [E].
Future<void> checkThrows<E extends Object>(
  Future<Object?> Function() action,
  String what,
) async {
  try {
    await action();
  } catch (e) {
    if (e is E) return;
    throw ContractFailure('$what: ожидал исключение $E, получил $e');
  }
  throw ContractFailure('$what: ожидал исключение $E, его не было');
}

// ---------------------------------------------------------------------------
// Хранилище под проверкой
// ---------------------------------------------------------------------------

/// Хранилище под проверкой и чтение его проекций.
///
/// Сценарии читают сущности через [entity] и [alive], а не через таблицы,
/// поэтому одинаково работают для памяти и для базы.
abstract interface class OpStoreProbe {
  OpStore get store;

  /// Все поля сущности (включая неизвестные приложению) или `null`.
  Future<Map<String, Object?>?> entity(String entityType, String entityId);

  /// Сущности типа, кроме помеченных удалёнными.
  Future<Map<String, Map<String, Object?>>> alive(String entityType);

  /// Внутренняя согласованность хранилища — вызывается в конце сценария.
  /// Например, для базы: типизированные таблицы совпадают с версиями полей.
  Future<void> checkConsistency();
}

/// Новое пустое хранилище для сценария.
typedef ProbeFactory = Future<OpStoreProbe> Function();

/// Новое пустое состояние транспорта для сценария.
typedef SyncStateFactory = Future<SyncStateStore> Function();

/// Именованный сценарий контракта; [run] получает фабрику хранилищ.
final class ContractScenario<F> {
  const ContractScenario(this.name, this.run);

  final String name;
  final Future<void> Function(F create) run;
}

/// [OpStoreProbe] над [MemoryOpStore].
final class MemoryProbe implements OpStoreProbe {
  MemoryProbe([MemoryOpStore? store]) : store = store ?? MemoryOpStore();

  @override
  final MemoryOpStore store;

  @override
  Future<Map<String, Object?>?> entity(String entityType, String entityId) =>
      Future.value(store.entity(entityType, entityId));

  @override
  Future<Map<String, Map<String, Object?>>> alive(String entityType) =>
      Future.value(store.alive(entityType));

  @override
  Future<void> checkConsistency() async {}
}

/// Фабрика хранилищ в памяти.
Future<OpStoreProbe> memoryProbeFactory() async => MemoryProbe();

/// Фабрика состояния транспорта в памяти.
Future<SyncStateStore> memorySyncStateFactory() async => MemorySyncStateStore();

// ---------------------------------------------------------------------------
// Узел сценария
// ---------------------------------------------------------------------------

/// Время старта часов узлов по умолчанию (22.10.2025 UTC).
const int scenarioStartMs = 1761110400000;

/// Узел сценария: движок, его хранилище и управляемые часы.
final class ScenarioNode {
  /// [opIdPrefix] — для второго «воплощения» того же узла (восстановление
  /// из резервной копии), чтобы его op_id не совпали с прежними.
  ScenarioNode(
    this.probe,
    String id, {
    int startMs = scenarioStartMs,
    Set<String> silentFields = const {},
    String? opIdPrefix,
  }) : _now = startMs {
    final prefix = opIdPrefix ?? id;
    engine = MergeEngine(
      nodeId: id,
      store: probe.store,
      nowMs: () => _now,
      newOpId: () => '$prefix-${++_seq}',
      silentFields: silentFields,
    );
  }

  final OpStoreProbe probe;
  late final MergeEngine engine;
  int _now;
  int _seq = 0;

  OpStore get store => probe.store;

  /// Сдвинуть часы узла вперёд.
  void advance(int ms) => _now += ms;

  Future<Map<String, Object?>?> task(String id) => probe.entity('task', id);

  /// Значение поля задачи (`null`, если задачи или поля нет).
  Future<Object?> taskField(String id, String field) async =>
      (await task(id))?[field];

  /// Ops узла [nodeId] из журнала этого узла, по возрастанию HLC.
  Future<List<Op>> opsOf(String nodeId) => store.opsOfNodeAfter(nodeId, null);

  Future<int> opCount() async => (await store.allOps()).length;

  /// Отдать все свои ops другому узлу (имитация транспорта).
  Future<ApplyReport> pushTo(ScenarioNode other) async =>
      other.engine.applyAll(await opsOf(engine.nodeId));

  /// Отдать весь свой журнал, включая чужие ops (узел как ретранслятор).
  Future<ApplyReport> pushAllTo(ScenarioNode other) async =>
      other.engine.applyAll(await store.allOps());

  /// Конфликты узла, упорядоченные по id — удобно сравнивать между узлами.
  Future<List<Conflict>> conflicts() async =>
      (await store.conflicts())..sort((x, y) => x.id.compareTo(y.id));
}

/// Обменяться ops в обе стороны.
Future<void> syncBoth(ScenarioNode a, ScenarioNode b) async {
  await a.pushTo(b);
  await b.pushTo(a);
}

// ---------------------------------------------------------------------------
// Сценарии OpStore
// ---------------------------------------------------------------------------

/// Все сценарии контракта [OpStore]: уровень хранилища и движок поверх него.
final List<ContractScenario<ProbeFactory>> opStoreScenarios = [
  ..._storeScenarios,
  ..._engineScenarios,
  ..._baseScenarios,
  ..._detectionScenarios,
  ..._resolutionScenarios,
];

/// Создаёт хранилища сценария и в конце проверяет их согласованность.
final class _Run {
  _Run(this._create);

  final ProbeFactory _create;
  final List<OpStoreProbe> _probes = [];

  Future<OpStoreProbe> probe() async {
    final p = await _create();
    _probes.add(p);
    return p;
  }

  Future<ScenarioNode> node(
    String id, {
    Set<String> silentFields = const {},
  }) async => ScenarioNode(await probe(), id, silentFields: silentFields);

  Future<(ScenarioNode, ScenarioNode)> ab({
    Set<String> silentFields = const {},
  }) async => (
    await node('a', silentFields: silentFields),
    await node('b', silentFields: silentFields),
  );

  Future<void> finish() async {
    for (final p in _probes) {
      await p.checkConsistency();
    }
  }
}

ContractScenario<ProbeFactory> _scenario(
  String name,
  Future<void> Function(_Run run) body,
) => ContractScenario(name, (create) async {
  final run = _Run(create);
  await body(run);
  await run.finish();
});

Hlc _hlc(int wall, {int counter = 0, String node = 'a'}) =>
    Hlc(wallMs: scenarioStartMs + wall, counter: counter, nodeId: node);

Op _op(
  String id, {
  String node = 'a',
  int wall = 0,
  String type = 'task',
  String entity = 't1',
  String field = 'title',
  Object? value = 'x',
  Hlc? base,
}) => Op(
  opId: id,
  nodeId: node,
  hlc: _hlc(wall, node: node),
  entityType: type,
  entityId: entity,
  field: field,
  value: value,
  base: base,
);

Conflict _conflict(String id, {bool resolved = false}) => Conflict(
  id: id,
  kind: ConflictKind.edit,
  entityType: 'task',
  entityId: 't1',
  field: 'title',
  olderOpId: 'a-1',
  newerOpId: 'b-1',
  resolved: resolved,
);

/// Не-JSON значение: хранилище обязано отказаться его сохранять.
final Object _notJson = DateTime.utc(2026);

final class _Planned implements Exception {}

final List<ContractScenario<ProbeFactory>> _storeScenarios = [
  _scenario('хранилище: containsOp — false до appendOp, true после', (
    run,
  ) async {
    final store = (await run.probe()).store;
    checkThat(!await store.containsOp('op-1'), 'пустой журнал без op-1');
    await store.appendOp(_op('op-1'));
    checkThat(await store.containsOp('op-1'), 'op-1 в журнале');
  }),

  _scenario('хранилище: повторный appendOp с тем же op_id — одна запись, '
      'первая', (run) async {
    final store = (await run.probe()).store;
    await store.appendOp(_op('op-1', value: 'первая'));
    await store.appendOp(_op('op-1', value: 'вторая'));
    final ops = await store.allOps();
    check(ops.length, 1, 'записей в журнале');
    check(ops.single.value, 'первая', 'значение');
  }),

  _scenario('хранилище: op и значение поля сохраняются без искажений', (
    run,
  ) async {
    final probe = await run.probe();
    final store = probe.store;
    final values = <Object?>[
      null,
      true,
      false,
      0,
      -42,
      1.5,
      'юникод: «ёлка» 🙂 \u0000 "кавычки"',
      <Object?>[1, 'a', null, <Object?>[]],
      <String, Object?>{
        'вложено': <String, Object?>{
          'n': <Object?>[1, 2],
          'пусто': null,
        },
      },
    ];
    for (var i = 0; i < values.length; i++) {
      final op = _op(
        'op-$i',
        wall: i,
        entity: 't$i',
        field: 'поле $i',
        value: values[i],
        base: i.isEven ? null : _hlc(i, counter: 7, node: 'узел-б'),
      );
      await store.appendOp(op);
      await store.writeField(op);
    }
    final byId = {for (final op in await store.allOps()) op.opId: op};
    for (var i = 0; i < values.length; i++) {
      final op = byId['op-$i']!;
      check(op.nodeId, 'a', 'op-$i node_id');
      check(op.hlc, _hlc(i), 'op-$i hlc');
      check(op.entityType, 'task', 'op-$i entity_type');
      check(op.entityId, 't$i', 'op-$i entity_id');
      check(op.field, 'поле $i', 'op-$i field');
      check(op.value, values[i], 'op-$i value');
      check(
        op.base,
        i.isEven ? null : _hlc(i, counter: 7, node: 'узел-б'),
        'op-$i base',
      );
      check(await probe.entity('task', 't$i'), {
        'поле $i': values[i],
      }, 'проекция t$i');
      check(await store.fieldHlc('task', 't$i', 'поле $i'), _hlc(i), 'hlc t$i');
    }
  }),

  _scenario('хранилище: не-JSON значение — ошибка, ничего не записано', (
    run,
  ) async {
    final probe = await run.probe();
    final store = probe.store;
    final op = _op('op-1', value: _notJson);
    await checkThrows<JsonUnsupportedObjectError>(
      () => store.appendOp(op),
      'appendOp',
    );
    await checkThrows<JsonUnsupportedObjectError>(
      () => store.writeField(op),
      'writeField',
    );
    checkThat(!await store.containsOp('op-1'), 'op-1 не в журнале');
    check(await probe.entity('task', 't1'), null, 'проекция');
  }),

  _scenario('хранилище: writeField не сравнивает HLC — побеждает последняя '
      'запись', (run) async {
    final probe = await run.probe();
    await probe.store.writeField(_op('op-2', wall: 2, value: 'новее'));
    await probe.store.writeField(_op('op-1', wall: 1, value: 'старее'));
    check(
      await probe.store.fieldHlc('task', 't1', 'title'),
      _hlc(1),
      'hlc поля',
    );
    check(await probe.entity('task', 't1'), {'title': 'старее'}, 'проекция');
  }),

  _scenario('хранилище: writeField не пишет в журнал, appendOp не меняет '
      'проекцию', (run) async {
    final probe = await run.probe();
    final store = probe.store;
    await store.writeField(_op('op-1'));
    check((await store.allOps()).length, 0, 'журнал после writeField');
    await store.appendOp(_op('op-2', entity: 't2'));
    check(await probe.entity('task', 't2'), null, 'проекция после appendOp');
    check(await store.fieldHlc('task', 't2', 'title'), null, 'hlc t2');
  }),

  _scenario('хранилище: opsForEntity — одинаковый id у разных типов не '
      'смешивается', (run) async {
    final store = (await run.probe()).store;
    await store.appendOp(_op('op-1', type: 'task', entity: 'x'));
    await store.appendOp(_op('op-2', type: 'project', entity: 'x'));
    await store.appendOp(_op('op-3', type: 'task', entity: 'y'));
    final ops = await store.opsForEntity('task', 'x');
    check(ops.map((o) => o.opId).toList(), ['op-1'], 'ops task/x');
  }),

  _scenario('хранилище: opsOfNodeAfter — только узел, строго после, по '
      'возрастанию HLC', (run) async {
    final store = (await run.probe()).store;
    for (final wall in [5, 1, 4, 2, 3]) {
      await store.appendOp(_op('a-$wall', wall: wall));
      await store.appendOp(_op('b-$wall', node: 'b', wall: wall));
    }
    final all = await store.opsOfNodeAfter('a', null);
    check(all.map((o) => o.opId).toList(), [
      'a-1',
      'a-2',
      'a-3',
      'a-4',
      'a-5',
    ], 'все ops узла a');
    final after = await store.opsOfNodeAfter('a', _hlc(2));
    check(after.map((o) => o.opId).toList(), [
      'a-3',
      'a-4',
      'a-5',
    ], 'ops узла a после hlc 2');
    check(await store.opsOfNodeAfter('c', null), <Op>[], 'неизвестный узел');
  }),

  _scenario('хранилище: putConflict — новая true, повторная false, resolved '
      'из аргумента не пишется', (run) async {
    final store = (await run.probe()).store;
    checkThat(
      await store.putConflict(_conflict('c1', resolved: true)),
      'первая запись — новая',
    );
    checkThat(
      !await store.putConflict(_conflict('c1')),
      'повторная — не новая',
    );
    check(await store.conflicts(), [_conflict('c1')], 'конфликты');
  }),

  _scenario('хранилище: resolved берётся из op, даже записанной до '
      'putConflict', (run) async {
    final store = (await run.probe()).store;
    await store.writeField(
      _op(
        'r-1',
        type: conflictEntityType,
        entity: 'c1',
        field: conflictResolvedField,
        value: true,
      ),
    );
    await store.putConflict(_conflict('c1'));
    await store.putConflict(_conflict('c2'));
    final byId = {for (final c in await store.conflicts()) c.id: c};
    check(byId['c1']?.resolved, true, 'c1 разрешён');
    check(byId['c2']?.resolved, false, 'c2 открыт');
  }),

  _scenario('хранилище: clearProjections — проекции, версии полей и '
      'конфликты очищены, журнал цел', (run) async {
    final probe = await run.probe();
    final store = probe.store;
    final op = _op('op-1');
    await store.appendOp(op);
    await store.writeField(op);
    await store.putConflict(_conflict('c1'));
    await store.clearProjections();
    check(await probe.entity('task', 't1'), null, 'проекция');
    check(await store.fieldHlc('task', 't1', 'title'), null, 'hlc поля');
    check(await store.conflicts(), <Conflict>[], 'конфликты');
    checkThat(await store.containsOp('op-1'), 'op-1 в журнале');
  }),

  _scenario('хранилище: transaction — возвращает результат action', (
    run,
  ) async {
    final store = (await run.probe()).store;
    check(await store.transaction(() async => 42), 42, 'результат');
  }),

  _scenario('хранилище: transaction — исключение откатывает журнал, '
      'проекцию и конфликты', (run) async {
    final probe = await run.probe();
    final store = probe.store;
    await checkThrows<_Planned>(
      () => store.transaction(() async {
        final op = _op('op-1');
        await store.appendOp(op);
        await store.writeField(op);
        await store.putConflict(_conflict('c1'));
        throw _Planned();
      }),
      'исключение пробрасывается',
    );
    checkThat(!await store.containsOp('op-1'), 'op-1 откачена');
    check(await probe.entity('task', 't1'), null, 'проекция');
    check(await store.fieldHlc('task', 't1', 'title'), null, 'hlc поля');
    check(await store.conflicts(), <Conflict>[], 'конфликты');
  }),

  _scenario('хранилище: вложенная transaction — пойманное снаружи '
      'исключение откатывает только её', (run) async {
    final probe = await run.probe();
    final store = probe.store;
    await store.transaction(() async {
      await store.appendOp(_op('outer'));
      try {
        await store.transaction(() async {
          await store.appendOp(_op('inner', entity: 't2'));
          throw _Planned();
        });
      } on _Planned {
        // Внешняя транзакция продолжается.
      }
      await store.appendOp(_op('after', entity: 't3'));
    });
    checkThat(await store.containsOp('outer'), 'outer сохранена');
    checkThat(!await store.containsOp('inner'), 'inner откачена');
    checkThat(await store.containsOp('after'), 'after сохранена');
  }),

  _scenario('хранилище: вложенная transaction — непойманное исключение '
      'откатывает всё', (run) async {
    final store = (await run.probe()).store;
    await checkThrows<_Planned>(
      () => store.transaction(() async {
        await store.appendOp(_op('outer'));
        await store.transaction(() async {
          await store.appendOp(_op('inner', entity: 't2'));
          throw _Planned();
        });
      }),
      'исключение пробрасывается',
    );
    checkThat(!await store.containsOp('outer'), 'outer откачена');
    checkThat(!await store.containsOp('inner'), 'inner откачена');
  }),

  _scenario('хранилище: параллельные транзакции — откат одной не стирает '
      'другую', (run) async {
    final store = (await run.probe()).store;
    final failing = store.transaction(() async {
      await store.appendOp(_op('first'));
      await Future<void>.delayed(Duration.zero);
      throw _Planned();
    });
    final succeeding = store.transaction(() async {
      await store.appendOp(_op('second', entity: 't2'));
    });
    await checkThrows<_Planned>(() => failing, 'первая падает');
    await succeeding;
    checkThat(!await store.containsOp('first'), 'first откачена');
    checkThat(await store.containsOp('second'), 'second сохранена');
  }),

  _scenario('хранилище: неизвестные тип и поле — сохраняются и читаются', (
    run,
  ) async {
    final probe = await run.probe();
    final op = _op(
      'op-1',
      type: 'gadget',
      entity: 'g1',
      field: 'поле_из_будущего',
      value: <String, Object?>{'k': 1},
    );
    await probe.store.appendOp(op);
    await probe.store.writeField(op);
    check(await probe.entity('gadget', 'g1'), {
      'поле_из_будущего': {'k': 1},
    }, 'сущность');
    check(await probe.alive('gadget'), {
      'g1': {
        'поле_из_будущего': {'k': 1},
      },
    }, 'alive');
  }),

  _scenario('хранилище: tombstone — сущности нет в alive, но есть в entity', (
    run,
  ) async {
    final probe = await run.probe();
    await probe.store.writeField(_op('op-1'));
    await probe.store.writeField(
      _op('op-2', entity: 't2', field: Op.deletedField, value: true),
    );
    await probe.store.writeField(
      _op('op-3', entity: 't2', wall: 1, value: 'удалённая'),
    );
    check((await probe.alive('task')).keys.toList(), ['t1'], 'alive');
    check(await probe.entity('task', 't2'), {
      Op.deletedField: true,
      'title': 'удалённая',
    }, 'удалённая сущность');
  }),

  _scenario('движок: applyAll с ошибкой посреди пакета — не применено '
      'ничего', (run) async {
    final b = await run.node('b');
    final ok = _op('a-1', entity: 't1');
    final broken = _op('a-2', entity: 't2', value: _notJson);
    await checkThrows<JsonUnsupportedObjectError>(
      () => b.engine.applyAll([ok, broken]),
      'applyAll',
    );
    check(await b.opCount(), 0, 'журнал');
    check(await b.task('t1'), null, 't1');
  }),
];

final List<ContractScenario<ProbeFactory>> _engineScenarios = [
  _scenario('движок: mutate — создание задачи даёт op на каждое поле с одним '
      'hlc', (run) async {
    final a = await run.node('a');
    final ops = await a.engine.mutate('task', 't1', {
      'title': 'Купить молоко',
      'priority': 4,
    });
    check(ops.length, 2, 'число ops');
    check(ops.map((o) => o.hlc).toSet().length, 1, 'разных hlc');
    check(await a.task('t1'), {
      'title': 'Купить молоко',
      'priority': 4,
    }, 'задача');
  }),

  _scenario('движок: синхронизация — второй узел получает задачу целиком', (
    run,
  ) async {
    final (a, b) = await run.ab();
    await a.engine.mutate('task', 't1', {'title': 'Отчёт', 'priority': 1});
    final report = await a.pushTo(b);
    check(report.applied, 2, 'применено');
    check(await b.task('t1'), await a.task('t1'), 'задача на b');
  }),

  _scenario('движок: правка разных полей офлайн — сохраняются обе', (
    run,
  ) async {
    final (a, b) = await run.ab();
    await a.engine.mutate('task', 't1', {'title': 'Отчёт', 'priority': 4});
    await syncBoth(a, b);

    a.advance(1000);
    b.advance(2000);
    await a.engine.mutate('task', 't1', {'title': 'Квартальный отчёт'});
    await b.engine.mutate('task', 't1', {'priority': 1});
    await syncBoth(a, b);

    final expected = {'title': 'Квартальный отчёт', 'priority': 1};
    check(await a.task('t1'), expected, 'задача на a');
    check(await b.task('t1'), expected, 'задача на b');
  }),

  _scenario('движок: правка одного поля — побеждает более поздний HLC (LWW)', (
    run,
  ) async {
    final (a, b) = await run.ab();
    await a.engine.mutate('task', 't1', {'title': 'v0'});
    await syncBoth(a, b);

    a.advance(1000);
    b.advance(5000); // b правит позже по часам
    await a.engine.mutate('task', 't1', {'title': 'от a'});
    await b.engine.mutate('task', 't1', {'title': 'от b'});
    await syncBoth(a, b);

    check(await a.taskField('t1', 'title'), 'от b', 'title на a');
    check(await b.taskField('t1', 'title'), 'от b', 'title на b');
  }),

  _scenario('движок: одинаковое время — ничью решает больший node_id, '
      'одинаково на обоих', (run) async {
    final (a, b) = await run.ab();
    await a.engine.mutate('task', 't1', {'title': 'от a'});
    await b.engine.mutate('task', 't1', {'title': 'от b'});
    // Часы одинаковые → hlc равны по wall и counter, отличаются только node.
    await syncBoth(a, b);
    check(await a.taskField('t1', 'title'), 'от b', 'title на a');
    check(await b.taskField('t1', 'title'), 'от b', 'title на b');
  }),

  _scenario('движок: порядок доставки не важен — результат один', (run) async {
    final (a, b) = await run.ab();
    await a.engine.mutate('task', 't1', {'title': 'v1'});
    a.advance(10);
    await a.engine.mutate('task', 't1', {'title': 'v2'});
    a.advance(10);
    await a.engine.mutate('task', 't1', {'title': 'v3'});

    // Доставляем задом наперёд.
    await b.engine.applyAll((await a.opsOf('a')).reversed);
    check(await b.taskField('t1', 'title'), 'v3', 'title на b');
  }),

  _scenario('движок: повторная доставка — duplicate, состояние не меняется', (
    run,
  ) async {
    final (a, b) = await run.ab();
    await a.engine.mutate('task', 't1', {'title': 'v1'});
    final first = await a.pushTo(b);
    final second = await a.pushTo(b);
    check(first.applied, 1, 'первая доставка: применено');
    check(second.duplicate, 1, 'вторая: дубликатов');
    check(second.applied, 0, 'вторая: применено');
    check(await b.opCount(), 1, 'журнал b');
  }),

  _scenario('движок: удаление vs правка — побеждает более позднее', (
    run,
  ) async {
    final (a, b) = await run.ab();
    await a.engine.mutate('task', 't1', {'title': 'v0'});
    await syncBoth(a, b);

    a.advance(1000);
    b.advance(2000);
    await a.engine.delete('task', 't1');
    await b.engine.mutate('task', 't1', {'title': 'правка после удаления'});
    await syncBoth(a, b);

    // Удаление и правка — разные поля; tombstone остаётся, правка тоже.
    check(await a.taskField('t1', Op.deletedField), true, 'tombstone на a');
    check(
      await a.taskField('t1', 'title'),
      'правка после удаления',
      'title на a',
    );
    check(await a.probe.alive('task'), <String, Object?>{}, 'alive на a');
    check(await b.probe.alive('task'), <String, Object?>{}, 'alive на b');
  }),

  _scenario('движок: воскрешение — deleted=false позже tombstone', (run) async {
    final (a, b) = await run.ab();
    await a.engine.mutate('task', 't1', {'title': 'v0'});
    await a.engine.delete('task', 't1');
    a.advance(100);
    await a.engine.mutate('task', 't1', {Op.deletedField: false});
    await a.pushTo(b);
    check((await b.probe.alive('task')).keys.toList(), ['t1'], 'alive на b');
  }),

  _scenario('движок: долгий офлайн — узел b догоняет сотню правок', (
    run,
  ) async {
    final (a, b) = await run.ab();
    for (var i = 0; i < 100; i++) {
      a.advance(1);
      await a.engine.mutate('task', 't$i', {'title': 'задача $i', 'order': i});
    }
    final report = await a.pushTo(b);
    check(report.applied, 200, 'применено');
    check((await b.probe.alive('task')).length, 100, 'задач на b');
    check(await b.taskField('t99', 'order'), 99, 'order t99');
  }),

  _scenario('движок: часы получателя подтягиваются — следующая правка позже '
      'чужой', (run) async {
    final (a, b) = await run.ab();
    b.advance(60 * 1000); // b на минуту впереди
    await b.engine.mutate('task', 't1', {'title': 'от b'});
    await b.pushTo(a);
    await a.engine.mutate('task', 't1', {'title': 'от a после'});
    checkThat(a.engine.clock > b.engine.clock, 'часы a впереди часов b');
    await a.pushTo(b);
    check(await b.taskField('t1', 'title'), 'от a после', 'title на b');
  }),

  _scenario('движок: op из далёкого будущего — rejected, в журнал не '
      'попадает', (run) async {
    final (a, b) = await run.ab();
    b.advance(2 * 60 * 60 * 1000); // часы b ушли на 2 часа вперёд
    await b.engine.mutate('task', 't1', {'title': 'из будущего'});
    final report = await b.pushTo(a);
    check(report.rejected, 1, 'отклонено');
    check(await a.opCount(), 0, 'журнал a');
    check(await a.task('t1'), null, 'задача на a');
  }),

  _scenario('движок: stale op — в журнале есть, проекцию не меняет', (
    run,
  ) async {
    final (a, b) = await run.ab();
    await a.engine.mutate('task', 't1', {'title': 'старое'});
    a.advance(10);
    await a.engine.mutate('task', 't1', {'title': 'новое'});
    final ops = await a.opsOf('a');
    await b.engine.apply(ops[1]);
    final result = await b.engine.apply(ops[0]);
    check(result, ApplyResult.stale, 'результат');
    check(await b.opCount(), 2, 'журнал b');
    check(await b.taskField('t1', 'title'), 'новое', 'title на b');
  }),

  _scenario('движок: rebuild — проекции из журнала совпадают с '
      'инкрементальными', (run) async {
    final (a, b) = await run.ab();
    await a.engine.mutate('task', 't1', {'title': 'v0', 'priority': 4});
    await a.engine.mutate('project', 'p1', {'name': 'Дом'});
    await syncBoth(a, b);
    a.advance(100);
    b.advance(200);
    await a.engine.mutate('task', 't1', {'title': 'v1'});
    await b.engine.mutate('task', 't1', {'priority': 1});
    await b.engine.delete('project', 'p1');
    await syncBoth(a, b);

    final tasks = await a.probe.alive('task');
    final project = await a.probe.entity('project', 'p1');
    await a.engine.rebuild();
    check(await a.probe.alive('task'), tasks, 'задачи');
    check(await a.probe.entity('project', 'p1'), project, 'проект');
    check(await a.probe.alive('project'), <String, Object?>{}, 'alive проекты');
  }),
];

/// Задача t1 создана на a и доставлена на b; часы обоих сдвинуты по-разному,
/// чтобы следующие правки были «параллельными» и упорядоченными: a раньше b.
Future<void> _sharedTask(ScenarioNode a, ScenarioNode b) async {
  await a.engine.mutate('task', 't1', {'title': 'v0', 'priority': 4});
  await syncBoth(a, b);
  a.advance(1000);
  b.advance(2000);
}

final List<ContractScenario<ProbeFactory>> _baseScenarios = [
  _scenario('base: mutate — свои ops в base не учитываются', (run) async {
    final a = await run.node('a');
    final created = await a.engine.mutate('task', 't1', {'title': 'v0'});
    a.advance(10);
    final edited = await a.engine.mutate('task', 't1', {'title': 'v1'});
    check(created.single.base, null, 'base создания');
    check(edited.single.base, null, 'base правки');
  }),

  _scenario('base: mutate — base = макс. HLC чужих ops сущности, общий на '
      'все поля', (run) async {
    final (a, b) = await run.ab();
    await _sharedTask(a, b);
    final fromB = await b.engine.mutate('task', 't1', {'priority': 1});
    await b.pushTo(a);
    final ops = await a.engine.mutate('task', 't1', {
      'title': 'от a',
      'priority': 2,
    });
    check(ops.map((o) => o.base).toSet().toList(), [
      fromB.single.hlc,
    ], 'base всех ops правки');
  }),

  _scenario('base: tombstone — base = максимальный HLC правок с других '
      'узлов', (run) async {
    final (a, b) = await run.ab();
    await _sharedTask(a, b);
    final edit = await b.engine.mutate('task', 't1', {'title': 'от b'});
    await b.pushTo(a);
    final tombstone = await a.engine.delete('task', 't1');
    check(tombstone.single.base, edit.single.hlc, 'base tombstone');
  }),
];

final List<ContractScenario<ProbeFactory>> _detectionScenarios = [
  _scenario('детекция: параллельная правка одного поля — один конфликт с '
      'одним id на обоих', (run) async {
    final (a, b) = await run.ab();
    await _sharedTask(a, b);
    await a.engine.mutate('task', 't1', {'title': 'от a'});
    await b.engine.mutate('task', 't1', {'title': 'от b'});
    final toB = await a.pushTo(b);
    await b.pushTo(a);

    final onA = await a.conflicts();
    check(onA.length, 1, 'конфликтов на a');
    check(await b.conflicts(), onA, 'конфликты на b');
    check(toB.conflicts, onA, 'конфликты в отчёте');
    final c = onA.single;
    check(c.kind, ConflictKind.edit, 'вид');
    check(c.field, 'title', 'поле');
    check(c.olderOpId, 'a-3', 'older'); // a-1, a-2 — создание (title, priority)
    check(c.newerOpId, 'b-1', 'newer');
    check(c.resolved, false, 'resolved');
    // LWW действует до выбора пользователя.
    check(await a.taskField('t1', 'title'), 'от b', 'title на a');
    check(await b.taskField('t1', 'title'), 'от b', 'title на b');
  }),

  _scenario('детекция: последовательная правка (b видел правку a) — '
      'конфликта нет', (run) async {
    final (a, b) = await run.ab();
    await _sharedTask(a, b);
    await a.engine.mutate('task', 't1', {'title': 'от a'});
    await a.pushTo(b);
    await b.engine.mutate('task', 't1', {'title': 'от b'});
    await syncBoth(a, b);
    check(await a.conflicts(), <Conflict>[], 'конфликты на a');
    check(await b.conflicts(), <Conflict>[], 'конфликты на b');
  }),

  _scenario('детекция: параллельная правка одинаковым значением — '
      'конфликта нет', (run) async {
    final (a, b) = await run.ab();
    await _sharedTask(a, b);
    await a.engine.mutate('task', 't1', {'title': 'одно и то же'});
    await b.engine.mutate('task', 't1', {'title': 'одно и то же'});
    await syncBoth(a, b);
    check(await a.conflicts(), <Conflict>[], 'конфликты на a');
    check(await b.conflicts(), <Conflict>[], 'конфликты на b');
  }),

  _scenario('детекция: параллельная правка разных полей — конфликта нет', (
    run,
  ) async {
    final (a, b) = await run.ab();
    await _sharedTask(a, b);
    await a.engine.mutate('task', 't1', {'title': 'от a'});
    await b.engine.mutate('task', 't1', {'priority': 1});
    await syncBoth(a, b);
    check(await a.conflicts(), <Conflict>[], 'конфликты на a');
    check(await b.conflicts(), <Conflict>[], 'конфликты на b');
  }),

  _scenario('детекция: поле из silentFields — конфликта нет, LWW работает', (
    run,
  ) async {
    final (a, b) = await run.ab(silentFields: {'order_key'});
    await _sharedTask(a, b);
    await a.engine.mutate('task', 't1', {'order_key': 'a0'});
    await b.engine.mutate('task', 't1', {'order_key': 'b0'});
    await syncBoth(a, b);
    check(await a.conflicts(), <Conflict>[], 'конфликты на a');
    check(await a.taskField('t1', 'order_key'), 'b0', 'order_key на a');
  }),

  _scenario('детекция: правка vs удаление — конфликт вида delete с одним id '
      'на обоих', (run) async {
    final (a, b) = await run.ab();
    await _sharedTask(a, b);
    await a.engine.delete('task', 't1');
    await b.engine.mutate('task', 't1', {'title': 'правка'});
    await syncBoth(a, b);

    final onA = await a.conflicts();
    check(onA.length, 1, 'конфликтов на a');
    check(await b.conflicts(), onA, 'конфликты на b');
    check(onA.single.kind, ConflictKind.delete, 'вид');
    check(onA.single.field, 'title', 'поле');
  }),

  _scenario('детекция: удаление после того, как увидел правку, — конфликта '
      'нет', (run) async {
    final (a, b) = await run.ab();
    await _sharedTask(a, b);
    await b.engine.mutate('task', 't1', {'title': 'правка'});
    await b.pushTo(a);
    await a.engine.delete('task', 't1');
    await syncBoth(a, b);
    check(await a.conflicts(), <Conflict>[], 'конфликты на a');
    check(await b.conflicts(), <Conflict>[], 'конфликты на b');
  }),

  _scenario('детекция: воскрешение после увиденного удаления и правка — '
      'конфликта нет', (run) async {
    final (a, b) = await run.ab();
    await _sharedTask(a, b);
    await a.engine.delete('task', 't1');
    await a.pushTo(b);
    await b.engine.mutate('task', 't1', {
      Op.deletedField: false,
      'title': 'вернул',
    });
    await syncBoth(a, b);
    check(await a.conflicts(), <Conflict>[], 'конфликты на a');
    check(await b.conflicts(), <Conflict>[], 'конфликты на b');
    check((await a.probe.alive('task')).keys.toList(), ['t1'], 'alive на a');
  }),

  _scenario('детекция: порядок доставки не важен — одинаковые конфликты на '
      'всех узлах', (run) async {
    final (a, b) = await run.ab();
    final c = await run.node('c');
    final d = await run.node('d');
    await a.engine.mutate('task', 't1', {'title': 'v0'});
    await a.pushTo(b); // b правит задачу, которую уже получил
    a.advance(1000);
    b.advance(2000);
    await a.engine.mutate('task', 't1', {'title': 'от a'});
    await b.engine.mutate('task', 't1', {'title': 'от b'});

    final opsA = await a.opsOf('a');
    final opsB = await b.opsOf('b');
    await c.engine.applyAll([...opsA, ...opsB]);
    await d.engine.applyAll([...opsB.reversed, ...opsA.reversed]);

    final onC = await c.conflicts();
    check(onC.length, 1, 'конфликтов на c');
    check(await d.conflicts(), onC, 'конфликты на d');
  }),

  _scenario('детекция: повторная доставка — конфликт не дублируется', (
    run,
  ) async {
    final (a, b) = await run.ab();
    await _sharedTask(a, b);
    await a.engine.mutate('task', 't1', {'title': 'от a'});
    await b.engine.mutate('task', 't1', {'title': 'от b'});
    await syncBoth(a, b);
    final again = await a.pushTo(b);
    check(again.conflicts, <Conflict>[], 'новые конфликты в отчёте');
    check((await b.conflicts()).length, 1, 'конфликтов на b');
  }),

  _scenario('детекция: отмена удаления → синхронизация → чужая правка — '
      'конфликта нет', (run) async {
    final (a, b) = await run.ab();
    await _sharedTask(a, b);
    await a.engine.delete('task', 't1');
    a.advance(100);
    await a.engine.mutate('task', 't1', {Op.deletedField: false});
    await syncBoth(a, b);
    await b.engine.mutate('task', 't1', {'title': 'после синка'});
    final report = await b.pushTo(a);
    check(report.conflicts, <Conflict>[], 'конфликты в отчёте');
    check(await a.conflicts(), <Conflict>[], 'конфликты на a');
    check(await b.conflicts(), <Conflict>[], 'конфликты на b');
  }),

  for (final restoreFirst in [true, false])
    _scenario('детекция: воскрешение и правка одной группой (restore '
        '${restoreFirst ? 'первым' : 'вторым'}) — конфликта нет, '
        'инкрементально == rebuild', (run) async {
      final (a, b) = await run.ab();
      await _sharedTask(a, b);
      await a.engine.delete('task', 't1');
      await a.pushTo(b);
      final fields = restoreFirst
          ? {Op.deletedField: false, 'title': 'вернул'}
          : {'title': 'вернул', Op.deletedField: false};
      await b.engine.mutate('task', 't1', fields);
      await syncBoth(a, b);
      for (final node in [a, b]) {
        check(await node.conflicts(), <Conflict>[], 'конфликты');
        await node.engine.rebuild();
        check(await node.conflicts(), <Conflict>[], 'конфликты после rebuild');
      }
    }),

  _scenario('детекция: удаление и правка одной группой против чужой правки — '
      'два конфликта разных видов, одинаково при любом порядке', (run) async {
    final (a, b) = await run.ab();
    final c = await run.node('c');
    final d = await run.node('d');
    await a.engine.mutate('task', 't1', {'title': 'v0'});
    await a.pushTo(b);
    a.advance(1000);
    b.advance(2000);
    await a.engine.mutate('task', 't1', {
      Op.deletedField: true,
      'title': 'от a',
    });
    await b.engine.mutate('task', 't1', {'title': 'от b'});

    final opsA = await a.opsOf('a');
    final opsB = await b.opsOf('b');
    await c.engine.applyAll([...opsA, ...opsB]);
    await d.engine.applyAll([...opsB, ...opsA.reversed]);

    final onC = await c.conflicts();
    check(
      onC.map((x) => x.kind).toSet().length,
      2,
      'видов конфликтов (edit и delete)',
    );
    check(onC.map((x) => x.id).toSet().length, 2, 'разных id');
    check(await d.conflicts(), onC, 'конфликты на d');
    await d.engine.rebuild();
    check(await d.conflicts(), onC, 'конфликты на d после rebuild');
  }),
];

/// Параллельная правка названия t1 на a и b, синхронизация; конфликт с a.
Future<Conflict> _parallelTitles(ScenarioNode a, ScenarioNode b) async {
  await _sharedTask(a, b);
  await a.engine.mutate('task', 't1', {'title': 'от a'});
  await b.engine.mutate('task', 't1', {'title': 'от b'});
  await syncBoth(a, b);
  return (await a.conflicts()).single;
}

final List<ContractScenario<ProbeFactory>> _resolutionScenarios = [
  _scenario('разрешение: выбор на одном узле закрывает конфликт на другом', (
    run,
  ) async {
    final (a, b) = await run.ab();
    final conflict = await _parallelTitles(a, b);
    await a.engine.resolveConflict(conflict.id, {'title': 'от a'});
    await syncBoth(a, b);

    for (final node in [a, b]) {
      final at = 'на ${node.engine.nodeId}';
      check(await node.taskField('t1', 'title'), 'от a', 'title $at');
      final list = await node.conflicts();
      check(list.length, 1, 'выбор не создаёт новый конфликт $at');
      check(list.single.resolved, true, 'resolved $at');
    }
  }),

  _scenario('разрешение: узел, заметивший конфликт позже, не переоткрывает '
      'разрешённый', (run) async {
    final (a, b) = await run.ab();
    await _sharedTask(a, b);
    await a.engine.mutate('task', 't1', {'title': 'от a'});
    await b.engine.mutate('task', 't1', {'title': 'от b'});
    await b.pushTo(a);
    final conflict = (await a.conflicts()).single;
    await a.engine.resolveConflict(conflict.id, {'title': 'от a'});

    b.advance(30 * 60 * 1000); // часы b далеко впереди — не должно влиять
    final report = await a.pushTo(b);
    check(report.conflicts, <Conflict>[], 'уведомлять не о чем');
    final onB = await b.conflicts();
    check(onB.single.id, conflict.id, 'id на b');
    check(onB.single.resolved, true, 'resolved на b');
    check(await b.taskField('t1', 'title'), 'от a', 'title на b');
  }),

  _scenario('разрешение: «оставить как есть» — пустой выбор только закрывает '
      'конфликт', (run) async {
    final (a, b) = await run.ab();
    final conflict = await _parallelTitles(a, b);
    final ops = await a.engine.resolveConflict(conflict.id, {});
    check(ops.single.entityType, conflictEntityType, 'тип единственной op');
    check(await a.taskField('t1', 'title'), 'от b', 'title на a');
    check((await a.conflicts()).single.resolved, true, 'resolved');
  }),

  _scenario('разрешение: выбор «восстановить» при удалении → синхронизация → '
      'новая правка с другого узла — новых конфликтов нет', (run) async {
    final (a, b) = await run.ab();
    await _sharedTask(a, b);
    await a.engine.delete('task', 't1');
    await b.engine.mutate('task', 't1', {'title': 'правка'});
    await syncBoth(a, b);
    final conflict = (await a.conflicts()).single;
    check(conflict.kind, ConflictKind.delete, 'вид');

    await a.engine.resolveConflict(conflict.id, {Op.deletedField: false});
    await syncBoth(a, b);
    await b.engine.mutate('task', 't1', {'title': 'ещё'});
    await syncBoth(a, b);

    for (final node in [a, b]) {
      final at = 'на ${node.engine.nodeId}';
      final list = await node.conflicts();
      check(list.length, 1, 'конфликтов $at');
      check(list.single.resolved, true, 'resolved $at');
      check((await node.probe.alive('task')).keys.toList(), [
        't1',
      ], 'alive $at');
    }
  }),

  _scenario('разрешение: повторный выбор по разрешённому конфликту — ops не '
      'создаются', (run) async {
    final (a, b) = await run.ab();
    final conflict = await _parallelTitles(a, b);
    await a.engine.resolveConflict(conflict.id, {'title': 'от a'});
    check(
      await a.engine.resolveConflict(conflict.id, {'title': 'x'}),
      <Op>[],
      'ops повторного выбора',
    );
    check(await a.taskField('t1', 'title'), 'от a', 'title');
  }),

  _scenario('разрешение: неизвестный id — ArgumentError', (run) async {
    final a = await run.node('a');
    await checkThrows<ArgumentError>(
      () => a.engine.resolveConflict('нет', {}),
      'resolveConflict',
    );
  }),

  _scenario('разрешение: rebuild восстанавливает конфликты и отметку '
      'resolved', (run) async {
    final (a, b) = await run.ab();
    final conflict = await _parallelTitles(a, b);
    await a.engine.mutate('task', 't2', {'title': 'x'});
    await a.engine.resolveConflict(conflict.id, {'title': 'от a'});
    final before = await a.conflicts();
    await a.engine.rebuild();
    check(await a.conflicts(), before, 'конфликты после rebuild');
    check(await a.taskField('t1', 'title'), 'от a', 'title');
  }),
];

// ---------------------------------------------------------------------------
// Сценарии SyncStateStore
// ---------------------------------------------------------------------------

/// Все сценарии контракта [SyncStateStore].
final List<ContractScenario<SyncStateFactory>> syncStateScenarios = [
  ContractScenario('состояние: курсор неизвестного узла — 0', (create) async {
    final state = await create();
    check(await state.chunkCursor('a'), 0, 'курсор a');
  }),

  ContractScenario('состояние: курсоры хранятся по узлам', (create) async {
    final state = await create();
    await state.setChunkCursor('a', 3);
    await state.setChunkCursor('узел-б', 7);
    await state.setChunkCursor('a', 4);
    check(await state.chunkCursor('a'), 4, 'курсор a');
    check(await state.chunkCursor('узел-б'), 7, 'курсор узел-б');
  }),

  ContractScenario('состояние: папка и водяной знак изначально null', (
    create,
  ) async {
    final state = await create();
    check(await state.folderId(), null, 'folderId');
    check(await state.uploadedUpTo(), null, 'uploadedUpTo');
  }),

  ContractScenario('состояние: uploadedUpTo — HLC туда и обратно', (
    create,
  ) async {
    final state = await create();
    final hlc = _hlc(12345, counter: 17, node: 'узел-б');
    await state.setUploadedUpTo(hlc);
    check(await state.uploadedUpTo(), hlc, 'uploadedUpTo');
  }),

  ContractScenario('состояние: resetForFolder — сбрасывает курсоры и '
      'водяной знак, запоминает папку', (create) async {
    final state = await create();
    await state.resetForFolder('f1');
    await state.setChunkCursor('a', 3);
    await state.setUploadedUpTo(_hlc(1));
    await state.resetForFolder('f2');
    check(await state.folderId(), 'f2', 'folderId');
    check(await state.chunkCursor('a'), 0, 'курсор a');
    check(await state.uploadedUpTo(), null, 'uploadedUpTo');
  }),
];
