import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';

import 'hlc.dart';
import 'op.dart';

/// Тип сущности конфликта в журнале. Ops этого типа несут только `resolved`.
const String conflictEntityType = 'conflict';

/// Поле конфликта, которое синхронизируется op-ом: `true` — пользователь выбрал вариант.
const String conflictResolvedField = 'resolved';

/// Вид конфликта.
enum ConflictKind {
  /// Два устройства параллельно записали в одно поле разные значения.
  edit,

  /// Одно устройство удалило сущность, другое параллельно её правило.
  delete,
}

/// Параллельная правка, о которой нужно сообщить пользователю.
///
/// Запись производная: вычисляется из журнала ops ([findConflicts]) и
/// пересоздаётся при `rebuild`. Через op синхронизируется только [resolved],
/// поэтому узел, заметивший конфликт позже, не может «переоткрыть» уже
/// разрешённый на другом устройстве.
@immutable
final class Conflict {
  const Conflict({
    required this.id,
    required this.kind,
    required this.entityType,
    required this.entityId,
    required this.field,
    required this.olderOpId,
    required this.newerOpId,
    this.resolved = false,
  });

  /// Детерминированный id — одинаков на всех узлах ([conflictId]).
  final String id;

  final ConflictKind kind;
  final String entityType;
  final String entityId;

  /// Поле, о котором спор. Для [ConflictKind.delete] — поле, которое правили.
  final String field;

  /// Op с меньшим HLC — проигравшая по LWW.
  final String olderOpId;

  /// Op с большим HLC — её значение действует, пока пользователь не выбрал.
  final String newerOpId;

  final bool resolved;

  Conflict withResolved(bool value) => Conflict(
    id: id,
    kind: kind,
    entityType: entityType,
    entityId: entityId,
    field: field,
    olderOpId: olderOpId,
    newerOpId: newerOpId,
    resolved: value,
  );

  @override
  bool operator ==(Object other) =>
      other is Conflict &&
      id == other.id &&
      kind == other.kind &&
      entityType == other.entityType &&
      entityId == other.entityId &&
      field == other.field &&
      olderOpId == other.olderOpId &&
      newerOpId == other.newerOpId &&
      resolved == other.resolved;

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    entityType,
    entityId,
    field,
    olderOpId,
    newerOpId,
    resolved,
  );

  @override
  String toString() =>
      'Conflict(${kind.name} $entityType/$entityId.$field, '
      '$olderOpId vs $newerOpId, resolved: $resolved)';
}

/// Id конфликта: SHA-256 от (entity_id, вид, field, меньший hlc, больший hlc),
/// оформленный как UUID версии 8 (RFC 9562, «свой алгоритм»).
///
/// Оба узла считают его из одних и тех же данных и получают одну запись,
/// а не две. Порядок аргументов [a] и [b] не важен. Вид входит в хеш: одна
/// правка может одновременно спорить и с правкой поля, и с удалением, если
/// другой узел записал их одной группой с общим HLC.
String conflictId(
  String entityId,
  ConflictKind kind,
  String field,
  Hlc a,
  Hlc b,
) {
  final (lo, hi) = a < b ? (a, b) : (b, a);
  final digest = sha256.convert(
    utf8.encode('$entityId\u0000${kind.name}\u0000$field\u0000$lo\u0000$hi'),
  );
  final bytes = digest.bytes.sublist(0, 16);
  bytes[6] = 0x80 | (bytes[6] & 0x0F); // версия 8
  bytes[8] = 0x80 | (bytes[8] & 0x3F); // вариант RFC 4122
  final hex = StringBuffer();
  for (var i = 0; i < 16; i++) {
    if (i == 4 || i == 6 || i == 8 || i == 10) hex.write('-');
    hex.write(bytes[i].toRadixString(16).padLeft(2, '0'));
  }
  return hex.toString();
}

/// Конфликты, в которых участвует [op], среди [entityOps] — всех известных
/// ops той же сущности (список может включать и саму [op]).
///
/// Решение принимается по каждой паре (op, другая op) отдельно, без оглядки
/// на третьи ops. Поэтому результат — чистая функция от набора ops: не
/// зависит от порядка прихода, повторной доставки и `rebuild`, и все узлы с
/// одинаковым журналом находят одинаковые конфликты.
///
/// Пара ops с разных узлов **параллельна**, если ни один автор не видел op
/// другого: `base` автора (что он знал о сущности от других узлов) меньше
/// HLC чужой op. Параллельная пара — конфликт, если:
/// - одно поле и разные значения → [ConflictKind.edit];
/// - одна из ops — tombstone, другая правит обычное поле → [ConflictKind.delete].
/// Поля из [silentFields] (например порядок) конфликтов не дают.
///
/// Для двух устройств правило точное: ops каждого узла доставляются по
/// порядку, поэтому «видел op узла с HLC ≥ X» означает «видел X». Для трёх и
/// более возможен редкий пропуск уведомления. На сходимость данных это не
/// влияет: LWW работает независимо от детекции.
List<Conflict> findConflicts(
  Op op,
  Iterable<Op> entityOps, {
  Set<String> silentFields = const {},
}) {
  if (op.entityType == conflictEntityType) return const [];
  final result = <Conflict>[];
  for (final other in entityOps) {
    if (other.opId == op.opId || other.nodeId == op.nodeId) continue;
    if (other.entityType != op.entityType || other.entityId != op.entityId) {
      continue;
    }
    if (_saw(op, other) || _saw(other, op)) continue;
    if (other.field == op.field) {
      if (silentFields.contains(op.field)) continue;
      if (jsonEquals(other.value, op.value)) continue;
      result.add(_conflict(ConflictKind.edit, op.field, op, other));
    } else if (op.isTombstone || other.isTombstone) {
      final edit = op.isTombstone ? other : op;
      if (edit.field == Op.deletedField || silentFields.contains(edit.field)) {
        continue;
      }
      result.add(_conflict(ConflictKind.delete, edit.field, op, other));
    }
  }
  return result;
}

/// Автор [x] видел [y]: знание автора о сущности не старше [y].
bool _saw(Op x, Op y) => x.base != null && !(x.base! < y.hlc);

Conflict _conflict(ConflictKind kind, String field, Op x, Op y) {
  final (older, newer) = x.hlc < y.hlc ? (x, y) : (y, x);
  return Conflict(
    id: conflictId(x.entityId, kind, field, x.hlc, y.hlc),
    kind: kind,
    entityType: x.entityType,
    entityId: x.entityId,
    field: field,
    olderOpId: older.opId,
    newerOpId: newer.opId,
  );
}

/// Глубокое сравнение JSON-значений (списки — по порядку, карты — по ключам).
bool jsonEquals(Object? a, Object? b) {
  if (a is List<Object?> && b is List<Object?>) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!jsonEquals(a[i], b[i])) return false;
    }
    return true;
  }
  if (a is Map<String, Object?> && b is Map<String, Object?>) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (!b.containsKey(entry.key) || !jsonEquals(entry.value, b[entry.key])) {
        return false;
      }
    }
    return true;
  }
  return a == b;
}
