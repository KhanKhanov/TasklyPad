import 'package:rrule/rrule.dart' as rfc;

import 'models.dart';

// Следующее вхождение повторяющегося срока. Расчёт по RFC 5545 делает пакет
// `rrule` (решение 2 плана M3); здесь — правила Todoist поверх него: от
// срока или от выполнения, только будущие даты, несколько правил.
//
// Время — стенное («9:00 по часам в комнате»), обёрнутое в UTC: пакет
// работает только с UTC, а сдвиг пояса и переход на летнее время не должны
// превращать 9:00 в 8:00. Так же передаётся момент выполнения: перевести
// мгновение в стенное время пояса срока — забота вызывающего (в домене нет ни
// часов, ни базы поясов).

/// Следующее вхождение срока [due] после выполнения в [completedAt] — новый
/// срок или `null`, если серия закончилась (`UNTIL` позади).
///
/// [completedAt] — стенное время выполнения в поясе срока в UTC-обёртке
/// (`DateTime.utc` с цифрами часов в комнате); секунды не учитываются.
///
/// Правила (help «Introduction to recurring dates», plans/m3 «Сверка с
/// Todoist»):
/// - `every` — серия от текущего срока; `every!`
///   ([RecurrenceRule.fromCompletion]) — от дня выполнения, а у часового
///   правила — от минуты выполнения;
/// - только будущее: срок без времени — не раньше завтра, со временем —
///   позже [completedAt];
/// - перенесённое вхождение (решение 10А): серия считается от текущего,
///   перенесённого, срока — правило с днями (`every tue`) само возвращается
///   к расписанию, интервальное (`every 12 days`) идёт от новой даты;
/// - несколько строк RRULE — ближайшее из их вхождений;
/// - `UNTIL` включительно; «до 3 ноября» записывается концом дня
///   `UNTIL=20261103T235959Z`, иначе срок со временем в последний день не
///   вошёл бы;
/// - `every month`, `every 3 months`, `every year` (месяц или год без
///   частей BY…) от 29–31 числа прижимаются к последнему дню короткого
///   месяца (31 января → 28 февраля), а не пропускают его, как RFC (решение
///   1А «Ход M3.3»). Явное `every 31st` (`BYMONTHDAY=31`) — по RFC.
///
/// [postpone] — «Отложить»: следующее будущее вхождение после срока без
/// выполнения, поэтому и у `every!` — от срока, а не от [completedAt].
/// Просроченную задачу «Отложить» переносит на завтра (help) — это делает
/// вызывающий, не эта функция.
///
/// Новый срок — копия [due] с другими датой и временем: текст, язык, правило
/// и пояс сохраняются.
///
/// Строка правила проверяется строго ([_parseRule], SYNC_DESIGN «Проекции»):
/// чужая или битая строка из папки синхронизации не должна ни подвесить
/// расчёт, ни молча закончить серию.
///
/// [ArgumentError] — срок без правила, пустой список правил или
/// [completedAt] не в UTC-обёртке.
/// [FormatException] — неразбираемые дата, время или строка RRULE, часть
/// правила вне набора формата, часовое правило у срока без времени.
Due? nextOccurrence(
  Due due, {
  required DateTime completedAt,
  bool postpone = false,
}) {
  final rule = due.rule;
  if (rule == null) {
    throw ArgumentError.value(due, 'due', 'срок не повторяется');
  }
  if (rule.rrule.isEmpty) {
    throw ArgumentError.value(due, 'due', 'пустой список правил');
  }
  if (!completedAt.isUtc) {
    throw ArgumentError.value(
      completedAt,
      'completedAt',
      'нужно стенное время в UTC-обёртке',
    );
  }
  final rules = [for (final line in rule.rrule) _parseRule(line)];
  final hourly = rules.any((r) => r.frequency == rfc.Frequency.hourly);
  final time = due.time;
  if (hourly && time == null) {
    throw FormatException('часовое правило у срока без времени', rule.rrule);
  }

  final dueAt = _wallDateTime(due.date, time);
  final now = DateTime.utc(
    completedAt.year,
    completedAt.month,
    completedAt.day,
    completedAt.hour,
    completedAt.minute,
  );
  final today = DateTime.utc(now.year, now.month, now.day);

  // Начало серии и граница: следующее вхождение — первое строго позже неё.
  final DateTime start;
  final DateTime after;
  if (rule.fromCompletion && !postpone) {
    start = time == null
        ? today
        : hourly
        ? now
        : DateTime.utc(
            today.year,
            today.month,
            today.day,
            dueAt.hour,
            dueAt.minute,
          );
    after = start;
  } else {
    start = dueAt;
    // Срок без времени — в полночь: «позже сегодняшней полуночи» = с завтра.
    final future = time == null ? today : now;
    after = dueAt.isAfter(future) ? dueAt : future;
  }

  DateTime? next;
  for (final r in rules) {
    final candidate = _isPlainMonthStep(r)
        ? _monthStepAfter(r, start, after)
        : r
              .getInstances(start: _startNear(r, start, after), after: after)
              .firstOrNull;
    if (candidate != null && (next == null || candidate.isBefore(next))) {
      next = candidate;
    }
  }
  if (next == null) return null;
  return due.copyWith(
    date: _isoDate(next),
    time: time == null ? null : _hhmm(next),
  );
}

/// Начало серии [start], сдвинутое целыми периодами (час, день, неделя ×
/// `INTERVAL`) ближе к [after]: пакет перебирает периоды от начала по одному,
/// и срок, просроченный на годы, перебирался бы минутами. Фаза серии не
/// меняется; вхождения между началом и [after] всё равно не нужны.
DateTime _startNear(rfc.RecurrenceRule r, DateTime start, DateTime after) {
  final interval = r.interval ?? 1;
  final period = switch (r.frequency) {
    rfc.Frequency.hourly => Duration(hours: interval),
    rfc.Frequency.daily => Duration(days: interval),
    rfc.Frequency.weekly => Duration(days: 7 * interval),
    _ => null,
  };
  if (period == null) return start;
  final periods =
      after.difference(start).inMicroseconds ~/ period.inMicroseconds;
  return periods <= 0 ? start : start.add(period * periods);
}

/// Шаг месяцами или годами без частей BY…: «то же число через N месяцев».
bool _isPlainMonthStep(rfc.RecurrenceRule r) =>
    (r.frequency == rfc.Frequency.monthly ||
        r.frequency == rfc.Frequency.yearly) &&
    r.byWeekDays.isEmpty &&
    r.byMonthDays.isEmpty &&
    r.byMonths.isEmpty &&
    r.bySetPositions.isEmpty;

/// Первое вхождение «то же число через N месяцев» строго позже [after], с
/// прижатием к последнему дню короткого месяца; `null` — позже `UNTIL`.
DateTime? _monthStepAfter(
  rfc.RecurrenceRule r,
  DateTime start,
  DateTime after,
) {
  final step =
      (r.interval ?? 1) * (r.frequency == rfc.Frequency.yearly ? 12 : 1);
  DateTime at(int k) {
    final month = start.month - 1 + k * step;
    final year = start.year + month ~/ 12;
    final m = month % 12 + 1;
    final lastDay = DateTime.utc(year, m + 1, 0).day;
    return DateTime.utc(
      year,
      m,
      start.day > lastDay ? lastDay : start.day,
      start.hour,
      start.minute,
    );
  }

  // Сразу к шагу, близкому к [after]: без перебора от давнего срока.
  final behind = (after.year - start.year) * 12 + (after.month - start.month);
  var k = behind ~/ step;
  if (k < 1) k = 1;
  while (!at(k).isAfter(after)) {
    k++;
  }
  final candidate = at(k);
  final until = r.until;
  return until != null && candidate.isAfter(until) ? null : candidate;
}

// Строка правила проверяется своим кодом до пакета: проверки пакета — `assert`,
// в релизной сборке их нет, а пакет на пустом наборе вхождений перебирает
// периоды до 9999 года (`INTERVAL=0` — бесконечно). Поэтому допускаются только
// формы, которые пишет разбор по help и у которых будущее вхождение есть всегда
// (SYNC_DESIGN «Проекции»).

const Set<String> _frequencyNames = {
  'YEARLY',
  'MONTHLY',
  'WEEKLY',
  'DAILY',
  'HOURLY',
};

/// Части правила и частоты, у которых они допустимы.
const Map<String, Set<String>> _partFrequencies = {
  'FREQ': _frequencyNames,
  'INTERVAL': _frequencyNames,
  'UNTIL': _frequencyNames,
  'WKST': _frequencyNames,
  'BYDAY': {'YEARLY', 'MONTHLY', 'WEEKLY', 'DAILY'},
  'BYMONTHDAY': {'YEARLY', 'MONTHLY'},
  'BYMONTH': {'YEARLY'},
  'BYSETPOS': {'MONTHLY'},
};

const List<String> _weekDays = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];

final RegExp _byDayEntry = RegExp(r'^([+-]?\d{1,2})?(MO|TU|WE|TH|FR|SA|SU)$');
final RegExp _untilDate = RegExp(r'^(\d{4})(\d{2})(\d{2})$');
final RegExp _untilDateTime = RegExp(
  r'^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})Z$',
);

/// Наибольшее число дней в месяце `1`–`12` (февраль — 29).
const List<int> _maxMonthDays = [
  31,
  29,
  31,
  30,
  31,
  30,
  31,
  31,
  30,
  31,
  30,
  31,
];

/// Строка правила из срока (`FREQ=…`, без префикса) → правило пакета.
///
/// Допустимые формы:
/// - `INTERVAL` 1–1000;
/// - `WKST` только `MO` (другое пакет не поддерживает);
/// - `UNTIL` — существующая дата или дата-время в UTC, дата — конец этого
///   дня, иначе срок со временем в последний день не вошёл бы в серию;
/// - номер дня недели (`3TH`, `-1FR`) ±1–4 — только у месяца и у года с
///   `BYMONTH`; дни недели у дня — только при `INTERVAL` 1;
/// - `BYDAY` и `BYMONTHDAY` — не вместе; у года — только с `BYMONTH`, а
///   `BYMONTH` — только с одним из них;
/// - при `INTERVAL` > 1 число месяца — не больше самого короткого из
///   выбранных месяцев (февраль — 28): серия может попадать только в них;
/// - `BYSETPOS` — только у месяца с днями недели без номеров и не больше
///   числа таких дней в месяце (24-го рабочего дня не бывает; при
///   `INTERVAL` > 1 — по короткому месяцу).
rfc.RecurrenceRule _parseRule(String line) {
  Never fail(String why) => throw FormatException(why, line);
  final parts = <String, String>{};
  for (final part in line.split(';')) {
    final eq = part.indexOf('=');
    if (eq < 1) fail('часть «$part» без значения');
    final key = part.substring(0, eq);
    if (!_partFrequencies.containsKey(key)) {
      fail('часть $key вне набора правила срока');
    }
    if (parts.containsKey(key)) fail('часть $key повторяется');
    parts[key] = part.substring(eq + 1);
  }
  final freq = parts['FREQ'];
  if (freq == null || !_frequencyNames.contains(freq)) {
    fail('частота ${freq ?? '—'} не поддерживается');
  }
  for (final key in parts.keys) {
    if (!_partFrequencies[key]!.contains(freq)) fail('$key у $freq');
  }
  List<int> numbers(String key, int max, {bool signed = true}) {
    final value = parts[key];
    if (value == null) return const [];
    return [
      for (final item in value.split(','))
        switch (int.tryParse(item)) {
          final n? when n != 0 && n.abs() <= max && (signed || n > 0) => n,
          _ => fail('$key: «$item» вне допустимого'),
        },
    ];
  }

  final intervals = numbers('INTERVAL', 1000, signed: false);
  if (intervals.length > 1) fail('INTERVAL — одно число');
  final interval = intervals.firstOrNull ?? 1;
  if (parts['WKST'] case final wkst? when wkst != 'MO') {
    fail('WKST только MO');
  }
  final byMonth = numbers('BYMONTH', 12, signed: false);
  final byMonthDay = numbers('BYMONTHDAY', 31);
  final bySetPos = numbers('BYSETPOS', 31);
  final dayEntries = [
    for (final item in (parts['BYDAY'] ?? '').split(','))
      if (item.isNotEmpty)
        _byDayEntry.firstMatch(item) ?? fail('BYDAY: «$item»'),
  ];
  final ordinals = [
    for (final m in dayEntries)
      if (m.group(1) case final n?) int.parse(n),
  ];
  if (freq == 'YEARLY' &&
      (byMonthDay.isNotEmpty || dayEntries.isNotEmpty) &&
      byMonth.isEmpty) {
    fail('день у года — только с BYMONTH');
  }
  if (ordinals.isNotEmpty) {
    if (freq != 'MONTHLY' && freq != 'YEARLY') {
      fail('номер дня недели у $freq');
    }
    if (ordinals.any((n) => n == 0 || n.abs() > 4)) {
      fail('номер дня недели — ±1…4');
    }
  }
  if (byMonth.isNotEmpty && byMonthDay.isNotEmpty) {
    final longest = byMonth
        .map((m) => _maxMonthDays[m - 1])
        .reduce((a, b) => a > b ? a : b);
    if (byMonthDay.every((d) => d.abs() > longest)) {
      fail('таких чисел нет в этих месяцах');
    }
  }
  if (dayEntries.isNotEmpty && byMonthDay.isNotEmpty) {
    // Фильтры пересекаются: «15-е и первый понедельник» не бывает никогда.
    fail('BYDAY вместе с BYMONTHDAY');
  }
  if (byMonth.isNotEmpty && byMonthDay.isEmpty && dayEntries.isEmpty) {
    // Пакет взял бы число срока: от 31 октября «каждый февраль» — 31 февраля.
    fail('BYMONTH — только с числом или днём недели');
  }
  if (freq == 'DAILY' && dayEntries.isNotEmpty && interval > 1) {
    // Шаг в 7 дней всегда на тот же день недели — мимо выбранных.
    fail('дни недели у дня — только при INTERVAL 1');
  }
  if (interval > 1 && byMonthDay.isNotEmpty) {
    // Серия может попадать только в одни и те же месяцы: число должно быть в
    // любом из них (февраль — 28, високосный год тоже можно пропустить).
    final shortest = byMonth.isEmpty
        ? 28
        : byMonth
              .map((m) => m == 2 ? 28 : _maxMonthDays[m - 1])
              .reduce((a, b) => a < b ? a : b);
    if (byMonthDay.any((d) => d.abs() > shortest)) {
      fail('число больше $shortest при INTERVAL > 1');
    }
  }
  if (bySetPos.isNotEmpty) {
    if (dayEntries.isEmpty || ordinals.isNotEmpty) {
      fail('BYSETPOS — только с днями недели без номеров');
    }
    final days = {for (final m in dayEntries) _weekDays.indexOf(m.group(2)!)};
    // При INTERVAL > 1 серия может попадать только в короткие месяцы, где
    // каждого дня недели ровно 4.
    final limit = interval > 1 ? 4 * days.length : _maxWeekdaysInMonth(days);
    if (bySetPos.any((n) => n.abs() > limit)) {
      fail('BYSETPOS больше числа таких дней в месяце');
    }
  }
  // UNTIL — отдельно: пакет читал бы его местным временем устройства, и в
  // ночь перевода часов 02:30 стало бы 03:30.
  DateTime? until;
  if (parts.remove('UNTIL') case final value?) {
    until = _untilValue(value) ?? fail('UNTIL: «$value»');
  }

  final text = [for (final e in parts.entries) '${e.key}=${e.value}'].join(';');
  final rfc.RecurrenceRule parsed;
  try {
    parsed = rfc.RecurrenceRule.fromString('RRULE:$text');
  } on FormatException {
    rethrow;
  } on AssertionError {
    // Сработала проверка пакета, которой нет в релизной сборке, — пробел
    // своей проверки: пусть падает тест, а не превращается в FormatException.
    rethrow;
  } on Object catch (e) {
    // Пакет на части мусора падает не FormatException, а RangeError.
    fail('строка RRULE не разобрана: $e');
  }
  return until == null ? parsed : parsed.copyWith(until: until);
}

/// `UNTIL` правила в UTC-обёртке: дата — конец дня; `null` — нет такой даты
/// или времени (31 ноября пакет молча перенёс бы на 1 декабря).
DateTime? _untilValue(String value) {
  final date = _untilDate.firstMatch(value);
  final m = date ?? _untilDateTime.firstMatch(value);
  if (m == null) return null;
  final n = [for (var i = 1; i <= m.groupCount; i++) int.parse(m.group(i)!)];
  final time = date == null ? n.sublist(3) : const [0, 0, 0];
  final at = DateTime.utc(n[0], n[1], n[2], time[0], time[1], time[2]);
  final exists =
      at.month == n[1] &&
      at.day == n[2] &&
      at.hour == time[0] &&
      at.minute == time[1] &&
      at.second == time[2];
  if (!exists) return null;
  return date != null ? DateTime.utc(n[0], n[1], n[2], 23, 59, 59) : at;
}

/// Сколько раз дни недели [days] (0 — пн) встречаются в 31-дневном месяце
/// при лучшем для них первом дне: каждый 4 раза и ещё раз — те, что попали в
/// три «лишних» дня.
int _maxWeekdaysInMonth(Set<int> days) {
  var best = 0;
  for (var first = 0; first < 7; first++) {
    final extra = {for (var i = 0; i < 3; i++) (first + i) % 7};
    final count = 4 * days.length + days.intersection(extra).length;
    if (count > best) best = count;
  }
  return best;
}

final RegExp _datePattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
final RegExp _timePattern = RegExp(r'^(\d{2}):(\d{2})$');

/// Срок `YYYY-MM-DD` и `HH:MM` (или `null` — полночь) — стенное время в
/// UTC-обёртке.
DateTime _wallDateTime(String date, String? time) {
  final d = _datePattern.firstMatch(date);
  if (d == null) throw FormatException('дата срока', date);
  final t = time == null ? null : _timePattern.firstMatch(time);
  if (time != null && t == null) throw FormatException('время срока', time);
  int part(RegExpMatch? m, int i) => m == null ? 0 : int.parse(m.group(i)!);
  final result = DateTime.utc(
    part(d, 1),
    part(d, 2),
    part(d, 3),
    part(t, 1),
    part(t, 2),
  );
  // DateTime молча переносит 31 ноября на 1 декабря — такой срок неверен.
  if (result.month != part(d, 2) ||
      result.day != part(d, 3) ||
      result.hour != part(t, 1)) {
    throw FormatException('срок вне календаря', '$date ${time ?? ''}');
  }
  return result;
}

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

String _hhmm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:'
    '${d.minute.toString().padLeft(2, '0')}';
