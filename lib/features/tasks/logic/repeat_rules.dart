/// Правила «Повторить» планировщика срока: готовые варианты и окно
/// «Пользовательский…». Чистые функции от даты и «сейчас» — проверяются
/// тестами на любой день.
library;

import '../../../domain/models.dart';
import '../../../domain/recurrence.dart';
import '../../../nlp/parse_context.dart';
import '../../../nlp/quick_add.dart';
import '../../../nlp/rule_text.dart';
import 'due_dates.dart';

/// Готовые варианты «Повторить» — подпись к скриншоту help «Introduction to
/// recurring dates»: Daily, Weekly, Monthly, Yearly.
enum RepeatPreset { daily, weekly, monthly, yearly }

/// Правило готового варианта [preset] от даты [anchor]. День недели, число
/// и дата записаны в правило (`BYDAY`, `BYMONTHDAY`, `BYMONTH`), как в
/// подписи пункта: перенесённое календарём вхождение после выполнения
/// возвращается к расписанию (help: «returns to its usual pattern»), а не
/// сдвигает серию на новый день.
RecurrenceRule presetRule(RepeatPreset preset, DateTime anchor) =>
    RecurrenceRule(
      rrule: [
        switch (preset) {
          RepeatPreset.daily => 'FREQ=DAILY',
          RepeatPreset.weekly =>
            'FREQ=WEEKLY;BYDAY=${_rfcDays[anchor.weekday - 1]}',
          RepeatPreset.monthly => 'FREQ=MONTHLY;BYMONTHDAY=${anchor.day}',
          RepeatPreset.yearly =>
            'FREQ=YEARLY;BYMONTH=${anchor.month};BYMONTHDAY=${anchor.day}',
        },
      ],
      fromCompletion: false,
    );

/// Единица «Каждые» окна «Пользовательский…».
enum RepeatUnit { day, week, month, year }

/// «В» у месяца: число даты срока («23-го») или её день недели по номеру
/// («4-я пт»).
enum MonthDay { date, weekday }

/// Значения окна «Пользовательский…» (help: Based on, Every, On, Ends).
final class CustomRepeat {
  const CustomRepeat({
    this.fromCompletion = false,
    this.interval = 1,
    this.unit = RepeatUnit.week,
    this.weekdays = const {},
    this.monthDay = MonthDay.date,
    this.until,
  });

  /// «По дате выполнения» (`every!`), иначе — по дате срока.
  final bool fromCompletion;

  /// «Каждые N»: 1 и больше.
  final int interval;
  final RepeatUnit unit;

  /// Дни недели (`DateTime.monday` …) у недели; пусто — день даты срока.
  final Set<int> weekdays;
  final MonthDay monthDay;

  /// Последний день серии; `null` — «Никогда».
  final DateTime? until;

  CustomRepeat copyWith({
    bool? fromCompletion,
    int? interval,
    RepeatUnit? unit,
    Set<int>? weekdays,
    MonthDay? monthDay,
    ({DateTime? date})? until,
  }) => CustomRepeat(
    fromCompletion: fromCompletion ?? this.fromCompletion,
    interval: interval ?? this.interval,
    unit: unit ?? this.unit,
    weekdays: weekdays ?? this.weekdays,
    monthDay: monthDay ?? this.monthDay,
    until: until == null ? this.until : until.date,
  );
}

const List<String> _rfcDays = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];

const Map<RepeatUnit, String> _freq = {
  RepeatUnit.day: 'DAILY',
  RepeatUnit.week: 'WEEKLY',
  RepeatUnit.month: 'MONTHLY',
  RepeatUnit.year: 'YEARLY',
};

/// Дата, от которой считаются «Повторить» и окно: дата срока [current], а без
/// срока — [today] (help: новая повторяющаяся задача начинается сегодня).
DateTime repeatAnchor(Due? current, DateTime today) =>
    parseIsoDate(current?.date ?? '') ??
    DateTime(today.year, today.month, today.day);

/// Номер дня недели [day] в его месяце: 1–4; пятый — последний (-1): пятой
/// пятницы в большинстве месяцев нет.
int weekdayOrdinal(DateTime day) {
  final n = (day.day - 1) ~/ 7 + 1;
  return n == 5 ? -1 : n;
}

/// Правило окна [c] для даты [anchor]. Дни недели — частью `BYDAY`, пока
/// правило выражается текстом («каждую вторую пн, пт»); при шаге больше двух
/// недель — серия от даты срока без дней.
RecurrenceRule customRule(CustomRepeat c, DateTime anchor) {
  final parts = ['FREQ=${_freq[c.unit]}'];
  if (c.interval > 1) parts.add('INTERVAL=${c.interval}');
  switch (c.unit) {
    case RepeatUnit.week when c.interval <= 2:
      final days = c.weekdays.isEmpty ? {anchor.weekday} : c.weekdays;
      parts.add(
        'BYDAY=${[for (final d in days.toList()..sort()) _rfcDays[d - 1]].join(',')}',
      );
    case RepeatUnit.month when c.monthDay == MonthDay.weekday:
      parts.add(
        'BYDAY=${weekdayOrdinal(anchor)}${_rfcDays[anchor.weekday - 1]}',
      );
    default:
  }
  if (c.until case final u?) {
    parts.add('UNTIL=${isoDate(u).replaceAll('-', '')}');
  }
  return RecurrenceRule(
    rrule: [parts.join(';')],
    fromCompletion: c.fromCompletion,
  );
}

/// Значения окна для правила [rule]; нет правила или окно его не выражает
/// (несколько строк, рабочие дни, числа месяца, день недели месяца не от
/// [anchor]) — неделя по дню [anchor] (решение 4А «Ход M3.7»).
CustomRepeat customFromRule(RecurrenceRule? rule, DateTime anchor) {
  final fallback = CustomRepeat(weekdays: {anchor.weekday});
  if (rule == null || rule.rrule.length != 1) return fallback;
  final parts = <String, String>{};
  for (final part in rule.rrule.single.split(';')) {
    final eq = part.indexOf('=');
    if (eq < 1) return fallback;
    parts[part.substring(0, eq)] = part.substring(eq + 1);
  }
  final unit = {
    for (final e in _freq.entries) e.value: e.key,
  }[parts.remove('FREQ')];
  final interval = int.tryParse(parts.remove('INTERVAL') ?? '1');
  // Окончание с временем окно не выражает — как и прочие формы.
  final rawUntil = parts.remove('UNTIL');
  final until = rawUntil != null && RegExp(r'^\d{8}$').hasMatch(rawUntil)
      ? DateTime(
          int.parse(rawUntil.substring(0, 4)),
          int.parse(rawUntil.substring(4, 6)),
          int.parse(rawUntil.substring(6)),
        )
      : null;
  final byDay = parts.remove('BYDAY');
  if (unit == null ||
      interval == null ||
      interval < 1 ||
      (rawUntil != null && until == null) ||
      parts.isNotEmpty) {
    return fallback;
  }
  var weekdays = <int>{};
  var monthDay = MonthDay.date;
  if (byDay != null) {
    final codes = byDay.split(',');
    if (unit == RepeatUnit.week && codes.every(_rfcDays.contains)) {
      weekdays = {for (final c in codes) _rfcDays.indexOf(c) + 1};
    } else if (unit == RepeatUnit.month &&
        byDay == '${weekdayOrdinal(anchor)}${_rfcDays[anchor.weekday - 1]}') {
      // Окно выражает только день недели даты срока: у перенесённого
      // вхождения («4-я пт» на вт 03.11) другой — «Сохранить» не должен
      // молча превратить серию в «1-й вт».
      monthDay = MonthDay.weekday;
    } else {
      return fallback;
    }
  }
  return CustomRepeat(
    fromCompletion: rule.fromCompletion,
    interval: interval,
    unit: unit,
    weekdays: unit == RepeatUnit.week && weekdays.isEmpty
        ? {anchor.weekday}
        : weekdays,
    monthDay: monthDay,
    until: until,
  );
}

/// Срок с правилом [rule]: дата — первое вхождение не раньше даты [current]
/// (без срока — сегодня), время и пояс прежние, текст правила — на языке
/// [lang]. [now] — стенное время устройства в UTC-обёртке.
///
/// `null` — правило нельзя записать: у него нет текста, который разбирается
/// обратно в то же правило (Todoist хранит повторение строкой, и его окно
/// выражается ею же), или до окончания серии нет ни одного вхождения.
Due? dueWithRule(
  Due? current,
  RecurrenceRule rule, {
  required String lang,
  required DateTime now,
}) {
  final text = ruleText(rule, lang);
  if (text == null) return null;
  final back = parseDueText(text, ParseContext(now: now, lang: lang));
  if (back?.due?.rule != rule) return null;
  final anchor = repeatAnchor(current, now);
  // Без срока — дата того же текста, введённого в поле: «every other fri»
  // начинается со второй пятницы (help), и записанная строка не расходится
  // с датой. Со сроком серия идёт от него, как «… starting <дата срока>».
  final first = current == null
      ? parseIsoDate(back!.due!.date)!
      : _firstDay(rule.rrule.single, anchor);
  final custom = customFromRule(rule, anchor);
  if (custom.until case final until? when first.isAfter(until)) return null;
  final due = (current ?? Due(date: isoDate(first))).copyWith(
    date: isoDate(first),
    string: text,
    lang: lang,
    rule: rule,
  );
  try {
    nextOccurrence(due, completedAt: now);
  } on FormatException {
    return null;
  }
  return due;
}

/// Первый день серии не раньше [anchor]: у недели с днями — ближайший из
/// них, иначе — сама дата (число и день недели месяца взяты из неё).
DateTime _firstDay(String line, DateTime anchor) {
  final byDay = RegExp(r'(?:^|;)BYDAY=([A-Z,]+)(?:;|$)').firstMatch(line);
  if (!line.startsWith('FREQ=WEEKLY') || byDay == null) return anchor;
  final days = {for (final c in byDay[1]!.split(',')) _rfcDays.indexOf(c) + 1};
  for (var i = 0; i < 7; i++) {
    final day = DateTime(anchor.year, anchor.month, anchor.day + i);
    if (days.contains(day.weekday)) return day;
  }
  return anchor;
}
