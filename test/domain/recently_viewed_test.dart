import 'package:flutter_test/flutter_test.dart';
import 'package:planner/domain/recently_viewed.dart';

// «Недавно просмотренное» (решение 1А plans/m5 «Решения M5.4»): последнее —
// первым, без повторов, до пяти; вид для хранения.
void main() {
  const today = ViewedItem(ViewedKind.today);
  ViewedItem task(String id) => ViewedItem(ViewedKind.task, id);

  test('открытое — наверх, повтор убирается, не больше '
      '$recentlyViewedLimit', () {
    var list = const RecentlyViewed();
    for (final id in ['1', '2', '3', '4', '5', '6']) {
      list = list.visit(task(id));
    }
    list = list.visit(task('4'));
    expect(list.items, [task('4'), task('6'), task('5'), task('3'), task('2')]);
  });

  test('уже наверху — тот же объект: писать нечего', () {
    final list = const RecentlyViewed().visit(today);
    expect(identical(list.visit(today), list), isTrue);
  });

  test('вид для хранения читается обратно', () {
    final list = const RecentlyViewed()
        .visit(today)
        .visit(task('t'))
        .visit(const ViewedItem(ViewedKind.project, 'p'));
    expect(RecentlyViewed.fromJson(list.toJson()).items, list.items);
  });

  test('чужая версия и битые записи — ошибка разбора', () {
    for (final json in <Object?>[
      null,
      {'v': 2, 'items': <Object?>[]},
      {'v': 1, 'items': 'x'},
      {
        'v': 1,
        'items': [
          {'k': 'task'},
        ],
      },
      {
        'v': 1,
        'items': [
          {'k': 'today', 'id': 'x'},
        ],
      },
      {
        'v': 1,
        'items': [
          {'k': 'nope'},
        ],
      },
    ]) {
      expect(
        () => RecentlyViewed.fromJson(json),
        throwsFormatException,
        reason: '$json',
      );
    }
  });
}
