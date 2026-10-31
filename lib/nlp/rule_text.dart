import '../domain/models.dart';

// Текст правила повторения на языке интерфейса: «каждый пн, пт», `every 3rd
// fri`. Текст разбирается обратно в то же правило (тест «туда и обратно»,
// test/nlp/recurrence_test.dart), поэтому формы — из docs/TODOIST_SYNTAX.md
// §3.

const List<String> _rfcDays = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];
const String _workdays = 'MO,TU,WE,TH,FR';

/// Слова языка.
final class _Words {
  const _Words({
    required this.days,
    required this.months,
    required this.until,
    required this.unit,
    required this.ordinal,
    required this.every,
  });

  final List<String> days;
  final List<String> months;
  final String until;

  /// «3 дня», `3 days`; `n` = 1 — единица без числа.
  final String Function(String freq, int n) unit;

  /// Порядковое: `3rd`, `last`; «3», «последний».
  final String Function(int n) ordinal;

  /// Слово «каждый» в форме [form].
  final String Function(_Form form) every;
}

/// Род и число «каждого» перед телом: «каждый день», «каждую неделю»,
/// «каждое 27», «каждые 3 дня».
enum _Form { masculine, feminine, neuter, plural }

final _Words _en = _Words(
  days: const ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'],
  months: const [
    'jan',
    'feb',
    'mar',
    'apr',
    'may',
    'jun',
    'jul',
    'aug',
    'sep',
    'oct',
    'nov',
    'dec',
  ],
  until: 'until',
  unit: (freq, n) {
    final name = switch (freq) {
      'HOURLY' => 'hour',
      'DAILY' => 'day',
      'WEEKLY' => 'week',
      'MONTHLY' => 'month',
      _ => 'year',
    };
    return n == 1 ? name : '$n ${name}s';
  },
  ordinal: (n) {
    if (n == -1) return 'last';
    final suffix = n % 100 >= 11 && n % 100 <= 13
        ? 'th'
        : switch (n % 10) {
            1 => 'st',
            2 => 'nd',
            3 => 'rd',
            _ => 'th',
          };
    return '$n$suffix';
  },
  every: (_) => 'every',
);

/// «1 день», «2 дня», «5 дней».
String _ruPlural(int n, String one, String few, String many) {
  final mod100 = n % 100;
  final mod10 = n % 10;
  if (mod100 >= 11 && mod100 <= 14) return many;
  if (mod10 == 1) return one;
  if (mod10 >= 2 && mod10 <= 4) return few;
  return many;
}

final _Words _ru = _Words(
  days: const ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'],
  months: const [
    'янв',
    'фев',
    'мар',
    'апр',
    'мая',
    'июн',
    'июл',
    'авг',
    'сен',
    'окт',
    'ноя',
    'дек',
  ],
  until: 'до',
  unit: (freq, n) {
    final (one, few, many) = switch (freq) {
      'HOURLY' => ('час', 'часа', 'часов'),
      'DAILY' => ('день', 'дня', 'дней'),
      'WEEKLY' => ('неделю', 'недели', 'недель'),
      'MONTHLY' => ('месяц', 'месяца', 'месяцев'),
      _ => ('год', 'года', 'лет'),
    };
    return n == 1 ? one : '$n ${_ruPlural(n, one, few, many)}';
  },
  ordinal: (n) => n == -1 ? 'последний' : '$n',
  every: (form) => switch (form) {
    _Form.masculine => 'каждый',
    _Form.feminine => 'каждую',
    _Form.neuter => 'каждое',
    _Form.plural => 'каждые',
  },
);

/// Текст правила [rule] на языке [lang] (`ru` или `en`); `null` — у правила
/// нет формы текстом (например, `INTERVAL` вместе с днями месяца) — тогда
/// показывается `Due.string`.
String? ruleText(RecurrenceRule rule, String lang) {
  final w = switch (lang) {
    'ru' => _ru,
    'en' => _en,
    _ => throw ArgumentError.value(lang, 'lang', 'язык — ru или en'),
  };
  if (rule.rrule.isEmpty) return null;
  final lines = [for (final line in rule.rrule) _parts(line)];
  if (lines.any((l) => l == null)) return null;
  final until = lines.first!.remove('UNTIL');
  for (final l in lines.skip(1)) {
    if (l!.remove('UNTIL') != until) return null;
  }

  final String body;
  final _Form form;
  if (lines.length == 1) {
    final single = _single(lines.first!, w);
    if (single == null) return null;
    (body, form) = single;
  } else {
    final items = [for (final l in lines) _yearItem(l!, w)];
    if (items.any((e) => e == null)) return null;
    body = items.join(', ');
    form = _Form.neuter;
  }

  final bang = rule.fromCompletion ? '!' : '';
  final head = w.every(form);
  final end = until == null ? '' : _untilText(until, w);
  if (until != null && end.isEmpty) return null;
  return '$head$bang $body$end';
}

/// Части строки RRULE; `null` — повтор части.
Map<String, String>? _parts(String line) {
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

/// Тело одной строки правила и форма «каждого» перед ним.
(String, _Form)? _single(Map<String, String> p, _Words w) {
  final freq = p.remove('FREQ');
  final interval = int.tryParse(p.remove('INTERVAL') ?? '1');
  if (freq == null || interval == null) return null;
  final byDay = p.remove('BYDAY');
  final byMonthDay = p.remove('BYMONTHDAY');
  final bySetPos = p.remove('BYSETPOS');
  final byMonth = p.remove('BYMONTH');
  if (p.isNotEmpty) return null;

  if (byDay == null && byMonthDay == null && bySetPos == null) {
    if (byMonth != null) return null;
    final form = interval > 1
        ? _Form.plural
        : freq == 'WEEKLY'
        ? _Form.feminine
        : _Form.masculine;
    return (w.unit(freq, interval), form);
  }
  if (freq == 'WEEKLY' && byDay != null && byMonthDay == null) {
    if (bySetPos != null || byMonth != null) return null;
    if (byDay == _workdays && interval == 1) {
      return (w == _ru ? 'рабочий день' : 'workday', _Form.masculine);
    }
    final days = _dayNames(byDay, w);
    if (days == null) return null;
    if (interval == 1) return (days, _Form.masculine);
    if (interval == 2) {
      return w == _ru
          ? ('вторую $days', _Form.feminine)
          : ('other $days', _Form.masculine);
    }
    return null;
  }
  if (interval != 1) return null;
  if (freq == 'MONTHLY' && byMonth == null) {
    if (byMonthDay != null && byDay == null && bySetPos == null) {
      final days = [
        for (final d in byMonthDay.split(','))
          if (int.tryParse(d) case final n?)
            n == -1
                ? '${w.ordinal(-1)} ${w == _ru ? 'день' : 'day'}'
                : w == _ru
                ? '$n'
                : w.ordinal(n),
      ];
      // «каждый последний день», но «каждое 2, 15, 27».
      final form = byMonthDay == '-1' ? _Form.masculine : _Form.neuter;
      return (days.join(', '), form);
    }
    if (byDay == _workdays && bySetPos != null && byMonthDay == null) {
      final workday = w == _ru ? 'рабочий день' : 'workday';
      final items = [
        for (final s in bySetPos.split(','))
          if (int.tryParse(s) case final n?) '${w.ordinal(n)} $workday',
      ];
      return (items.join(', '), _Form.masculine);
    }
    if (byDay != null && bySetPos == null && byMonthDay == null) {
      final items = [for (final d in byDay.split(',')) ?_nthDay(d, w)];
      if (items.length != byDay.split(',').length) return null;
      return (items.join(', '), _Form.feminine);
    }
    return null;
  }
  if (freq == 'YEARLY' && byMonth != null) {
    final item = _yearItem({
      'FREQ': freq,
      'BYMONTH': byMonth,
      'BYMONTHDAY': ?byMonthDay,
      'BYDAY': ?byDay,
      'BYSETPOS': ?bySetPos,
    }, w);
    return item == null ? null : (item, _Form.neuter);
  }
  return null;
}

/// День года строки `FREQ=YEARLY;BYMONTH=…`: «14 янв», `jan 14`, «1 ср янв»,
/// `1st wed jan`.
String? _yearItem(Map<String, String> p, _Words w) {
  if (p['FREQ'] != 'YEARLY' || p.containsKey('INTERVAL')) return null;
  final month = int.tryParse(p['BYMONTH'] ?? '');
  if (month == null || month < 1 || month > 12) return null;
  final name = w.months[month - 1];
  final keys = p.keys.toSet()..removeAll({'FREQ', 'BYMONTH'});
  if (keys.length != 1) return null;
  if (p['BYMONTHDAY'] case final d?) {
    final day = int.tryParse(d);
    if (day == null || day < 1) return null;
    return w == _ru ? '$day $name' : '$name $day';
  }
  if (p['BYDAY'] case final d? when !d.contains(',')) {
    final nth = _nthDay(d, w);
    return nth == null ? null : '$nth $name';
  }
  return null;
}

/// `3FR` → `3rd fri`, «3 пт»; `-1FR` → `last fri`, «последнюю пт».
String? _nthDay(String entry, _Words w) {
  final m = RegExp(r'^(-?\d)(MO|TU|WE|TH|FR|SA|SU)$').firstMatch(entry);
  if (m == null) return null;
  final n = int.parse(m[1]!);
  final day = w.days[_rfcDays.indexOf(m[2]!)];
  final ordinal = n == -1 && w == _ru ? 'последнюю' : w.ordinal(n);
  return '$ordinal $day';
}

/// `MO,FR` → `mon, fri`; номер у дня — не список дней недели.
String? _dayNames(String byDay, _Words w) {
  final names = <String>[];
  for (final code in byDay.split(',')) {
    final i = _rfcDays.indexOf(code);
    if (i < 0) return null;
    names.add(w.days[i]);
  }
  return names.join(', ');
}

/// ` until jan 14 2027`, « до 14 янв 2027»; `UNTIL` с временем — пусто.
String _untilText(String until, _Words w) {
  final m = RegExp(r'^(\d{4})(\d{2})(\d{2})$').firstMatch(until);
  if (m == null) return '';
  final month = w.months[int.parse(m[2]!) - 1];
  final day = int.parse(m[3]!);
  final date = w == _ru ? '$day $month ${m[1]}' : '$month $day ${m[1]}';
  return ' ${w.until} $date';
}
