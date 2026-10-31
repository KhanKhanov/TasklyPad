/// Даты срока для интерфейса: быстрые варианты выбора и вид даты в строке
/// задачи. Чистые функции от «сегодня» — без часов внутри, поэтому
/// проверяются тестами на любой день.
library;

import '../../../domain/models.dart';

/// Дата `YYYY-MM-DD` — как в поле срока.
String isoDate(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';

/// Дата из поля срока; неверная строка (от более новой версии) — `null`.
DateTime? parseIsoDate(String value) {
  final parts = value.split('-');
  if (parts.length != 3) return null;
  final (y, m, d) = (
    int.tryParse(parts[0]),
    int.tryParse(parts[1]),
    int.tryParse(parts[2]),
  );
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}

DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

/// День через [n] дней — по календарю, а не по 24 часа: в сутках перехода на
/// летнее или зимнее время 23 или 25 часов.
DateTime _plusDays(DateTime day, int n) =>
    DateTime(day.year, day.month, day.day + n);

/// Быстрые варианты, как в планировщике срока Todoist.
enum QuickDue { today, tomorrow, weekend, nextWeek }

/// Дата быстрого варианта от [today]: «На выходных» — ближайшая суббота
/// (сегодня, если суббота), «Следующая неделя» — понедельник следующей
/// недели (настройка «следующая неделя = пн», по умолчанию Todoist).
DateTime quickDueDate(QuickDue option, DateTime today) {
  final day = _day(today);
  return switch (option) {
    QuickDue.today => day,
    QuickDue.tomorrow => _plusDays(day, 1),
    QuickDue.weekend => _plusDays(day, (DateTime.saturday - day.weekday) % 7),
    QuickDue.nextWeek => _plusDays(day, 8 - day.weekday),
  };
}

/// Как подписать дату в строке задачи.
enum DueKind { overdueYesterday, overdue, today, tomorrow, thisWeek, later }

/// Вид даты [due] относительно [today]: вчера и раньше — просрочено,
/// ближайшие 6 дней — день недели, дальше — дата.
DueKind dueKind(DateTime due, DateTime today) {
  // Разница календарных дней — через UTC, где в сутках всегда 24 часа.
  DateTime utc(DateTime t) => DateTime.utc(t.year, t.month, t.day);
  final days = utc(due).difference(utc(today)).inDays;
  return switch (days) {
    -1 => DueKind.overdueYesterday,
    < 0 => DueKind.overdue,
    0 => DueKind.today,
    1 => DueKind.tomorrow,
    < 7 => DueKind.thisWeek,
    _ => DueKind.later,
  };
}

/// Срок [current] на дату [date] — выбор даты в планировщике. Время и пояс
/// сохраняются (смена даты не делает срок с поясом «плавающим»), правило
/// повторения — тоже: дата из планировщика переносит только вхождение
/// (plans/m3 «Сверка с Todoist»).
Due dueOnDate(Due? current, String date) =>
    current?.copyWith(
      date: date,
      tz: current.time == null ? null : current.tz,
    ) ??
    Due(date: date);

/// Срок [current] с временем [time] (`HH:MM`; `null` — убрать время), правило
/// повторения сохраняется.
Due dueWithTime(Due current, String? time) =>
    current.copyWith(time: time, tz: time == null ? null : current.tz);
