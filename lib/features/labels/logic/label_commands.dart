import '../../../core/fractional_index.dart';
import '../../../data/projection/entity_fields.dart';
import '../../../domain/rules.dart';
import '../../../domain/workspace.dart';
import '../../../sync/mutator.dart';

/// Действия пользователя над метками — всё через [Mutator].
///
/// Имя метки уникально без учёта регистра ([RejectReason.duplicateName]).
/// Два устройства всё же могут создать одноимённые метки офлайн — тогда обе
/// живут, пока пользователь не удалит лишнюю.
final class LabelCommands {
  LabelCommands({required this._mutator, required this._read});

  final Mutator _mutator;
  final Future<Workspace> Function() _read;

  /// Создать метку в конце списка. Возвращает id.
  Future<String> add({
    required String name,
    String color = 'charcoal',
    bool isFavorite = false,
  }) async {
    final ws = await _read();
    final text = _name(ws, name);
    return _mutator.create(EntityTypes.label, {
      LabelFields.name: text,
      LabelFields.color: color,
      LabelFields.orderKey: keyAtEnd([for (final l in ws.labels) l.orderKey]),
      LabelFields.isFavorite: isFavorite,
    });
  }

  Future<void> rename(String id, String name) async {
    final ws = await _read();
    _alive(ws, id);
    await _mutator.update(EntityTypes.label, id, {
      LabelFields.name: _name(ws, name, except: id),
    });
  }

  Future<void> setColor(String id, String color) =>
      _update(id, {LabelFields.color: color});

  Future<void> setFavorite(String id, bool favorite) =>
      _update(id, {LabelFields.isFavorite: favorite});

  /// Удалить (tombstone): метка пропадает со всех задач, связи остаются в
  /// журнале — вернуть метку значит вернуть и её связи.
  Future<void> delete(String id) async {
    _alive(await _read(), id);
    await _mutator.delete(EntityTypes.label, id);
  }

  Future<void> _update(String id, Map<String, Object?> fields) async {
    _alive(await _read(), id);
    await _mutator.update(EntityTypes.label, id, fields);
  }

  static void _alive(Workspace ws, String id) {
    if (ws.label(id) == null) {
      throw const CommandRejected(RejectReason.notFound);
    }
  }

  static String _name(Workspace ws, String name, {String? except}) {
    final text = name.trim();
    if (text.isEmpty) throw const CommandRejected(RejectReason.emptyName);
    final lower = text.toLowerCase();
    if (ws.labels.any((l) => l.id != except && l.name.toLowerCase() == lower)) {
      throw const CommandRejected(RejectReason.duplicateName);
    }
    return text;
  }
}
