import 'package:drift/drift.dart';
import 'package:logger/logger.dart';

/// Значение op не того типа, что ждёт колонка (например, строка в приоритете).
final class ProjectionTypeError implements Exception {
  ProjectionTypeError(this.expected, this.value);

  final String expected;
  final Object? value;

  @override
  String toString() =>
      'ожидался $expected, пришло ${value.runtimeType}: $value';
}

/// Строит из значения поля строку-companion: `id` и колонки этого поля.
/// Значение `null` даёт значения колонок по умолчанию.
typedef FieldWriter<R> = Insertable<R> Function(String id, Object? value);

/// Как поля одного типа сущности ложатся в колонки его таблицы.
abstract interface class EntityProjector {
  String get entityType;

  /// Поля, которые проектор знает (белый список).
  Set<String> get fields;

  TableInfo<Table, Object?> get table;

  /// Записать поле [field] сущности [id]; `false` — поле неизвестно, таблица
  /// не тронута.
  Future<bool> write(String id, String field, Object? value);

  /// Удалить все строки таблицы (пересборка проекции).
  Future<void> clear();

  /// SQL-имена колонок, которые пишет поле [field].
  Set<String> columnsOf(String field);

  /// Значение [value] поля [field] даёт те же колонки, что и отсутствие поля
  /// (`null` — значения по умолчанию). Неизвестное поле или значение не того
  /// типа — `false`.
  bool isDefault(String field, Object? value);
}

/// Проектор поверх таблицы drift с белым списком полей.
///
/// Имена колонок берутся только из ключей [writers] (код), не из данных op:
/// подделанный файл синхронизации не может подставить в SQL своё имя.
/// Значение не того типа даёт значения по умолчанию и предупреждение; само
/// значение остаётся в журнале и `field_versions`.
final class TableProjector<T extends Table, R> implements EntityProjector {
  TableProjector({
    required this.db,
    required this.entityType,
    required this.table,
    required Map<String, FieldWriter<R>> writers,
    void Function(String message)? warn,
  }) : _writers = Map.unmodifiable(writers),
       _warn = warn ?? _loggerWarn;

  final GeneratedDatabase db;

  @override
  final String entityType;

  @override
  final TableInfo<T, R> table;

  final Map<String, FieldWriter<R>> _writers;
  final void Function(String message) _warn;

  @override
  Set<String> get fields => _writers.keys.toSet();

  /// Копия без полей [removed] — так выглядит реестр более старой версии.
  TableProjector<T, R> without(Set<String> removed) => TableProjector(
    db: db,
    entityType: entityType,
    table: table,
    writers: {
      for (final entry in _writers.entries)
        if (!removed.contains(entry.key)) entry.key: entry.value,
    },
    warn: _warn,
  );

  @override
  Future<bool> write(String id, String field, Object? value) async {
    final writer = _writers[field];
    if (writer == null) return false;
    Insertable<R> row;
    try {
      row = writer(id, value);
    } on ProjectionTypeError catch (e) {
      _warn('$entityType/$id.$field: $e — в колонке значение по умолчанию');
      row = writer(id, null);
    }
    await db.into(table).insertOnConflictUpdate(row);
    return true;
  }

  @override
  Future<void> clear() => db.delete(table).go();

  @override
  Set<String> columnsOf(String field) {
    final writer = _writers[field];
    if (writer == null) return const {};
    return writer('', null).toColumns(false).keys.toSet()..remove('id');
  }

  @override
  bool isDefault(String field, Object? value) {
    final writer = _writers[field];
    if (writer == null) return false;
    try {
      final given = writer('', value).toColumns(false);
      final defaults = writer('', null).toColumns(false);
      return given.length == defaults.length &&
          given.entries.every((e) => defaults[e.key] == e.value);
    } on ProjectionTypeError {
      return false;
    }
  }

  static final Logger _logger = Logger();

  static void _loggerWarn(String message) => _logger.w(message);
}

/// Реестр проекторов: тип сущности → проектор, плюс версия набора полей.
///
/// [version] увеличивается при каждом изменении набора полей или колонок:
/// по расхождению с сохранённой версией база перекладывает `field_versions`
/// в таблицы заново (`DriftOpStore.reproject`).
final class ProjectorRegistry {
  ProjectorRegistry(this.version, Iterable<EntityProjector> projectors)
    : _byType = {for (final p in projectors) p.entityType: p};

  final int version;
  final Map<String, EntityProjector> _byType;

  EntityProjector? operator [](String entityType) => _byType[entityType];

  Iterable<EntityProjector> get all => _byType.values;

  Set<String> get entityTypes => _byType.keys.toSet();
}

// Преобразования значений op в значения колонок. Проверяется только тип
// SQLite; смысловых проверок нет — незнакомое значение (например, новый
// вид проекта) ложится как есть, UI сам решает, как его показать.

/// Строка; `null` → [fallback].
String textOr(Object? value, String fallback) => switch (value) {
  null => fallback,
  final String s => s,
  _ => throw ProjectionTypeError('строка', value),
};

/// Строка или `null`.
String? textOrNull(Object? value) => switch (value) {
  null => null,
  final String s => s,
  _ => throw ProjectionTypeError('строка', value),
};

/// Логическое значение; `null` → [fallback].
bool boolOr(Object? value, bool fallback) => switch (value) {
  null => fallback,
  final bool b => b,
  _ => throw ProjectionTypeError('логическое', value),
};

/// Целое; `null` → [fallback]. `2.0` из JSON другого языка — тоже целое.
int intOr(Object? value, int fallback) => switch (value) {
  null => fallback,
  final int i => i,
  final double d when d == d.truncateToDouble() => d.toInt(),
  _ => throw ProjectionTypeError('целое', value),
};

/// Целое или `null`.
int? intOrNull(Object? value) => value == null ? null : intOr(value, 0);
