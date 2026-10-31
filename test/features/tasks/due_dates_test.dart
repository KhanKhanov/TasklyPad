import 'package:flutter_test/flutter_test.dart';
import 'package:planner/domain/models.dart';
import 'package:planner/features/tasks/logic/due_dates.dart';

void main() {
  // Понедельник, 26 октября 2026.
  final monday = DateTime(2026, 10, 26, 15, 30);

  test('isoDate и parseIsoDate — туда и обратно, мусор — null', () {
    expect(isoDate(DateTime(2026, 3, 5)), '2026-03-05');
    expect(parseIsoDate('2026-03-05'), DateTime(2026, 3, 5));
    expect(parseIsoDate('завтра'), isNull);
  });

  test('быстрые варианты срока от понедельника', () {
    expect(quickDueDate(QuickDue.today, monday), DateTime(2026, 10, 26));
    expect(quickDueDate(QuickDue.tomorrow, monday), DateTime(2026, 10, 27));
    expect(quickDueDate(QuickDue.weekend, monday), DateTime(2026, 10, 31));
    expect(quickDueDate(QuickDue.nextWeek, monday), DateTime(2026, 11, 2));
  });

  test('«На выходных» в субботу — сегодня; «Следующая неделя» в воскресенье '
      '— завтрашний понедельник', () {
    final saturday = DateTime(2026, 10, 31);
    final sunday = DateTime(2026, 11, 1);
    expect(quickDueDate(QuickDue.weekend, saturday), saturday);
    expect(quickDueDate(QuickDue.nextWeek, sunday), DateTime(2026, 11, 2));
  });

  test('вид даты относительно сегодня', () {
    DueKind kind(int days) =>
        dueKind(DateTime(2026, 10, 26).add(Duration(days: days)), monday);
    expect(kind(-3), DueKind.overdue);
    expect(kind(-1), DueKind.overdueYesterday);
    expect(kind(0), DueKind.today);
    expect(kind(1), DueKind.tomorrow);
    expect(kind(6), DueKind.thisWeek);
    expect(kind(7), DueKind.later);
  });

  // В зоне с переходом на летнее и зимнее время в сутках перехода 23 или
  // 25 часов. Арифметика по 24 часа там сдвигала дату; тест проходит по всем
  // дням двух лет и ловит это в поясе с переходами: в CI он идёт ещё раз с
  // TZ=Europe/Berlin (в UTC и Москве переходов нет).
  test('дни считаются по календарю в любой день года — переход на летнее и '
      'зимнее время не сдвигает дату', () {
    for (
      var d = DateTime(2026);
      d.year < 2028;
      d = DateTime(d.year, d.month, d.day + 1)
    ) {
      final next = DateTime(d.year, d.month, d.day + 1);
      expect(isoDate(quickDueDate(QuickDue.tomorrow, d)), isoDate(next));
      expect(quickDueDate(QuickDue.nextWeek, d).weekday, DateTime.monday);
      expect(dueKind(next, d), DueKind.tomorrow, reason: isoDate(d));
      expect(
        dueKind(DateTime(d.year, d.month, d.day + 2), d),
        DueKind.thisWeek,
        reason: isoDate(d),
      );
      expect(
        dueKind(DateTime(d.year, d.month, d.day - 1), d),
        DueKind.overdueYesterday,
      );
    }
  });

  const weekly = Due(
    date: '2026-10-26',
    time: '07:00',
    tz: 'Europe/Moscow',
    string: 'каждый пн в 7:00',
    lang: 'ru',
    rule: RecurrenceRule(
      rrule: ['FREQ=WEEKLY;BYDAY=MO'],
      fromCompletion: false,
    ),
  );

  test('dueOnDate — новая дата, время, пояс и правило сохраняются; без срока — '
      'только дата', () {
    expect(
      dueOnDate(weekly, '2026-10-27'),
      weekly.copyWith(date: '2026-10-27'),
    );
    expect(
      dueOnDate(
        const Due(date: '2026-10-26', tz: 'Europe/Moscow'),
        '2026-10-27',
      ),
      const Due(date: '2026-10-27'),
    );
    expect(dueOnDate(null, '2026-10-27'), const Due(date: '2026-10-27'));
  });

  test('dueWithTime — время меняется, правило сохраняется; без времени — без '
      'пояса', () {
    expect(dueWithTime(weekly, '09:30'), weekly.copyWith(time: '09:30'));
    expect(dueWithTime(weekly, null), weekly.copyWith(time: null, tz: null));
    expect(dueWithTime(weekly, null).isRecurring, isTrue);
  });
}
