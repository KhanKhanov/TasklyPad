import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/data_providers.dart';
import '../../../domain/conflicts.dart';

part 'conflict_marks.g.dart';

/// Какие сущности в споре — пометка «Конфликт» на экранах (решение 1Б
/// «Хода M4.13» docs/plans/m4-views-ordering.md). Чистая производная от
/// открытых карточек: пометка снимается вместе с карточкой.
///
/// Задачу помечает любая её карточка (любое поле, место, «выполнена»,
/// удаление) и карточка метки задачи (`ownerId`). Проект, раздел и метку —
/// только спор об имени или цвете (решение 1А): описание, избранное, архив,
/// место и удаление против правки видны на экране «Конфликты» (удаление было в
/// отклонённом варианте Б). Настройки и прочее не помечаются нигде;
/// «Входящие» — тоже (имя и цвет у них не меняются). Окно «Выбрать»
/// показывает все открытые карточки помеченной сущности, а не только те, что
/// дали пометку (план 1Б).
final class ConflictMarks {
  const ConflictMarks._(this._marked, this._cards);

  /// Пометки по открытым карточкам [cards].
  factory ConflictMarks.of(List<ConflictCard> cards) {
    final marked = <(ConflictEntity, String)>{};
    final byKey = <(ConflictEntity, String), List<ConflictCard>>{};
    for (final card in cards) {
      final key = _ownerKey(card);
      if (key == null) continue;
      (byKey[key] ??= []).add(card);
      if (_marks(card)) marked.add(key);
    }
    return ConflictMarks._(marked, byKey);
  }

  /// Пустой набор — конфликтов нет.
  static const ConflictMarks none = ConflictMarks._({}, {});

  final Set<(ConflictEntity, String)> _marked;
  final Map<(ConflictEntity, String), List<ConflictCard>> _cards;

  /// Сущность [id] типа [entity] помечена.
  bool has(ConflictEntity entity, String id) => _marked.contains((entity, id));

  /// Открытые карточки помеченной сущности [id]; у задачи — и карточки её
  /// меток. У непомеченной — пусто.
  List<ConflictCard> cardsFor(ConflictEntity entity, String id) =>
      has(entity, id) ? _cards[(entity, id)] ?? const [] : const [];

  /// Чья карточка: задача, проект, раздел или метка; `null` — ничья из них.
  static (ConflictEntity, String)? _ownerKey(ConflictCard card) {
    switch (card.entity) {
      case ConflictEntity.task:
      case ConflictEntity.project:
      case ConflictEntity.section:
      case ConflictEntity.label:
        return card.isInbox ? null : (card.entity, card.entityId);
      case ConflictEntity.taskLabel:
        final owner = card.ownerId;
        return owner == null ? null : (ConflictEntity.task, owner);
      case ConflictEntity.settings:
      case ConflictEntity.other:
        return null;
    }
  }

  /// Карточка даёт пометку своей сущности (решение 1А для проекта, раздела и
  /// метки).
  static bool _marks(ConflictCard card) => switch (card.entity) {
    ConflictEntity.task || ConflictEntity.taskLabel => true,
    _ => !card.isDelete && _touchesNameOrColor(card),
  };

  static bool _touchesNameOrColor(ConflictCard card) => [
    ...card.older.values,
    ...card.newer.values,
  ].any((v) => v.field == ConflictField.name || v.field == ConflictField.color);
}

/// Пометки спорных сущностей; строки берут свой `bool` через `select`.
@riverpod
ConflictMarks conflictMarks(Ref ref) {
  final cards = ref.watch(openConflictsProvider).value;
  return cards == null ? ConflictMarks.none : ConflictMarks.of(cards);
}
