/// Общие правила строки RRULE срока (SYNC_DESIGN «Проекции»): коды дней
/// недели, части строки и дата `UNTIL`. Ими пользуются разбор дат и текст
/// правила (lib/nlp), окно «Пользовательский…» (features/tasks/logic) и
/// расчёт следующего вхождения ([nextOccurrence] в recurrence.dart — со своей
/// строгой проверкой частей).
library;

/// Коды дней недели по порядку: `[0]` — понедельник (`DateTime.weekday - 1`).
const List<String> rruleWeekDays = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];

/// `BYDAY` рабочих дней — «каждый будний день».
const String rruleWorkdays = 'MO,TU,WE,TH,FR';

/// Код дня недели [weekday] (`DateTime.monday` … `DateTime.sunday`).
String rruleDay(int weekday) => rruleWeekDays[weekday - 1];

/// Части строки RRULE «ключ → значение» по порядку; `null` — часть без `=`
/// или ключ повторяется.
Map<String, String>? rruleParts(String line) {
  final parts = <String, String>{};
  for (final part in line.split(';')) {
    final eq = part.indexOf('=');
    if (eq < 1) return null;
    final key = part.substring(0, eq);
    if (parts.containsKey(key)) return null;
    parts[key] = part.substring(eq + 1);
  }
  return parts;
}

/// `YYYYMMDD` — дата `UNTIL` правила: серия идёт до конца этого дня.
String rruleUntilDate(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}'
    '${day.month.toString().padLeft(2, '0')}'
    '${day.day.toString().padLeft(2, '0')}';

final RegExp _untilDay = RegExp(r'^(\d{4})(\d{2})(\d{2})$');

/// Дата `UNTIL` без времени (`YYYYMMDD`) — числа как записаны, без проверки,
/// что такой день есть; `null` — `UNTIL` с временем или не дата.
({int year, int month, int day})? rruleUntilDay(String value) {
  final m = _untilDay.firstMatch(value);
  if (m == null) return null;
  return (
    year: int.parse(m[1]!),
    month: int.parse(m[2]!),
    day: int.parse(m[3]!),
  );
}
