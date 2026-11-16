import '../../../domain/models.dart';
import '../../../domain/recently_viewed.dart';
import '../../../domain/search.dart';
import '../../../domain/text_fold.dart';
import '../../shell/logic/shell_commands.dart';
import 'search_input.dart';

// Строки окна «Поиск» в порядке, по которому ходят ↑/↓ (решения 2А, 3А
// plans/m5 «Решения M5.4»): до ввода — недавние запросы, недавно
// просмотренное, команды (help: «recently viewed … and a list of keyboard
// shortcuts»); с текстом — подходящие команды, найденное, выполненные и
// действия «Искать в выполненных задачах», «Сохранить как фильтр».

/// Строка окна «Поиск».
sealed class SearchItem {
  const SearchItem();
}

/// Недавний запрос — подставить в строку.
final class RecentSearchRow extends SearchItem {
  const RecentSearchRow(this.text);
  final String text;
}

/// Недавно просмотренное — открыть.
final class ViewedRow extends SearchItem {
  const ViewedRow(this.item);
  final ViewedItem item;
}

/// Команда оболочки.
final class CommandRow extends SearchItem {
  const CommandRow(this.id);
  final ShellCommandId id;
}

/// Найденный элемент.
final class HitRow extends SearchItem {
  const HitRow(this.hit);
  final SearchHit hit;
}

/// Выполненная задача (после «Искать в выполненных задачах»).
final class CompletedRow extends SearchItem {
  const CompletedRow(this.task);
  final Task task;
}

/// «Искать в выполненных задачах».
final class SearchCompletedRow extends SearchItem {
  const SearchCompletedRow();
}

/// «Сохранить как фильтр».
final class SaveAsFilterRow extends SearchItem {
  const SaveAsFilterRow();
}

/// Команды окна, подходящие к строке [input]: до ввода — все команды окна,
/// с текстом — те, у которых все слова строки есть в подписи [labelOf]
/// (допущение, О-69).
List<ShellCommandId> paletteCommands(
  SearchInput input,
  String Function(ShellCommandId) labelOf,
) {
  final palette = [
    for (final c in shellCommands)
      if (c.inPalette) c.id,
  ];
  final text = switch (input) {
    EmptySearch() => null,
    WordSearch(:final query) => query.text,
    FilterSearch(:final text) => text,
  };
  if (text == null) return palette;
  final query = SearchQuery.parse(text);
  return [
    for (final id in palette)
      if (query.inText(foldText(labelOf(id)))) id,
  ];
}

/// Строки окна по порядку. [hits] — найденное выбранной вкладки (у запроса
/// фильтра — его задачи); [completed] — показанные выполненные;
/// [canSearchCompleted] — кнопка «Искать в выполненных задачах» видна (поиск
/// словами, выполненные ещё не показаны; help: у запроса фильтра её нет).
List<SearchItem> searchItems({
  required SearchInput input,
  required List<String> recent,
  required List<ViewedItem> viewed,
  required List<ShellCommandId> commands,
  List<SearchHit> hits = const [],
  List<Task> completed = const [],
  bool canSearchCompleted = false,
}) => switch (input) {
  EmptySearch() => [
    for (final text in recent) RecentSearchRow(text),
    for (final item in viewed) ViewedRow(item),
    for (final id in commands) CommandRow(id),
  ],
  _ => [
    for (final id in commands) CommandRow(id),
    for (final hit in hits) HitRow(hit),
    for (final task in completed) CompletedRow(task),
    if (canSearchCompleted) const SearchCompletedRow(),
    const SaveAsFilterRow(),
  ],
};
