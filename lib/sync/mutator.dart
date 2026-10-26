import 'package:oplog_sync/oplog_sync.dart';

import '../core/ids.dart';
import '../data/local_meta_dao.dart';
import '../data/projection/entity_fields.dart';
import 'drift_op_store.dart';

/// Единственная точка записи данных пользователя в приложении.
///
/// Каждая правка — ops через [MergeEngine] (журнал и проекция) и сохранение
/// часов движка в `local_meta` одной транзакцией: после перезапуска часы не
/// окажутся позади уже записанных ops. Прямые `update`/`delete` в таблицах
/// сущностей запрещены — только через этот класс.
final class Mutator {
  Mutator({
    required this._engine,
    required this._store,
    required this._meta,
    required this._ids,
    this._objectFields = mergedObjectFields,
  });

  final MergeEngine _engine;
  final DriftOpStore _store;
  final LocalMetaDao _meta;
  final IdGenerator _ids;

  /// Тип сущности → поле-объект → ключи, которые это приложение знает.
  final Map<String, Map<String, Set<String>>> _objectFields;

  /// Создать сущность с полями [fields]; возвращает её новый id (UUIDv7).
  Future<String> create(String entityType, Map<String, Object?> fields) async {
    _checkWritable(entityType);
    final id = _ids.next();
    await _write(() => _engine.mutate(entityType, id, fields));
    return id;
  }

  /// Изменить поля [fields] сущности; остальные поля не трогаются.
  ///
  /// Поле-объект (`due`) передаётся целиком в том виде, как его понимает это
  /// приложение: известные ключи, которых нет в новом значении, убираются
  /// (дата без времени заменяет дату со временем). Незнакомые ключи — от более
  /// новой версии приложения, например правило повторения, — сохраняются из
  /// текущего значения. `null` у самого поля убирает объект (срок) целиком.
  Future<List<Op>> update(
    String entityType,
    String entityId,
    Map<String, Object?> fields,
  ) {
    _checkWritable(entityType);
    return _write(() async {
      final merged = await _mergeObjects(entityType, entityId, fields);
      // Только поля, которые действительно меняются: op на поле с прежним
      // значением спорила бы с параллельной правкой этого поля на другом
      // устройстве (ложный конфликт) и могла бы откатить её по LWW —
      // например, перестановка задачи откатила бы перенос её подзадачи.
      final changed = <String, Object?>{};
      // Новая для этого узла сущность (детерминированный id: метка задачи,
      // «Входящие») пишется целиком: на другом устройстве она может уже быть,
      // и op со значением по умолчанию (`deleted=false`) должна побеждать там
      // более раннюю правку по LWW.
      final known = await _store.hasEntity(entityType, entityId);
      for (final MapEntry(key: field, :value) in merged.entries) {
        final current = await _store.fieldValue(entityType, entityId, field);
        // У известной сущности поля ещё нет, а значение — то же, что колонка
        // показывает по умолчанию (`false`, `list`): видимого изменения нет.
        final unchanged =
            jsonEquals(current, value) ||
            (known &&
                current == null &&
                _store.isProjectionDefault(entityType, field, value));
        if (!unchanged) changed[field] = value;
      }
      if (changed.isEmpty) return const <Op>[];
      return _engine.mutate(entityType, entityId, changed);
    });
  }

  /// Пометить сущность удалённой (tombstone); [restore] отменяет.
  Future<List<Op>> delete(String entityType, String entityId) {
    _checkWritable(entityType);
    return _write(() => _engine.delete(entityType, entityId));
  }

  /// Отменить удаление («Отменить» в тосте).
  Future<List<Op>> restore(String entityType, String entityId) =>
      update(entityType, entityId, {Op.deletedField: false});

  /// Выбор пользователя по конфликту: [fields] — выбранные значения целиком
  /// (как в одной из спорящих ops), без слияния объектов.
  Future<List<Op>> resolveConflict(
    String conflictId,
    Map<String, Object?> fields,
  ) => _write(() => _engine.resolveConflict(conflictId, fields));

  /// Несколько правок одной транзакцией (задача и её метки, перенос
  /// поддерева, завершение с подзадачами): ops одного действия пользователя
  /// атомарны — синхронизация и сбой видят либо все, либо ни одной.
  Future<T> batch<T>(Future<T> Function() action) => _store.transaction(action);

  /// Запомнить текущие значения полей [targets] перед действием. [Undo]
  /// записывает их обратно новыми ops: удалять ops из журнала нельзя — они
  /// могли уже уйти в папку синхронизации. Поля, которых не было, вернутся
  /// как `null`.
  Future<Undo> capture(Iterable<UndoTarget> targets) async => Undo._(this, [
    for (final t in targets)
      (
        entityType: t.entityType,
        entityId: t.entityId,
        fields: {
          for (final field in t.fields)
            field: await _store.fieldValue(t.entityType, t.entityId, field),
        },
      ),
  ]);

  /// База оказалась копией и узел получил новый id: переиздать от него
  /// невыгруженные (HLC после [uploadedUpTo]) ops прежнего узла, которые ещё
  /// побеждают в своих полях, — иначе их никто не выгрузит. Время исходных
  /// ops сохраняется (`MergeEngine.adopt`). Возвращает число новых ops.
  Future<int> adoptUnsyncedOps(String previousNodeId, Hlc? uploadedUpTo) =>
      _write(
        () async => (await _engine.adopt(previousNodeId, uploadedUpTo)).length,
      );

  Future<T> _write<T>(Future<T> Function() action) =>
      _store.transaction(() async {
        final result = await action();
        await _meta.setHlc(_engine.clock);
        return result;
      });

  /// Поле-объект: известные приложению ключи берутся из нового значения
  /// целиком (нет в нём — ключ убран), незнакомые — из текущего значения.
  /// Объект без ключей — `null` (поля нет).
  Future<Map<String, Object?>> _mergeObjects(
    String entityType,
    String entityId,
    Map<String, Object?> fields,
  ) async {
    final objectFields = _objectFields[entityType];
    if (objectFields == null) return fields;
    final result = Map<String, Object?>.of(fields);
    for (final MapEntry(key: field, value: knownKeys) in objectFields.entries) {
      final value = fields[field];
      if (value is! Map<String, Object?>) continue;
      final current = await _store.fieldValue(entityType, entityId, field);
      final merged = <String, Object?>{
        if (current is Map<String, Object?>)
          for (final entry in current.entries)
            if (!knownKeys.contains(entry.key)) entry.key: entry.value,
        ...value,
      }..removeWhere((_, v) => v == null);
      result[field] = merged.isEmpty ? null : merged;
    }
    return result;
  }

  static void _checkWritable(String entityType) {
    if (entityType == conflictEntityType) {
      throw ArgumentError.value(
        entityType,
        'entityType',
        'конфликт меняется только через resolveConflict',
      );
    }
  }
}

/// Поля одной сущности, которые меняет действие с «Отменить».
typedef UndoTarget = ({String entityType, String entityId, Set<String> fields});

/// Отмена действия: прежние значения полей, записанные обратно новыми ops.
///
/// Если за время тоста поле изменило другое устройство, отмена — обычная
/// правка поверх него (последняя по времени).
final class Undo {
  Undo._(this._mutator, this._values);

  final Mutator _mutator;
  final List<
    ({String entityType, String entityId, Map<String, Object?> fields})
  >
  _values;

  /// Вернуть прежние значения одной транзакцией.
  Future<void> call() => _mutator.batch(() async {
    for (final v in _values) {
      await _mutator.update(v.entityType, v.entityId, v.fields);
    }
  });
}
