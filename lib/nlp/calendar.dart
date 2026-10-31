/// Календарная арифметика разбора. День — `DateTime.utc` в полночь: стенное
/// время в UTC-обёртке, как в lib/domain/recurrence.dart, поэтому переход на
/// летнее время не сдвигает дни.
library;

/// День через [n] дней.
DateTime addDays(DateTime day, int n) =>
    DateTime.utc(day.year, day.month, day.day + n);

/// Число дней в месяце [month] года [year].
int daysInMonth(int year, int month) => DateTime.utc(year, month + 1, 0).day;

/// То же число через [n] месяцев; 29–31 — последний день короткого месяца
/// (31 января → 28 февраля).
DateTime addMonths(DateTime day, int n) {
  final index = day.month - 1 + n;
  final year = day.year + (index >= 0 ? index ~/ 12 : (index - 11) ~/ 12);
  final month = index % 12 + 1;
  final last = daysInMonth(year, month);
  return DateTime.utc(year, month, day.day > last ? last : day.day);
}

/// Дата, если она есть в календаре (31 ноября — нет).
DateTime? calendarDate(int year, int month, int day) {
  if (month < 1 || month > 12 || day < 1) return null;
  if (day > daysInMonth(year, month)) return null;
  return DateTime.utc(year, month, day);
}

/// Ближайшее [day] [month] не раньше [today] (29 февраля — в ближайший
/// високосный год).
DateTime? nextDayMonth(DateTime today, int month, int day) {
  for (var year = today.year; year <= today.year + 8; year++) {
    final date = calendarDate(year, month, day);
    if (date != null && !date.isBefore(today)) return date;
  }
  return null;
}

/// Ближайший день недели [weekday] строго после [today].
DateTime nextWeekday(DateTime today, int weekday) {
  final ahead = (weekday - today.weekday + 7) % 7;
  return addDays(today, ahead == 0 ? 7 : ahead);
}

/// [n]-й день недели [weekday] месяца ([n] = -1 — последний); `null` —
/// пятого такого дня в месяце нет.
DateTime? nthWeekday(int year, int month, int weekday, int n) {
  if (n < 0) {
    final last = DateTime.utc(year, month, daysInMonth(year, month));
    return addDays(last, -((last.weekday - weekday + 7) % 7));
  }
  final first = DateTime.utc(year, month);
  final day = 1 + (weekday - first.weekday + 7) % 7 + 7 * (n - 1);
  return calendarDate(year, month, day);
}

/// `YYYY-MM-DD`.
String isoDate(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';

/// `YYYYMMDD` — дата `UNTIL` правила.
String untilDate(DateTime day) => isoDate(day).replaceAll('-', '');

/// `HH:MM` из минут от полуночи.
String hhmm(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
    '${(minutes % 60).toString().padLeft(2, '0')}';
