import '../../../data/projection/entity_fields.dart';
import '../../../domain/recent_searches.dart';
import '../../../sync/mutator.dart';

/// Недавние поисковые запросы — поле `recent_searches` общей сущности
/// `settings` (решения 5А, 4А plans/m5): добавить, убрать одно, «Удалить»
/// все. Правки идут строго по очереди: два быстрых Enter на одном устройстве
/// читают список после предыдущей записи и не теряют слово.
final class RecentSearchCommands {
  RecentSearchCommands({required this._mutator, required this._read});

  final Mutator _mutator;
  final Future<List<String>> Function() _read;
  Future<void> _tail = Future.value();

  /// [text] — наверх списка (повтор переносится, пустой не пишется).
  Future<void> add(String text) =>
      _change((list) => pushRecentSearch(list, text));

  /// Убрать [text] — крестик у запроса.
  Future<void> remove(String text) =>
      _change((list) => removeRecentSearch(list, text));

  /// «Удалить» — все недавние; удаления у `settings` нет, пишется пустой
  /// список.
  Future<void> clear() => _change((_) => const []);

  Future<void> _change(List<String> Function(List<String>) edit) {
    final step = _tail.then((_) async {
      final list = await _read();
      final next = edit(list);
      // `Mutator` и сам не пишет одинаковое значение; без перемен не
      // начинаем и транзакцию.
      if (_same(list, next)) return;
      await _mutator.update(EntityTypes.settings, settingsEntityId, {
        SettingsFields.recentSearches: next,
      });
    });
    // Ошибка шага достаётся вызывающему, очередь идёт дальше.
    _tail = step.then<void>((_) {}, onError: (Object _) {});
    return step;
  }

  static bool _same(List<String> a, List<String> b) =>
      a.length == b.length &&
      [for (var i = 0; i < a.length; i++) a[i] == b[i]].every((same) => same);
}
