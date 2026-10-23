import 'package:meta/meta.dart';

import 'hlc.dart';

/// Одна операция журнала: «поле [field] сущности [entityId] стало [value]».
///
/// Неизменяема. Создание сущности — набор ops по всем её полям с одним [hlc];
/// удаление — op с полем [deletedField] и значением `true` (tombstone).
/// Сериализуется в JSON построчно (NDJSON) для файлов и LAN.
@immutable
final class Op {
  const Op({
    required this.opId,
    required this.nodeId,
    required this.hlc,
    required this.entityType,
    required this.entityId,
    required this.field,
    required this.value,
  });

  /// Разбор из JSON-карты (обратно к [toJson]).
  factory Op.fromJson(Map<String, Object?> json) {
    String str(String key) {
      final v = json[key];
      if (v is! String || v.isEmpty) {
        throw FormatException('Op: поле "$key" отсутствует или пустое', json);
      }
      return v;
    }

    return Op(
      opId: str('op_id'),
      nodeId: str('node_id'),
      hlc: Hlc.parse(str('hlc')),
      entityType: str('entity_type'),
      entityId: str('entity_id'),
      field: str('field'),
      value: json['value'],
    );
  }

  /// Имя поля-надгробия: `deleted = true` помечает сущность удалённой.
  static const String deletedField = 'deleted';

  /// Уникальный идентификатор op (UUIDv7) — для дедупликации.
  final String opId;

  /// Узел-автор.
  final String nodeId;

  /// Метка времени; по ней решается, кто победил (LWW).
  final Hlc hlc;

  /// Тип сущности: task, project, section, label, …
  final String entityType;

  /// Идентификатор сущности (UUIDv7).
  final String entityId;

  /// Имя поля сущности.
  final String field;

  /// Значение — любой JSON-совместимый объект, включая `null`.
  final Object? value;

  bool get isTombstone => field == deletedField && value == true;

  Map<String, Object?> toJson() => <String, Object?>{
    'op_id': opId,
    'node_id': nodeId,
    'hlc': hlc.toString(),
    'entity_type': entityType,
    'entity_id': entityId,
    'field': field,
    'value': value,
  };

  @override
  bool operator ==(Object other) => other is Op && opId == other.opId;

  @override
  int get hashCode => opId.hashCode;

  @override
  String toString() => 'Op($entityType/$entityId.$field = $value @ $hlc)';
}
