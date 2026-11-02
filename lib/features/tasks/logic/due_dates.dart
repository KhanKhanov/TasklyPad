/// Даты срока для интерфейса: быстрые варианты выбора и вид даты в строке
/// задачи. Чистые функции от «сегодня» — без часов внутри, поэтому
/// проверяются тестами на любой день.
library;

import '../../../domain/models.dart';
import '../../../domain/recurrence.dart';

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

/// Цвет срока в строке задачи (help «Introduction to dates and time»).
enum DueTone { overdue, today, tomorrow, nextWeek, none }

/// Цвет срока [due] относительно [today]: просрочено — красный, как и
/// сегодня, когда время срока [timePassed] прошло; сегодня — зелёный;
/// завтра — коричневый; через 2–7 дней — фиолетовый; дальше — без цвета.
DueTone dueTone(DateTime due, DateTime today, {bool timePassed = false}) {
  DateTime utc(DateTime t) => DateTime.utc(t.year, t.month, t.day);
  final days = utc(due).difference(utc(today)).inDays;
  return switch (days) {
    < 0 => DueTone.overdue,
    0 => timePassed ? DueTone.overdue : DueTone.today,
    1 => DueTone.tomorrow,
    <= 7 => DueTone.nextWeek,
    _ => DueTone.none,
  };
}

/// Срок [current] на дату [date] — выбор даты в планировщике. Время и пояс
/// сохраняются (смена даты не делает срок с поясом «плавающим»), правило
/// повторения — тоже: дата из планировщика переносит только вхождение
/// (plans/m3 «Сверка с Todoist»). Текст неповторяющегося срока
/// ([_withoutStaleText]) сбрасывается.
Due dueOnDate(Due? current, String date) => current == null
    ? Due(date: date)
    : _withoutStaleText(
        current.copyWith(
          date: date,
          tz: current.time == null ? null : current.tz,
        ),
      );

/// Срок [current] с временем [time] (`HH:MM`; `null` — убрать время), правило
/// повторения сохраняется, текст неповторяющегося срока сбрасывается. У
/// повторяющегося меняется только ближайшее вхождение, время серии
/// запоминается в [Due.seriesTime] (help «Introduction to recurring dates»,
/// решения 1А и 2А по О-65); у часового правила время — начало отсчёта, и
/// меняется вся серия (решение 3А). [wholeSeries] — время всей серии: у
/// задачи из быстрого добавления вхождений ещё не было (решение А по О-65).
Due dueWithTime(Due current, String? time, {bool wholeSeries = false}) {
  final rule = current.rule;
  final keepsSeries = !wholeSeries && rule != null && !hasHourlyRule(rule);
  final series = keepsSeries ? current.seriesClock : null;
  return _withoutStaleText(
    current.copyWith(
      time: time,
      // Пояс уходит, только когда времени нет ни у вхождения, ни у серии.
      tz: time == null && series == null ? null : current.tz,
      // Вхождение вернулось ко времени серии — запоминать нечего.
      seriesTime: !keepsSeries || series == time ? null : (series ?? ''),
    ),
  );
}

/// Неповторяющийся срок без `string` и `lang`: после новой даты или времени
/// введённый текст («завтра в 9») срок больше не описывает. У повторяющегося
/// текст остаётся — он описывает правило, а дата из планировщика переносит
/// только вхождение.
Due _withoutStaleText(Due due) =>
    due.isRecurring ? due : due.copyWith(string: null, lang: null);
