import '../../../domain/conflicts.dart';
import '../../../domain/workspace.dart';
import '../../../sync/mutator.dart';

/// Выбор пользователя на экране «Конфликты» (SYNC_DESIGN «Конфликты: решает
/// пользователь», п. 4). Карточка закрывается целиком одной транзакцией:
/// значения выбранной стороны — одной правкой, остальные конфликты карточки
/// только отмечаются решёнными.
final class ConflictCommands {
  ConflictCommands({required this._mutator, required this._read});

  final Mutator _mutator;
  final Future<Workspace> Function() _read;

  /// Оставить сторону [side]: у правки — всё её действие, у удаления —
  /// «Оставить удалённым» или «Восстановить». Сторона, которая и так
  /// действует, только закрывает конфликты: её «молчащие» поля (порядок,
  /// дата выполнения) могли поменять позже, и выбор не должен их откатить.
  /// `true` — сущность восстановлена, но не видна: удалены её проект, раздел
  /// или родитель (каскад вычисляемый, и без пояснения кнопка казалась бы
  /// сломанной).
  Future<bool> keep(ConflictCard card, ConflictSide side) async {
    final ops = await _mutator.resolveConflicts(
      card.conflictIds,
      side.isCurrent ? const {} : side.fields,
    );
    // Пусто — карточка уже решена на другом устройстве: восстанавливать
    // было нечего.
    if (ops.isEmpty || !card.isDelete || side.deletes) return false;
    final ws = await _read();
    return switch (card.entity) {
      ConflictEntity.task => ws.task(card.entityId) == null,
      ConflictEntity.project => ws.project(card.entityId) == null,
      ConflictEntity.section => ws.section(card.entityId) == null,
      _ => false,
    };
  }

  /// Оставить то, что действует сейчас (поле правили после конфликта), —
  /// только закрыть конфликты.
  Future<void> keepCurrent(ConflictCard card) async {
    await _mutator.resolveConflicts(card.conflictIds, const {});
  }
}
