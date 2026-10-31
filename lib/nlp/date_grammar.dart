import '../domain/models.dart';
import '../domain/recurrence.dart';
import 'calendar.dart';
import 'lexicon.dart';
import 'parse_context.dart';
import 'scanner.dart';

// Грамматика дат и повторений — рекурсивный спуск по токенам: у каждой формы
// своя функция, которая с позиции i пробует прочесть форму и возвращает
// позицию после неё или null. Формы — docs/TODOIST_SYNTAX.md §2, §3; слова —
// lexicon_ru.dart и lexicon_en.dart.

/// Распознанный срок: участок исходной строки и значение.
final class DueMatch {
  const DueMatch({
    required this.start,
    required this.end,
    this.due,
    this.noDate = false,
  });

  /// Участок в исходной строке: [start] включительно, [end] — нет.
  final int start;
  final int end;

  /// Срок; `null` — «без срока» ([noDate]).
  final Due? due;

  /// «no date», «без срока»: срок убирается.
  final bool noDate;
}

/// Дата длиннее — не дата (help «Introduction to dates and time»).
const int maxDateLength = 150;

/// Слово грамматики: токен (или часть слитного токена, `tommorning`) и его
/// смысл по словарю.
final class _Item {
  const _Item(this.token, this.text, this.lex);
  final Token token;
  final String text;
  final Lex? lex;
}

/// Прочитанная дата: позиция после неё, день и, если есть, время.
final class _Day {
  const _Day(this.end, this.day, [this.minutes]);
  final int end;
  final DateTime day;
  final int? minutes;
}

final class _Time {
  const _Time(this.end, this.minutes);
  final int end;
  final int minutes;
}

/// Дата и время фразы: [dated] — дата названа явно, а не выведена из
/// времени («6pm» — сегодня или завтра).
final class _DateTime {
  const _DateTime(this.end, this.day, this.minutes, {required this.dated});
  final int end;
  final DateTime day;
  final int? minutes;
  final bool dated;
}

/// Тело правила после `every`: строки RRULE без `UNTIL`, время из самого
/// правила («каждое утро») и сдвиг первого вхождения на недели (`every
/// other fri` — со второй пятницы).
final class _Body {
  const _Body(this.end, this.lines, {this.minutes, this.otherWeek = false});
  final int end;
  final List<String> lines;
  final int? minutes;
  final bool otherWeek;
}

/// Элемент списка дней в правиле: `27th`, `3rd fri`, `14 jan`,
/// `15th workday`.
sealed class _RuleItem {
  const _RuleItem(this.end);
  final int end;
}

final class _MonthDayItem extends _RuleItem {
  const _MonthDayItem(super.end, this.day, {this.bare = false});
  final int day;

  /// Число без порядкового суффикса: «27», а не `27th`.
  final bool bare;
}

final class _SetPosItem extends _RuleItem {
  const _SetPosItem(super.end, this.n);
  final int n;
}

final class _WeekdayItem extends _RuleItem {
  const _WeekdayItem(super.end, this.n, this.weekday, this.month);
  final int n;
  final int weekday;
  final int? month;
}

final class _DateItem extends _RuleItem {
  const _DateItem(super.end, this.month, this.day);
  final int month;
  final int day;
}

/// Форма help, которую формат правила не выражает (О-63): вся фраза — не
/// повторение.
final class _Unsupported implements Exception {
  const _Unsupported();
}

const List<String> _rfcDays = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];
const String _workdays = 'MO,TU,WE,TH,FR';

final RegExp _isoPattern = RegExp(r'^(\d{4})[-/](\d{1,2})[-/](\d{1,2})$');
final RegExp _numericDate = RegExp(
  r'^(\d{1,2})([./])(\d{1,2})(?:[./](\d{2,4}))?$',
);
final RegExp _clockPattern = RegExp(r'^(\d{1,2}):(\d{2})$');
final RegExp _numberPattern = RegExp(r'^(\+?)(\d+)-?(\p{L}*)$', unicode: true);

const Set<String> _ordinalSuffixes = {
  'st',
  'nd',
  'rd',
  'th',
  'е',
  'й',
  'я',
  'ю',
  'го',
  'ое',
  'ий',
  'ая',
  'ого',
};

/// Число токена: `27`, `27th`, `27-е`, `+5`, `7pm` или число словом.
final class _Number {
  const _Number(this.value, this.suffix, {required this.plus});
  final int value;
  final String suffix;
  final bool plus;

  bool get plain => suffix.isEmpty && !plus;
  bool get ordinal => !plus && _ordinalSuffixes.contains(suffix);
}

/// Грамматика дат над токенами строки (scanner.dart).
final class DateGrammar {
  DateGrammar(List<Token> tokens, this.ctx, {this.field = false, this.timeHint})
    : _lexicon = Lexicon.of(ctx.lang) {
    for (final token in tokens) {
      final parts = _lexicon.expansions[token.text] ?? [token.text];
      for (final part in parts) {
        _items.add(_Item(token, part, _lexicon.words[part]));
      }
    }
  }

  final ParseContext ctx;

  /// Строка поля срока планировщика: число без слова — день месяца.
  final bool field;

  /// Время повторения без своего времени — из отрезка `9:30-10:00` в той же
  /// строке: первое вхождение считается уже с ним.
  final int? timeHint;

  /// Конец фразы после `every` с токена [i]: слова словаря, числа, даты,
  /// время, запятые; `null` — с [i] не `every`. Если повторение не
  /// разобралось («every 27th and 3rd fri», `every day starting dec 1 until
  /// nov 15`), дата внутри этой фразы — не срок.
  int? everyPhraseEnd(int i) {
    if (_lex(i) is! EveryLex) return null;
    var j = i + 1;
    if (_bang(j)) j++;
    // Предлог сразу после `every` — уже не правило: «каждую в пятницу» —
    // «каждую» текстом и срок «в пятницу».
    final first = _key(j);
    if (first == Key.at || first == Key.on || first == Key.and) return j;
    while (j < length && (_lex(j) != null || _ruleChar.hasMatch(_text(j)!))) {
      j++;
    }
    return j;
  }

  static final RegExp _ruleChar = RegExp(r'^[\d,!+]');

  final Lexicon _lexicon;
  final List<_Item> _items = [];

  int get length => _items.length;

  Token tokenAt(int i) => _items[i].token;

  /// Нормализованное слово [i] (часть слитного токена — своё).
  String textAt(int i) => _items[i].text;

  /// Срок, который начинается с токена [i]: самая длинная из форм —
  /// повторение, дата со временем, «без срока».
  DueMatch? matchAt(int i) {
    if (i >= length) return null;
    DueMatch? best;
    void consider(int? end, Due? due, {bool noDate = false}) {
      if (end == null || end <= i) return;
      if (best != null && _items[end - 1].token.end <= best!.end) return;
      final start = _items[i].token.start;
      final stop = _items[end - 1].token.end;
      if (stop - start > maxDateLength) return;
      best = DueMatch(start: start, end: stop, due: due, noDate: noDate);
    }

    final rule = _recurrence(i);
    if (rule != null) consider(rule.$1, rule.$2);
    final date = _dateTime(i);
    // Срок хранится как `YYYY-MM-DD`: `in 9999 years` — не дата.
    if (date != null && date.day.year >= 1 && date.day.year <= 9999) {
      consider(
        date.end,
        Due(date: isoDate(date.day), time: _hhmmOrNull(date.minutes)),
      );
    }
    consider(_noDate(i), null, noDate: true);
    return best;
  }

  /// Конец формы напоминания с токена [i] (`14:00`, `завтра 9:00`, `30 min
  /// before`, «за 30 мин»): напоминание не разбирается как срок.
  int? reminderEnd(int i) {
    final date = _dateTime(i);
    var k = i;
    if (_key(k) == Key.ahead) k++;
    final n = _number(k);
    final relative = n != null && n.plain && _unit(k + 1) != null
        ? k + 2 + (_key(k + 2) == Key.before ? 1 : 0)
        : null;
    final ends = [?date?.end, ?relative];
    return ends.isEmpty ? null : ends.reduce((a, b) => a > b ? a : b);
  }

  // --- Слова -----------------------------------------------------------------

  Lex? _lex(int i) => i < length ? _items[i].lex : null;

  Key? _key(int i) => switch (_lex(i)) {
    KeyLex(:final key) => key,
    _ => null,
  };

  String? _text(int i) => i < length ? _items[i].text : null;

  Unit? _unit(int i) => switch (_lex(i)) {
    UnitLex(:final unit) => unit,
    _ => null,
  };

  int? _weekday(int i) => switch (_lex(i)) {
    WeekdayLex(:final weekday) => weekday,
    _ => null,
  };

  int? _month(int i) => switch (_lex(i)) {
    MonthLex(:final month) => month,
    _ => null,
  };

  _Number? _number(int i) {
    final lex = _lex(i);
    if (lex is NumberLex) return _Number(lex.n, '', plus: false);
    final text = _text(i);
    if (text == null) return null;
    final m = _numberPattern.firstMatch(text);
    if (m == null || m[2]!.length > 4) return null;
    return _Number(int.parse(m[2]!), m[3]!, plus: m[1]!.isNotEmpty);
  }

  /// `!` вплотную к предыдущему слову: `every!`, «каждые!».
  bool _bang(int i) => i > 0 && _text(i) == '!' && _items[i].token.glued;

  /// Год `2027` после даты.
  int? _year(int i) {
    final n = _number(i);
    if (n == null || !n.plain || _text(i)!.length != 4) return null;
    return n.value;
  }

  /// Минуты части суток.
  int? _dayPart(int i) => switch (_key(i)) {
    Key.morning => 9 * 60,
    Key.afternoon || Key.noon => 12 * 60,
    Key.evening => 19 * 60,
    Key.night => 22 * 60,
    _ => null,
  };

  int? _phrase(int i, List<String> words) {
    for (var w = 0; w < words.length; w++) {
      if (_text(i + w) != words[w]) return null;
    }
    return i + words.length;
  }

  // --- «Без срока» и праздники ------------------------------------------------

  int? _noDate(int i) {
    for (final words in _lexicon.noDate) {
      final end = _phrase(i, words);
      if (end != null) return end;
    }
    return null;
  }

  /// Праздник: самая длинная фраза.
  (int, Holiday)? _holiday(int i) {
    (int, Holiday)? best;
    for (final h in _lexicon.holidays) {
      final end = _phrase(i, h.words);
      if (end != null && (best == null || end > best.$1)) best = (end, h);
    }
    return best;
  }

  // --- Дата и время -----------------------------------------------------------

  /// Дата и время в любом порядке, каждое не больше одного раза; хотя бы
  /// одно. Время без даты — сегодня, а если прошло — завтра (help: `6pm`).
  _DateTime? _dateTime(int i) {
    _Day? date;
    _Time? time;
    var k = i;
    for (;;) {
      if (date == null) {
        final d = _date(k);
        if (d != null) {
          date = d;
          k = d.end;
          if (d.minutes != null) break;
          continue;
        }
      }
      if (time == null) {
        final t = _time(k, afterDate: date != null);
        if (t != null) {
          time = t;
          k = t.end;
          continue;
        }
      }
      break;
    }
    if (date != null) {
      return _DateTime(k, date.day, date.minutes ?? time?.minutes, dated: true);
    }
    if (time == null) return null;
    final today = ctx.today;
    final day = time.minutes > ctx.nowMinutes ? today : addDays(today, 1);
    return _DateTime(k, day, time.minutes, dated: false);
  }

  /// Дата, с предлогом «в», «на», `on` или без него.
  _Day? _date(int i) {
    final bare = _dateCore(i, prefixed: false);
    final key = _key(i);
    if (key == Key.at || key == Key.on) {
      final withPrefix = _dateCore(i + 1, prefixed: true);
      if (withPrefix != null && (bare == null || withPrefix.end > bare.end)) {
        return withPrefix;
      }
    }
    return bare;
  }

  /// Самая длинная из форм даты с токена [i].
  _Day? _dateCore(int i, {required bool prefixed}) {
    if (i >= length) return null;
    _Day? best;
    for (final d in [
      _simpleDay(i),
      _nextDay(i),
      _thisDay(i, prefixed: prefixed),
      _relative(i),
      _offset(i),
      _holidayDay(i),
      _endOrMid(i),
      _absolute(i),
      _nthWeekdayOfMonth(i),
      _weekdayDay(i),
      _bareMonthDay(i),
    ]) {
      if (d != null && (best == null || d.end > best.end)) best = d;
    }
    return best;
  }

  _Day? _simpleDay(int i) {
    final today = ctx.today;
    final day = switch (_key(i)) {
      Key.today => today,
      Key.tomorrow => addDays(today, 1),
      Key.overmorrow => addDays(today, 2),
      Key.yesterday => addDays(today, -1),
      Key.someday => addMonths(today, 2),
      _ => null,
    };
    return day == null ? null : _Day(i + 1, day);
  }

  DateTime get _thisWeekend {
    final today = ctx.today;
    return addDays(today, (ctx.weekendDay - today.weekday + 7) % 7);
  }

  /// `next week`, `next month`, `next year`, `next friday`, `next weekend`.
  _Day? _nextDay(int i) {
    if (_key(i) != Key.next) return null;
    final today = ctx.today;
    final weekday = _weekday(i + 1);
    if (weekday != null) {
      // Help: день этой недели ещё впереди — тот же день следующей недели,
      // уже прошёл (или сегодня) — ближайший.
      final day = weekday > today.weekday
          ? addDays(today, weekday - today.weekday + 7)
          : nextWeekday(today, weekday);
      return _Day(i + 2, day);
    }
    if (_key(i + 1) == Key.weekend) {
      return _Day(i + 2, addDays(_thisWeekend, 7));
    }
    final day = switch (_unit(i + 1)) {
      Unit.week => addDays(today, 7 - today.weekday + ctx.nextWeekDay),
      Unit.month => addMonths(today, 1),
      Unit.year => DateTime.utc(today.year + 1),
      _ => null,
    };
    return day == null ? null : _Day(i + 2, day);
  }

  /// `this weekend`, «на выходных»; `later this week`, «на этой неделе».
  _Day? _thisDay(int i, {required bool prefixed}) {
    var k = i;
    final later = _key(k) == Key.later;
    if (later) k++;
    final current = _key(k) == Key.current;
    if (current) k++;
    if (_key(k) == Key.weekend && !later && (current || prefixed)) {
      return _Day(k + 1, _thisWeekend);
    }
    if (_unit(k) == Unit.week && current && (later || prefixed)) {
      // Допущение О-57: через 2 дня, не позже воскресенья этой недели.
      final today = ctx.today;
      final ahead = 7 - today.weekday;
      return _Day(k + 1, addDays(today, ahead < 2 ? ahead : 2));
    }
    return null;
  }

  /// `in 5 days`, `+5 days`, «через 2 часа».
  _Day? _relative(int i) {
    var k = i;
    if (_key(k) == Key.within) k++;
    final n = _number(k);
    if (n == null || n.suffix.isNotEmpty || (k == i && !n.plus)) return null;
    final unit = _unit(k + 1);
    if (unit == null) return null;
    return _shift(k + 2, unit, n.value);
  }

  /// День (и время у часов и минут) через [n] единиц от сейчас. Часы — по
  /// стенным часам: в ночь перевода `in 2 hours` на час расходится с
  /// реальным временем (как часовой шаг повторения, О-57).
  _Day _shift(int end, Unit unit, int n) {
    final today = ctx.today;
    switch (unit) {
      case Unit.minute || Unit.hour:
        final at = ctx.now.add(
          unit == Unit.hour ? Duration(hours: n) : Duration(minutes: n),
        );
        return _Day(
          end,
          DateTime.utc(at.year, at.month, at.day),
          at.hour * 60 + at.minute,
        );
      case Unit.day:
        return _Day(end, addDays(today, n));
      case Unit.week:
        return _Day(end, addDays(today, 7 * n));
      case Unit.month:
        return _Day(end, addMonths(today, n));
      case Unit.quarter:
        return _Day(end, addMonths(today, 3 * n));
      case Unit.year:
        return _Day(end, addMonths(today, 12 * n));
    }
  }

  /// `6 weeks before 21 Jul`, `28 days after 21 July`, «за 50 дней до нового
  /// года».
  _Day? _offset(int i) {
    var k = i;
    if (_key(k) == Key.ahead) k++;
    final n = _number(k);
    if (n == null || !n.plain) return null;
    final unit = _unit(k + 1);
    final direction = _key(k + 2);
    if (unit == null || (direction != Key.before && direction != Key.after)) {
      return null;
    }
    final anchor = _dateCore(k + 3, prefixed: false);
    if (anchor == null) return null;
    final sign = direction == Key.before ? -1 : 1;
    final day = switch (unit) {
      Unit.day => addDays(anchor.day, sign * n.value),
      Unit.week => addDays(anchor.day, sign * 7 * n.value),
      Unit.month => addMonths(anchor.day, sign * n.value),
      Unit.year => addMonths(anchor.day, sign * 12 * n.value),
      _ => null,
    };
    return day == null ? null : _Day(anchor.end, day);
  }

  _Day? _holidayDay(int i) {
    final h = _holiday(i);
    if (h == null) return null;
    final day = nextDayMonth(ctx.today, h.$2.month, h.$2.day);
    return day == null ? null : _Day(h.$1, day);
  }

  /// `end of month`, «конец месяца»; `mid January`, «середина января».
  _Day? _endOrMid(int i) {
    final key = _key(i);
    if (key != Key.end && key != Key.mid) return null;
    var k = i + 1;
    if (_key(k) == Key.of) k++;
    final today = ctx.today;
    if (key == Key.end && _unit(k) == Unit.month) {
      final last = daysInMonth(today.year, today.month);
      return _Day(k + 1, DateTime.utc(today.year, today.month, last));
    }
    final month = _month(k);
    if (key == Key.mid && month != null) {
      final day = nextDayMonth(today, month, 15);
      return day == null ? null : _Day(k + 1, day);
    }
    return null;
  }

  /// `2023-01-27`, `27/1`, `01/27/2023`, `27 jan`, `jan 27 2028`, `27th`.
  _Day? _absolute(int i) {
    final text = _text(i);
    if (text == null) return null;
    final iso = _isoPattern.firstMatch(text);
    if (iso != null) {
      final day = calendarDate(
        int.parse(iso[1]!),
        int.parse(iso[2]!),
        int.parse(iso[3]!),
      );
      return day == null ? null : _Day(i + 1, day);
    }
    final numeric = _numericDate.firstMatch(text);
    if (numeric != null) return _numericDay(i, numeric);

    final n = _number(i);
    final month = _month(i);
    if (n != null && !n.plus && (n.plain || n.ordinal)) {
      final m = _month(i + 1);
      if (m != null) return _dayMonth(i + 2, m, n.value);
      if (n.ordinal) return _monthDay(i + 1, n.value);
    }
    if (month != null) {
      final d = _number(i + 1);
      if (d != null && (d.plain || d.ordinal)) {
        return _dayMonth(i + 2, month, d.value);
      }
    }
    return null;
  }

  _Day? _numericDay(int i, RegExpMatch m) {
    // Через точку — только месяц двумя цифрами (`27.01`): «1.5 литра» — не
    // дата.
    if (m[2] == '.' && m[3]!.length != 2) return null;
    var (day, month) = (int.parse(m[1]!), int.parse(m[3]!));
    // `/`: день/месяц, а если второе больше 12 — месяц/день (`01/27/2023`).
    if (m[2] == '/' && day <= 12 && month > 12) (day, month) = (month, day);
    final yearText = m[4];
    if (yearText == null) {
      final date = nextDayMonth(ctx.today, month, day);
      return date == null ? null : _Day(i + 1, date);
    }
    var year = int.parse(yearText);
    if (yearText.length == 2) year += 2000;
    final date = calendarDate(year, month, day);
    return date == null ? null : _Day(i + 1, date);
  }

  /// День [day] месяца [month]: с годом после него — тот год, иначе
  /// ближайшая будущая дата.
  _Day? _dayMonth(int end, int month, int day) {
    final year = _year(end);
    if (year != null) {
      final date = calendarDate(year, month, day);
      return date == null ? null : _Day(end + 1, date);
    }
    final date = nextDayMonth(ctx.today, month, day);
    return date == null ? null : _Day(end, date);
  }

  /// Ближайшее [day]-е число не раньше сегодня.
  _Day? _monthDay(int end, int day) {
    if (day < 1 || day > 31) return null;
    var month = DateTime.utc(ctx.today.year, ctx.today.month);
    for (var k = 0; k < 12; k++) {
      final date = calendarDate(month.year, month.month, day);
      if (date != null && !date.isBefore(ctx.today)) return _Day(end, date);
      month = addMonths(month, 1);
    }
    return null;
  }

  /// `3rd friday jan`, «3 пятница янв» — ближайший такой день.
  _Day? _nthWeekdayOfMonth(int i) {
    final n = _ordinalAt(i);
    if (n == null) return null;
    final weekday = _weekday(i + 1);
    if (weekday == null) return null;
    var k = i + 2;
    if (_key(k) == Key.of) k++;
    final month = _month(k);
    if (month == null) return null;
    for (var year = ctx.today.year; year <= ctx.today.year + 1; year++) {
      final day = nthWeekday(year, month, weekday, n);
      if (day != null && !day.isBefore(ctx.today)) return _Day(k + 1, day);
    }
    return null;
  }

  /// Порядковый номер: `3rd`, «3», `first`, «последний» (-1).
  int? _ordinalAt(int i) {
    final lex = _lex(i);
    if (lex is OrdinalLex) return lex.n;
    final n = _number(i);
    if (n == null || !(n.plain || n.ordinal) || n.value < 1 || n.value > 5) {
      return null;
    }
    return n.value;
  }

  _Day? _weekdayDay(int i) {
    final weekday = _weekday(i);
    return weekday == null
        ? null
        : _Day(i + 1, nextWeekday(ctx.today, weekday));
  }

  /// Число без слова — день месяца, только в поле срока: в названии «Купить
  /// 6 яиц» — не дата (допущение О-57).
  _Day? _bareMonthDay(int i) {
    if (!field) return null;
    final n = _number(i);
    if (n == null || !n.plain || _lex(i) is NumberLex) return null;
    return _monthDay(i + 1, n.value);
  }

  /// Время: `19:00`, `7pm`, `4 pm`, «9 утра», `at 10`, `at 1900`, `noon`,
  /// `in the morning`, «вечером»; после даты — и `morning` (`tom morning`).
  _Time? _time(int i, {required bool afterDate}) {
    var k = i;
    final at = _key(k) == Key.at;
    if (at) k++;
    final text = _text(k);
    if (text == null) return null;

    final clock = _clockPattern.firstMatch(text);
    if (clock != null) {
      var h = int.parse(clock[1]!);
      final m = int.parse(clock[2]!);
      if (h > 23 || m > 59) return null;
      if (_lex(k + 1) case MeridiemLex(:final pm) when h >= 1 && h <= 12) {
        h = _withMeridiem(h, pm: pm);
        return _Time(k + 2, h * 60 + m);
      }
      return _Time(k + 1, h * 60 + m);
    }

    final n = _number(k);
    if (n != null && !n.plus && _lex(k) is! NumberLex) {
      final suffix = n.suffix;
      if (const {'am', 'a', 'pm', 'p'}.contains(suffix)) {
        if (n.value < 1 || n.value > 12) return null;
        final pm = suffix.startsWith('p');
        return _Time(k + 1, _withMeridiem(n.value, pm: pm) * 60);
      }
      if (suffix.isEmpty) {
        if (_lex(k + 1) case MeridiemLex(:final pm)
            when n.value >= 1 && n.value <= 12) {
          return _Time(k + 2, _withMeridiem(n.value, pm: pm) * 60);
        }
        if (at && text.length == 4 && _lexicon.clockWithoutColon) {
          final h = n.value ~/ 100;
          final m = n.value % 100;
          return h > 23 || m > 59 ? null : _Time(k + 1, h * 60 + m);
        }
        if (at && text.length <= 2 && n.value <= 23) {
          // Без am/pm 1–6 — после полудня: «завтра в 4» = 16:00 (help ru;
          // общее правило — допущение О-57).
          final h = n.value >= 1 && n.value <= 6 ? n.value + 12 : n.value;
          return _Time(k + 1, h * 60);
        }
      }
      return null;
    }

    if (_key(k) == Key.noon) return _Time(k + 1, 12 * 60);
    if (at) return null;
    if (_key(k) == Key.within && _key(k + 1) == Key.the) {
      final part = _dayPart(k + 2);
      if (part != null) return _Time(k + 3, part);
    }
    final part = _dayPart(k);
    if (part != null && (afterDate || _lexicon.bareDayParts.contains(text))) {
      return _Time(k + 1, part);
    }
    return null;
  }

  static int _withMeridiem(int h, {required bool pm}) =>
      pm ? (h == 12 ? 12 : h + 12) : (h == 12 ? 0 : h);

  // --- Повторения ------------------------------------------------------------

  /// Повторение с токена [i]: позиция после него и срок с правилом.
  (int, Due)? _recurrence(int i) {
    _Body? body;
    var fromCompletion = false;
    var needsStart = false;
    final lex = _lex(i);
    try {
      if (lex is EveryLex) {
        var k = i + 1;
        if (_bang(k)) {
          fromCompletion = true;
          k++;
        }
        body = _everyBody(k);
      } else if (lex is FrequencyLex) {
        body = _unitBody(i + 1, lex.unit, 1);
      } else if ((_key(i) == Key.after && _lexicon.afterIsFromCompletion) ||
          (_key(i) == Key.within && _lexicon.withinStartingIsFromCompletion)) {
        // `after 10 days` = `every! 10 days` (help en); «через 10 дней
        // начиная с …» — так же (help ru), а без начала это дата (решение 7А).
        final n = _number(i + 1);
        final unit = _unit(i + 2);
        if (n != null && n.plain && unit != null && unit != Unit.minute) {
          body = _unitBody(i + 3, unit, n.value);
          fromCompletion = true;
          needsStart = _key(i) == Key.within;
        }
      }
    } on _Unsupported {
      return null;
    }
    if (body == null) return null;

    // Уточнения в любом порядке: время, начало, конец, «в течение».
    var k = body.end;
    var minutes = body.minutes;
    DateTime? start;
    _EndSpec? ending;
    for (;;) {
      if (minutes == null) {
        final t = _time(k, afterDate: true);
        if (t != null) {
          minutes = t.minutes;
          k = t.end;
          continue;
        }
      }
      if (start == null && _key(k) == Key.starting) {
        var j = k;
        while (_key(j) == Key.starting || _key(j) == Key.on) {
          j++;
        }
        final at = _dateTime(j);
        if (at != null) {
          if (at.dated) start = at.day;
          start ??= ctx.today;
          minutes ??= at.minutes;
          k = at.end;
          continue;
        }
      }
      if (ending == null) {
        final e = _ending(k);
        if (e != null) {
          ending = e;
          k = e.end;
          continue;
        }
      }
      break;
    }
    if (needsStart && start == null) return null;

    final from = start ?? ctx.today;
    final until = ending?.until(from);
    final lines = [
      for (final line in body.lines)
        until == null ? line : '$line;UNTIL=${untilDate(until)}',
    ];
    minutes ??= timeHint;
    if (lines.first.startsWith('FREQ=HOURLY')) minutes ??= ctx.nowMinutes;
    final first = _firstOccurrence(
      lines,
      from: from,
      minutes: minutes,
      until: until,
      skipWeek: body.otherWeek && start == null,
    );
    if (first == null) return null;
    final due = Due(
      date: isoDate(first.$1),
      time: _hhmmOrNull(first.$2),
      rule: RecurrenceRule(rrule: lines, fromCompletion: fromCompletion),
    );
    try {
      // Строгая проверка формата правила (SYNC_DESIGN «Проекции»): разбор не
      // пишет строку, которую не примет расчёт следующего вхождения.
      nextOccurrence(due, completedAt: ctx.now);
    } on FormatException {
      return null;
    }
    return (k, due);
  }

  /// Тело после `every`: `day`, `3 days`, `other week`, `mon, fri`,
  /// `workday`, `weekend`, `morning`, список дней месяца или года.
  _Body? _everyBody(int k) {
    if (_key(k) == Key.other) {
      final unit = _unit(k + 1);
      if (unit != null) return _unitBody(k + 2, unit, 2);
      final days = _weekdayList(k + 1);
      if (days == null) return null;
      return _Body(days.$1, [
        'FREQ=WEEKLY;INTERVAL=2;BYDAY=${days.$2.join(',')}',
      ], otherWeek: true);
    }
    final n = _number(k);
    if (n != null && n.plain) {
      final unit = _unit(k + 1);
      if (unit != null) return _unitBody(k + 2, unit, n.value);
    }
    final unit = _unit(k);
    if (unit != null) return _unitBody(k + 1, unit, 1);
    final lex = _lex(k);
    if (lex is WorkdayLex && !lex.plural) {
      final end = _unit(k + 1) == Unit.day ? k + 2 : k + 1;
      return _Body(end, ['FREQ=WEEKLY;BYDAY=$_workdays']);
    }
    if (_key(k) == Key.weekend) {
      return _Body(k + 1, [
        'FREQ=WEEKLY;BYDAY=${_rfcDays[ctx.weekendDay - 1]}',
      ]);
    }
    final part = _dayPart(k);
    if (part != null) return _Body(k + 1, ['FREQ=DAILY'], minutes: part);
    final days = _weekdayList(k);
    if (days != null) {
      return _Body(days.$1, ['FREQ=WEEKLY;BYDAY=${days.$2.join(',')}']);
    }
    return _itemsBody(k);
  }

  _Body? _unitBody(int end, Unit unit, int n) {
    if (n < 1 || n > 1000) return null;
    final (freq, interval) = switch (unit) {
      Unit.minute => (null, n),
      Unit.hour => ('HOURLY', n),
      Unit.day => ('DAILY', n),
      Unit.week => ('WEEKLY', n),
      Unit.month => ('MONTHLY', n),
      Unit.quarter => ('MONTHLY', 3 * n),
      Unit.year => ('YEARLY', n),
    };
    if (freq == null) return null;
    final line = interval == 1 ? 'FREQ=$freq' : 'FREQ=$freq;INTERVAL=$interval';
    return _Body(end, [line]);
  }

  /// `mon, fri`, `monday, friday`, `mon, tues, wed, and fri`: позиция после
  /// списка и дни RFC.
  (int, List<String>)? _weekdayList(int k) {
    final first = _weekday(k);
    if (first == null) return null;
    final days = [_rfcDays[first - 1]];
    var end = k + 1;
    for (;;) {
      var j = end;
      if (_text(j) == ',') j++;
      if (_key(j) == Key.and) j++;
      final next = _weekday(j);
      if (j == end || next == null) break;
      final code = _rfcDays[next - 1];
      if (!days.contains(code)) days.add(code);
      end = j + 1;
    }
    return (end, days);
  }

  /// Список дней месяца или года через запятую: `2, 15, 27`, `27th`,
  /// `last day`, `15th workday, first workday`, `3rd fri`, `1st wed jan, 3rd
  /// thu jul`, `14 jan, 14 apr`, `halloween`.
  _Body? _itemsBody(int k) {
    final items = <_RuleItem>[];
    var end = k;
    for (;;) {
      var j = end;
      if (items.isNotEmpty) {
        if (_text(j) == ',') j++;
        if (_key(j) == Key.and) j++;
        if (j == end) break;
      }
      final item = _ruleItem(j);
      if (item == null) break;
      items.add(item);
      end = item.end;
    }
    if (items.isEmpty) return null;

    if (items.every((e) => e is _MonthDayItem)) {
      // Одно число без суффикса — день месяца только там, где так в help
      // («каждое 27»); `Water every 3 plants` — текст, `every 27th` и
      // `every 2, 15, 27` — правило.
      if (items case [_MonthDayItem(bare: true)]
          when !_lexicon.bareNumberIsMonthDay) {
        return null;
      }
      final days = [for (final e in items) (e as _MonthDayItem).day];
      return _Body(end, ['FREQ=MONTHLY;BYMONTHDAY=${days.join(',')}']);
    }
    if (items.every((e) => e is _SetPosItem)) {
      final positions = [for (final e in items) (e as _SetPosItem).n];
      return _Body(end, [
        'FREQ=MONTHLY;BYDAY=$_workdays;BYSETPOS=${positions.join(',')}',
      ]);
    }
    if (items.every((e) => e is _WeekdayItem && e.month == null)) {
      final days = [
        for (final e in items.cast<_WeekdayItem>())
          '${e.n}${_rfcDays[e.weekday - 1]}',
      ];
      return _Body(end, ['FREQ=MONTHLY;BYDAY=${days.join(',')}']);
    }
    final lines = <String>[];
    for (final e in items) {
      switch (e) {
        case _DateItem(:final month, :final day):
          lines.add('FREQ=YEARLY;BYMONTH=$month;BYMONTHDAY=$day');
        case _WeekdayItem(:final n, :final weekday, month: final month?):
          lines.add(
            'FREQ=YEARLY;BYMONTH=$month;BYDAY=$n${_rfcDays[weekday - 1]}',
          );
        default:
          return null;
      }
    }
    return _Body(end, lines);
  }

  _RuleItem? _ruleItem(int j) {
    final holiday = _holiday(j);
    if (holiday != null) {
      return _DateItem(holiday.$1, holiday.$2.month, holiday.$2.day);
    }
    final month = _month(j);
    if (month != null) {
      final d = _number(j + 1);
      if (d == null || !(d.plain || d.ordinal)) return null;
      return _dateItem(j + 2, month, d.value);
    }
    final lex = _lex(j);
    final n = _number(j);
    final int value;
    final bool ordinal;
    if (lex is OrdinalLex) {
      (value, ordinal) = (lex.n, true);
    } else if (n != null && !n.plus && (n.plain || n.ordinal)) {
      (value, ordinal) = (n.value, n.ordinal);
    } else {
      return null;
    }

    final weekday = _weekday(j + 1);
    if (weekday != null) {
      if (value != -1 && (value < 1 || value > 4)) return null;
      var k = j + 2;
      if (_key(k) == Key.of) k++;
      final m = _month(k);
      return _WeekdayItem(m == null ? j + 2 : k + 1, value, weekday, m);
    }
    final workday = _lex(j + 1);
    if (workday is WorkdayLex) {
      final isOrdinal =
          ordinal || (!workday.plural && _lexicon.singularWorkdayIsOrdinal);
      // «Каждые N рабочих дней» в RRULE не выражается (О-63).
      if (!isOrdinal) throw const _Unsupported();
      final end = _unit(j + 2) == Unit.day ? j + 3 : j + 2;
      return value == -1 || (value >= 1 && value <= 23)
          ? _SetPosItem(end, value)
          : null;
    }
    if (value == -1) {
      return _unit(j + 1) == Unit.day ? _MonthDayItem(j + 2, -1) : null;
    }
    if (lex is OrdinalLex) return null;
    final m = _month(j + 1);
    if (m != null) return _dateItem(j + 2, m, value);
    // Число словом — не день месяца: «Thank every one of them».
    if (lex is NumberLex) return null;
    return value >= 1 && value <= 31
        ? _MonthDayItem(j + 1, value, bare: !ordinal)
        : null;
  }

  _DateItem? _dateItem(int end, int month, int day) {
    final max = month == 2 ? 29 : daysInMonth(2025, month);
    return day >= 1 && day <= max ? _DateItem(end, month, day) : null;
  }

  /// Конец серии: `ending aug 3`, `until 20 May`, «до 3 августа»,
  /// «заканчивая в субботу», `ending in 6 months`; `for 3 weeks`, «в течение
  /// 3 недель».
  _EndSpec? _ending(int k) {
    final key = _key(k);
    if (key == Key.span || (key == Key.at && _key(k + 1) == Key.span)) {
      final j = key == Key.span ? k + 1 : k + 2;
      final n = _number(j);
      final unit = _unit(j + 1);
      if (n == null || !n.plain || unit == null || n.value < 1) return null;
      if (unit == Unit.minute || unit == Unit.hour) return null;
      return _EndSpec(j + 2, span: (unit, n.value));
    }
    if (key != Key.ending && key != Key.before) return null;
    final j = k + 1;
    if (_key(j) == Key.within) {
      final n = _number(j + 1);
      final unit = _unit(j + 2);
      if (n != null && n.plain && unit != null && unit != Unit.minute) {
        return _EndSpec(j + 3, after: (unit, n.value));
      }
    }
    final date = _date(j);
    if (date == null) return null;
    return _EndSpec(date.end, day: date.day);
  }

  /// Первое вхождение серии [lines] не раньше [from] и не раньше сегодня
  /// (только будущее): у правила без частей BY… — само начало (если оно
  /// прошло — следующее по серии), у правила с днями — первый подходящий
  /// день; ближайшее из строк. `null` — до [until] вхождений нет: такая фраза
  /// — не повторение.
  (DateTime, int?)? _firstOccurrence(
    List<String> lines, {
    required DateTime from,
    required int? minutes,
    required DateTime? until,
    required bool skipWeek,
  }) {
    final time = _hhmmOrNull(minutes);
    final today = ctx.today;
    final yesterday = addDays(today, -1);
    (DateTime, int?)? best;
    for (final line in lines) {
      final parts = line.split(';');
      final byDays = parts.any((p) => p.startsWith('BY'));
      Due? next;
      try {
        if (!byDays || parts.first == 'FREQ=HOURLY') {
          final base = Due(
            date: isoDate(from),
            time: time,
            rule: RecurrenceRule(rrule: [line], fromCompletion: false),
          );
          if (minutes != null &&
              !from.isAfter(today) &&
              (from.isBefore(today) || minutes < ctx.nowMinutes)) {
            next = nextOccurrence(base, completedAt: ctx.now);
          } else if (from.isBefore(today)) {
            // От вчерашнего дня: сегодняшнее вхождение тоже будущее.
            next = nextOccurrence(base, completedAt: yesterday);
          } else {
            next = until != null && from.isAfter(until) ? null : base;
          }
        } else {
          // Без INTERVAL: первый подходящий день не зависит от шага серии,
          // шаг считается уже от него.
          final single = parts
              .where((p) => !p.startsWith('INTERVAL='))
              .join(';');
          final seed = Due(
            date: isoDate(addDays(from, -1)),
            time: time,
            rule: RecurrenceRule(rrule: [single], fromCompletion: false),
          );
          final dayBefore = addDays(from, -1);
          final completedAt = minutes != null && !from.isAfter(today)
              ? ctx.now
              : (dayBefore.isBefore(yesterday) ? yesterday : dayBefore);
          next = nextOccurrence(seed, completedAt: completedAt);
        }
      } on FormatException {
        return null;
      }
      if (next == null) continue;
      var day = DateTime.parse('${next.date}T00:00:00Z');
      if (skipWeek) {
        day = addDays(day, 7);
        if (until != null && day.isAfter(until)) continue;
      }
      final at = next.time == null ? null : _minutesOf(next.time!);
      if (best == null ||
          day.isBefore(best.$1) ||
          (day == best.$1 && (at ?? 0) < (best.$2 ?? 0))) {
        best = (day, at);
      }
    }
    return best;
  }

  static int _minutesOf(String hhmm) =>
      int.parse(hhmm.substring(0, 2)) * 60 + int.parse(hhmm.substring(3));

  static String? _hhmmOrNull(int? minutes) =>
      minutes == null ? null : hhmm(minutes);
}

/// Конец серии: дата, «через N … от начала» или «в течение N …».
final class _EndSpec {
  const _EndSpec(this.end, {this.day, this.after, this.span});
  final int end;
  final DateTime? day;
  final (Unit, int)? after;
  final (Unit, int)? span;

  /// Последний день серии, начатой [from].
  DateTime until(DateTime from) {
    if (day case final d?) return d;
    if (after case (final unit, final n)) return _plus(from, unit, n);
    final (unit, n) = span!;
    return addDays(_plus(from, unit, n), -1);
  }

  static DateTime _plus(DateTime from, Unit unit, int n) => switch (unit) {
    Unit.week => addDays(from, 7 * n),
    Unit.month => addMonths(from, n),
    Unit.quarter => addMonths(from, 3 * n),
    Unit.year => addMonths(from, 12 * n),
    _ => addDays(from, n),
  };
}
