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

  /// Очистить проекции (журнал остаётся) — для [MergeEngine.rebuild].
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
      'stale: $stale, rejected: $rejected)';
}

/// Движок слияния: единственная точка, через которую меняются данные.
///
/// Локальные правки идут через [mutate] — он создаёт ops и сразу применяет их.
/// Чужие ops приходят через [apply] / [applyAll]. Правило одно: op применяется,
/// если её HLC больше HLC текущего значения поля (LWW по полю). Порядок доставки
/// не важен, повторная доставка безвредна.
final class MergeEngine {
  MergeEngine({
    required this.nodeId,
    required this.store,
    required this.nowMs,
    required this.newOpId,
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
  Hlc _clock;

  /// Текущее состояние часов узла. Приложение сохраняет его между запусками.
  Hlc get clock => _clock;

  /// Локальная правка: для каждого поля из [fields] создаётся op с общим HLC,
  /// пишется в журнал и в проекцию. Возвращает созданные ops (для транспорта).
  Future<List<Op>> mutate(
    String entityType,
    String entityId,
    Map<String, Object?> fields,
  ) async {
    if (fields.isEmpty) return const [];
    _clock = _clock.tick(nowMs());
    final ops = [
      for (final entry in fields.entries)
        Op(
          opId: newOpId(),
          nodeId: nodeId,
          hlc: _clock,
          entityType: entityType,
          entityId: entityId,
          field: entry.key,
          value: entry.value,
        ),
    ];
    await store.transaction(() async {
      for (final op in ops) {
        await store.appendOp(op);
        await store.writeField(op);
      }
    });
    return ops;
  }

  /// Пометить сущность удалённой (tombstone).
  Future<List<Op>> delete(String entityType, String entityId) =>
      mutate(entityType, entityId, {Op.deletedField: true});

  /// Применить одну чужую op.
  Future<ApplyResult> apply(Op op) => store.transaction(() => _applyInTx(op));

  /// Применить пакет ops одной транзакцией.
  Future<ApplyReport> applyAll(Iterable<Op> ops) {
    return store.transaction(() async {
      final report = ApplyReport();
      for (final op in ops) {
        report.add(await _applyInTx(op));
      }
      return report;
    });
  }

  Future<ApplyResult> _applyInTx(Op op) async {
    if (await store.containsOp(op.opId)) return ApplyResult.duplicate;
    try {
      _clock = _clock.receive(op.hlc, nowMs());
    } on HlcDriftException {
      return ApplyResult.rejected;
    }
    await store.appendOp(op);
    final current = await store.fieldHlc(op.entityType, op.entityId, op.field);
    if (current != null && !(op.hlc > current)) return ApplyResult.stale;
    await store.writeField(op);
    return ApplyResult.applied;
  }

  /// Пересобрать проекции с нуля из журнала.
  ///
  /// Проверка целостности и кнопка «пересобрать базу» в настройках: результат
  /// обязан совпадать с состоянием, накопленным инкрементально.
  Future<void> rebuild() {
    return store.transaction(() async {
      final ops = await store.allOps()
        ..sort((a, b) => a.hlc.compareTo(b.hlc));
      await store.clearProjections();
      for (final op in ops) {
        final current = await store.fieldHlc(
          op.entityType,
          op.entityId,
          op.field,
        );
        if (current == null || op.hlc > current) {
          await store.writeField(op);
        }
      }
    });
  }
}

/// Хранилище в памяти — для тестов и как эталон поведения для drift-адаптера.
final class MemoryOpStore implements OpStore {
  final Map<String, Op> _ops = <String, Op>{};

  /// entityType → entityId → field → value
  final Map<String, Map<String, Map<String, Object?>>> _entities =
      <String, Map<String, Map<String, Object?>>>{};

  final Map<String, Hlc> _fieldHlc = <String, Hlc>{};

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
  Future<void> appendOp(Op op) async => _ops[op.opId] = op;

  @override
  Future<Hlc?> fieldHlc(
    String entityType,
    String entityId,
    String field,
  ) async => _fieldHlc[_key(entityType, entityId, field)];

  @override
  Future<void> writeField(Op op) async {
    _entities
            .putIfAbsent(op.entityType, () => {})
            .putIfAbsent(op.entityId, () => {})[op.field] =
        op.value;
    _fieldHlc[_key(op.entityType, op.entityId, op.field)] = op.hlc;
  }

  @override
  Future<List<Op>> allOps() async => _ops.values.toList();

  @override
  Future<void> clearProjections() async {
    _entities.clear();
    _fieldHlc.clear();
  }

  @override
  Future<T> transaction<T>(Future<T> Function() action) => action();
}
