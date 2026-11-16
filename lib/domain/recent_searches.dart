import 'text_fold.dart';

// Недавние поисковые запросы (help «Introduction to search»: «saves up to
// five keywords in the Recent searches list»). Хранятся полем
// `recent_searches` настроек — списком строк, новые первыми (решения 5А и 4А
// plans/m5): синхронизируются, параллельные добавления сводит LWW без
// карточки.

/// Недавних поисков не больше.
const int recentSearchLimit = 5;

/// Список из значения поля [json]: не список — пусто, не строки и пустые
/// отбрасываются, остаются первые [recentSearchLimit] (значение могло прийти
/// с другой версии приложения).
List<String> recentSearchesOf(Object? json) => json is List
    ? [
        for (final item in json)
          if (item is String && item.trim().isNotEmpty) item,
      ].take(recentSearchLimit).toList()
    : const [];

/// [list] с [text] наверху: повтор (без учёта регистра и «ё») переносится
/// наверх в новом написании; пустой текст список не меняет.
List<String> pushRecentSearch(List<String> list, String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return list;
  final key = foldText(trimmed);
  return [
    trimmed,
    for (final item in list)
      if (foldText(item) != key) item,
  ].take(recentSearchLimit).toList();
}

/// [list] без [text] (точное совпадение — строка из самого списка).
List<String> removeRecentSearch(List<String> list, String text) => [
  for (final item in list)
    if (item != text) item,
];
