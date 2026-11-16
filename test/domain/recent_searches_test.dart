import 'package:flutter_test/flutter_test.dart';
import 'package:planner/domain/recent_searches.dart';

// Недавние поиски (help «Introduction to search»: до пяти; решения 5А, 4А
// plans/m5): новые первыми, повтор — наверх, разбор чужих значений.
void main() {
  test('новый запрос — наверх; не больше $recentSearchLimit', () {
    var list = <String>[];
    for (final w in ['a', 'b', 'c', 'd', 'e', 'f']) {
      list = pushRecentSearch(list, w);
    }
    expect(list, ['f', 'e', 'd', 'c', 'b']);
  });

  test('повтор без учёта регистра и «ё» переносится наверх в новом '
      'написании', () {
    expect(pushRecentSearch(['b', 'Отчёт', 'c'], 'ОТЧЕТ'), ['ОТЧЕТ', 'b', 'c']);
  });

  test('пробелы по краям обрезаются, пустой запрос список не меняет', () {
    final list = ['a'];
    expect(pushRecentSearch(list, '  x  '), ['x', 'a']);
    expect(identical(pushRecentSearch(list, '   '), list), isTrue);
  });

  test('удаление одного', () {
    expect(removeRecentSearch(['a', 'b', 'c'], 'b'), ['a', 'c']);
  });

  test('значение поля: не список — пусто; не строки и пустые отброшены; '
      'лишние обрезаны', () {
    expect(recentSearchesOf(null), isEmpty);
    expect(recentSearchesOf('a'), isEmpty);
    expect(recentSearchesOf({'a': 1}), isEmpty);
    expect(recentSearchesOf(['a', 1, '', ' ', 'b']), ['a', 'b']);
    expect(recentSearchesOf(['1', '2', '3', '4', '5', '6']), hasLength(5));
  });
}
