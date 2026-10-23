import 'dart:async';
import 'dart:convert';

import 'conflict.dart';
import 'hlc.dart';
import 'op.dart';

/// Хранилище журнала операций и проекций (материализованных сущностей).
///
/// В приложении реализуется поверх drift (таблицы `ops`, `tasks`, …), в тестах —
/// [MemoryOpStore]. Движок [MergeEngine] не знает, где лежат данные.
abstract interface class OpStore {
  /// Есть ли уже op с таким [opId] в журнале (дедупликация).
  Future<bool> containsOp(String opId);

  /// Дописать op в журнал. Журнал — источник истины, оттуда читают транспорты.
  Future<void> appendOp(Op op);

  /// HLC последней применённой записи поля, или `null`, если поле ещё не писали.
  Future<Hlc?> fieldHlc(String entityType, String entityId, String field);

  /// Записать значение поля в проекцию и запомнить его HLC.
  Future<void> writeField(Op op);

  /// Все ops журнала (порядок любой — движок сортирует сам).
  Future<List<Op>> allOps();

  /// Все ops журнала по одной сущности — для детекции конфликтов.
  Future<List<Op>> opsForEntity(String entityType, String entityId);

  /// Ops узла [nodeId] с HLC строго больше [after] (`null` — все),
  /// отсортированные по HLC. Транспорт выгружает так свои новые ops.
  Future<List<Op>> opsOfNodeAfter(String nodeId, Hlc? after);

  /// Сохранить производную запись конфликта, если её ещё нет.
  ///
  /// [Conflict.resolved] здесь игнорируется: он приходит только op-ом на
  /// сущность [conflictEntityType]. Возвращает `true`, если запись новая.
  Future<bool> putConflict(Conflict conflict);

  /// Все известные конфликты; `resolved` — из проекции op-ов.
  Future<List<Conflict>> conflicts();

  /// Очистить проекции и записи конфликтов (журнал остаётся) — для
  /// [MergeEngine.rebuild].
  Future<void> clearProjections();

  /// Выполнить [action] атомарно: либо всё, либо ничего.
  Future<T> transaction<T>(Future<T> Function() action);
}

/// Результат применения одной чужой op.
enum ApplyResult {
  /// Записана в проекцию — была новее текущего значения поля.
  applied,

  /// Уже есть в журнале — пропущена (идемпотентность).
  duplicate,

  /// Старее текущего значения поля — сохранена в журнал, но проекцию не меняла.
  stale,

  /// Отклонена: часы автора ушли в будущее дальше [Hlc.maxDrift]. В журнал не попала.
  rejected,
}

/// Сводка по пакету ops.
final class ApplyReport {
  ApplyReport();

  int applied = 0;
  int duplicate = 0;
  int stale = 0;
  int rejected = 0;

  /// Конфликты, впервые найденные при применении пакета (для уведомления).
  final List<Conflict> conflicts = <Conflict>[];

  int get total => applied + duplicate + stale + rejected;

  void add(ApplyResult result) {
    switch (result) {
      case ApplyResult.applied:
        applied++;
      case ApplyResult.duplicate:
        duplicate++;
      case ApplyResult.stale:
        stale++;
      case ApplyResult.rejected:
        rejected++;
    }
  }

  @override
  String toString() =>
      'ApplyReport(applied: $applied, duplicate: $duplicate, '
      'stale: $stale, rejected: $rejected, conflicts: ${conflicts.length})';
}

/// Движок слияния: единственная точка, через которую меняются данные.
///
/// Локальные правки идут через [mutate] — он создаёт ops и сразу применяет их.
/// Чужие ops приходят через [apply] / [applyAll]. Правило одно: op применяется,
/// если её HLC больше HLC текущего значения поля (LWW по полю). Порядок доставки
/// не важен, повторная доставка безвредна. Параллельные правки одного поля
/// дополнительно записываются как [Conflict] — для выбора пользователем.
final class MergeEngine {
  MergeEngine({
    required this.nodeId,
    required this.store,
    required this.nowMs,
    required this.newOpId,
    this.silentFields = const {},
    Hlc? initialClock,
  }) : _clock = initialClock ?? Hlc.zero(nodeId) {
    if (nodeId.isEmpty || nodeId.contains(':')) {
      throw ArgumentError.value(nodeId, 'nodeId', 'пустой или содержит ":"');
    }
  }

  /// Идентификатор этого узла.
  final String nodeId;

  final OpStore store;

  /// Текущее время в Unix-миллисекундах (инжектируется — в тестах управляемое).
  final int Function() nowMs;

  /// Генератор op_id (в приложении — UUIDv7).
  final String Function() newOpId;

  /// Поля, параллельная правка которых не считается конфликтом (например,
  /// ключ порядка: о переставленной задаче пользователя не спрашиваем).
  final Set<String> silentFields;

  Hlc _clock;

  /// Текущее состояние часов узла. Приложение сохраняет его между запусками.
  Hlc get clock => _clock;

  /// Локальная правка: для каждого поля из [fields] создаётся op с общим HLC,
  /// пишется в журнал и в проекцию. Возвращает созданные ops (для транспорта).
  ///
  /// `base` всех ops — максимальный HLC известных ops этой сущности с других
  /// узлов: так получатель поймёт, какие чужие правки автор уже видел.
  ///
  /// Конфликты, найденные при локальной правке (например, правка задачи,
  /// которую другой узел уже удалил), сохраняются в [OpStore.conflicts]
  /// так же, как при приёме, но в возвращаемый список не попадают.
  Future<List<Op>> mutate(
    String entityType,
    String entityId,
    Map<String, Object?> fields,
  ) async {
    if (fields.isEmpty) return const [];
    return store.transaction(() async {
      _clock = _clock.tick(nowMs());
      final base = _maxForeignHlc(
        await store.opsForEntity(entityType, entityId),
      );
      final ops = <Op>[];
      for (final entry in fields.entries) {
        ops.add(
          Op(
            opId: newOpId(),
            nodeId: nodeId,
            hlc: _clock,
            entityType: entityType,
            entityId: entityId,
            field: entry.key,
            value: entry.value,
            base: base,
          ),
        );
      }
      for (final op in ops) {
        await store.appendOp(op);
        await store.writeField(op);
      }
      // Проверка та же, что у получателя, — иначе узлы могли бы разойтись.
      for (final op in ops) {
        await _detectConflicts(op, null);
      }
      return ops;
    });
  }

  /// Пометить сущность удалённой (tombstone).
  Future<List<Op>> delete(String entityType, String entityId) =>
      mutate(entityType, entityId, {Op.deletedField: true});

  /// Применить одну чужую op. Найденные конфликты — в [OpStore.conflicts];
  /// транспортам, которым нужен список новых конфликтов, — [applyAll].
  Future<ApplyResult> apply(Op op) =>
      store.transaction(() => _applyInTx(op, ApplyReport()));

  /// Применить пакет ops одной транзакцией.
  ///
  /// [ApplyReport.conflicts] — новые конфликты, ещё не разрешённые к концу
  /// пакета: если тот же пакет принёс и выбор пользователя с другого
  /// устройства, уведомлять не о чем.
  Future<ApplyReport> applyAll(Iterable<Op> ops) {
    return store.transaction(() async {
      final report = ApplyReport();
      for (final op in ops) {
        report.add(await _applyInTx(op, report));
      }
      if (report.conflicts.isNotEmpty) {
        final resolved = {
          for (final c in await store.conflicts())
            if (c.resolved) c.id,
        };
        report.conflicts.removeWhere((c) => resolved.contains(c.id));
      }
      return report;
    });
  }

  /// Выбор пользователя по конфликту [conflictId].
  ///
  /// [fields] записываются обычной правкой сущности (автор видел обе стороны
  /// спора, поэтому это последовательная правка, а не новый конфликт; пустая
  /// карта — «оставить как есть»). Все открытые конфликты того же поля
  /// сущности (для удаления — все конфликты удаления) помечаются `resolved`,
  /// и эта отметка доходит до других узлов. Уже разрешённый конфликт — без
  /// изменений, ops не создаются.
  Future<List<Op>> resolveConflict(
    String conflictId,
    Map<String, Object?> fields,
  ) {
    return store.transaction(() async {
      final all = await store.conflicts();
      final target = all.where((c) => c.id == conflictId).firstOrNull;
      if (target == null) {
        throw ArgumentError.value(conflictId, 'conflictId', 'нет такого');
      }
      if (target.resolved) return const <Op>[];
      final ops = [...await mutate(target.entityType, target.entityId, fields)];
      for (final c in all) {
        if (c.resolved || c.entityId != target.entityId) continue;
        final sameField =
            c.kind == target.kind &&
            (c.field == target.field || c.kind == ConflictKind.delete);
        if (!sameField) continue;
        ops.addAll(
          await mutate(conflictEntityType, c.id, {conflictResolvedField: true}),
        );
      }
      return ops;
    });
  }

  Future<ApplyResult> _applyInTx(Op op, ApplyReport report) async {
    if (await store.containsOp(op.opId)) return ApplyResult.duplicate;
    try {
      _clock = _clock.receive(op.hlc, nowMs());
    } on HlcDriftException {
      return ApplyResult.rejected;
    }
    await store.appendOp(op);
    await _detectConflicts(op, report);
    final current = await store.fieldHlc(op.entityType, op.entityId, op.field);
    if (current != null && !(op.hlc > current)) return ApplyResult.stale;
    await store.writeField(op);
    return ApplyResult.applied;
  }

  Future<void> _detectConflicts(Op op, ApplyReport? report) async {
    if (op.entityType == conflictEntityType) return;
    final entityOps = await store.opsForEntity(op.entityType, op.entityId);
    for (final c in findConflicts(op, entityOps, silentFields: silentFields)) {
      if (await store.putConflict(c)) report?.conflicts.add(c);
    }
  }

  Hlc? _maxForeignHlc(List<Op> ops) {
    Hlc? max;
    for (final op in ops) {
      if (op.nodeId == nodeId) continue;
      if (max == null || op.hlc > max) max = op.hlc;
    }
    return max;
  }

  /// Пересобрать проекции и конфликты с нуля из журнала.
  ///
  /// Проверка целостности и кнопка «пересобрать базу» в настройках: результат
  /// обязан совпадать с состоянием, накопленным инкрементально.
  Future<void> rebuild() {
    return store.transaction(() async {
      final ops = await store.allOps()
        ..sort((a, b) => a.hlc.compareTo(b.hlc));
      await store.clearProjections();
      final byEntity = <String, List<Op>>{};
      for (final op in ops) {
        final current = await store.fieldHlc(
          op.entityType,
          op.entityId,
          op.field,
        );
        if (current == null || op.hlc > current) {
          await store.writeField(op);
        }
        byEntity
            .putIfAbsent('${op.entityType}\u0000${op.entityId}', () => [])
            .add(op);
      }
      for (final group in byEntity.values) {
        for (final op in group) {
          for (final c in findConflicts(
            op,
            group,
            silentFields: silentFields,
          )) {
            await store.putConflict(c);
          }
        }
      }
    });
  }
}

/// Хранилище в памяти — для тестов и как эталон поведения для drift-адаптера.
///
/// Ведёт себя как база: значения проходят через JSON (не-JSON значение —
/// ошибка), транзакции выполняются по одной, а исключение откатывает
/// изменения своего уровня вложенности.
final class MemoryOpStore implements OpStore {
  Map<String, Op> _ops = <String, Op>{};

  /// entityType → entityId → field → value
  Map<String, Map<String, Map<String, Object?>>> _entities =
      <String, Map<String, Map<String, Object?>>>{};

  Map<String, Hlc> _fieldHlc = <String, Hlc>{};

  Map<String, Conflict> _conflicts = <String, Conflict>{};

  /// Ключ зоны, внутри которой идёт транзакция этого хранилища.
  final Object _txZoneKey = Object();

  /// Хвост очереди внешних транзакций.
  Future<void> _txTail = Future<void>.value();

  static String _key(String type, String id, String field) =>
      '$type\u0000$id\u0000$field';

  /// Проекция сущности (копия) или `null`, если о ней ничего не известно.
  Map<String, Object?>? entity(String entityType, String entityId) {
    final fields = _entities[entityType]?[entityId];
    return fields == null ? null : Map<String, Object?>.unmodifiable(fields);
  }

  /// Все сущности типа, кроме помеченных удалёнными.
  Map<String, Map<String, Object?>> alive(String entityType) {
    final result = <String, Map<String, Object?>>{};
    for (final entry in (_entities[entityType] ?? const {}).entries) {
      if (entry.value[Op.deletedField] == true) continue;
      result[entry.key] = Map<String, Object?>.unmodifiable(entry.value);
    }
    return result;
  }

  /// Ops, созданные узлом [nodeId], в порядке добавления.
  List<Op> opsOf(String nodeId) =>
      _ops.values.where((op) => op.nodeId == nodeId).toList();

  int get opCount => _ops.length;

  @override
  Future<bool> containsOp(String opId) async => _ops.containsKey(opId);

  @override
  Future<void> appendOp(Op op) async {
    if (_ops.containsKey(op.opId)) return;
    _ops[op.opId] = Op(
      opId: op.opId,
      nodeId: op.nodeId,
      hlc: op.hlc,
      entityType: op.entityType,
      entityId: op.entityId,
      field: op.field,
      value: _viaJson(op.value),
      base: op.base,
    );
  }

  @override
  Future<Hlc?> fieldHlc(
    String entityType,
    String entityId,
    String field,
  ) async => _fieldHlc[_key(entityType, entityId, field)];

  @override
  Future<void> writeField(Op op) async {
    final value = _viaJson(op.value);
    _entities
            .putIfAbsent(op.entityType, () => {})
            .putIfAbsent(op.entityId, () => {})[op.field] =
        value;
    _fieldHlc[_key(op.entityType, op.entityId, op.field)] = op.hlc;
  }

  @override
  Future<List<Op>> allOps() async => _ops.values.toList();

  @override
  Future<List<Op>> opsForEntity(String entityType, String entityId) async =>
      _ops.values
          .where((op) => op.entityType == entityType && op.entityId == entityId)
          .toList();

  @override
  Future<List<Op>> opsOfNodeAfter(String nodeId, Hlc? after) async =>
      _ops.values
          .where(
            (op) => op.nodeId == nodeId && (after == null || op.hlc > after),
          )
          .toList()
        ..sort((a, b) => a.hlc.compareTo(b.hlc));

  @override
  Future<bool> putConflict(Conflict conflict) async {
    if (_conflicts.containsKey(conflict.id)) return false;
    _conflicts[conflict.id] = conflict.withResolved(false);
    return true;
  }

  @override
  Future<List<Conflict>> conflicts() async => [
    for (final c in _conflicts.values)
      c.withResolved(
        entity(conflictEntityType, c.id)?[conflictResolvedField] == true,
      ),
  ];

  @override
  Future<void> clearProjections() async {
    _entities.clear();
    _fieldHlc.clear();
    _conflicts.clear();
  }

  /// Вложенный вызов (из той же транзакции) выполняется сразу, внешний —
  /// после завершения предыдущих внешних, как в базе с одним соединением.
  @override
  Future<T> transaction<T>(Future<T> Function() action) {
    if (identical(Zone.current[_txZoneKey], this)) return _withRollback(action);
    final previous = _txTail;
    final done = Completer<void>();
    _txTail = done.future;
    return previous
        .then(
          (_) => runZoned(
            () => _withRollback(action),
            zoneValues: {_txZoneKey: this},
          ),
        )
        .whenComplete(done.complete);
  }

  Future<T> _withRollback<T>(Future<T> Function() action) async {
    final ops = Map.of(_ops);
    final entities = {
      for (final type in _entities.entries)
        type.key: {
          for (final entity in type.value.entries)
            entity.key: Map.of(entity.value),
        },
    };
    final fieldHlc = Map.of(_fieldHlc);
    final conflicts = Map.of(_conflicts);
    try {
      return await action();
    } catch (_) {
      _ops = ops;
      _entities = entities;
      _fieldHlc = fieldHlc;
      _conflicts = conflicts;
      rethrow;
    }
  }

  /// Значение после записи в базу и чтения обратно: только JSON-типы.
  /// Не-JSON значение (например, `DateTime`) — [JsonUnsupportedObjectError].
  static Object? _viaJson(Object? value) => jsonDecode(jsonEncode(value));
}
