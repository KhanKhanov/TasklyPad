import 'lexicon_en.dart';
import 'lexicon_ru.dart';

/// Смысл слова для грамматики дат. Грамматика одна на оба языка
/// (date_grammar.dart), различаются только словари: «каждую» и `every` —
/// одно [EveryLex].
sealed class Lex {
  const Lex();
}

/// Служебное слово.
final class KeyLex extends Lex {
  const KeyLex(this.key);
  final Key key;
}

/// Служебные слова грамматики.
enum Key {
  today,
  tomorrow,

  /// «послезавтра».
  overmorrow,
  yesterday,
  next,

  /// `this`, «этой».
  current,

  /// `in`, «через».
  within,
  after,
  before,

  /// «за» в «за 50 дней до …».
  ahead,
  starting,
  ending,

  /// `for`, «(в) течение».
  span,

  /// `at`, `@`, «в».
  at,

  /// `on`, «на».
  on,

  /// `other`, «второй»: `every other week`.
  other,
  weekend,
  morning,
  afternoon,
  noon,
  evening,
  night,
  end,
  mid,
  of,
  the,
  and,
  someday,
  later,
}

/// `every`, «каждый»; `ev`, «кажд».
final class EveryLex extends Lex {
  const EveryLex();
}

/// День недели: [DateTime.monday] … [DateTime.sunday].
final class WeekdayLex extends Lex {
  const WeekdayLex(this.weekday);
  final int weekday;
}

/// Месяц 1–12.
final class MonthLex extends Lex {
  const MonthLex(this.month);
  final int month;
}

/// Единица срока.
enum Unit { minute, hour, day, week, month, quarter, year }

/// Единица срока: «дней», `weeks`.
final class UnitLex extends Lex {
  const UnitLex(this.unit);
  final Unit unit;
}

/// «Рабочий день»; [plural] — «рабочих (дней)»: `каждые 3 рабочих дня`.
final class WorkdayLex extends Lex {
  const WorkdayLex({required this.plural});
  final bool plural;
}

/// Порядковое слово: `first` = 1 … `fourth` = 4, `last` = -1.
final class OrdinalLex extends Lex {
  const OrdinalLex(this.n);
  final int n;
}

/// Число словом: «два», `three`.
final class NumberLex extends Lex {
  const NumberLex(this.n);
  final int n;
}

/// `am` / `pm`, «утра» / «вечера».
final class MeridiemLex extends Lex {
  const MeridiemLex({required this.pm});
  final bool pm;
}

/// Наречие повторения: `daily`, «ежемесячно».
final class FrequencyLex extends Lex {
  const FrequencyLex(this.unit);
  final Unit unit;
}

/// Праздник из нескольких слов: [words] нормализованы (scanner.dart).
final class Holiday {
  const Holiday(this.words, this.month, this.day);
  final List<String> words;
  final int month;
  final int day;
}

/// Словарь языка разбора.
final class Lexicon {
  const Lexicon({
    required this.words,
    required this.expansions,
    required this.holidays,
    required this.noDate,
    required this.singularWorkdayIsOrdinal,
    required this.bareDayParts,
    required this.clockWithoutColon,
    required this.afterIsFromCompletion,
    required this.withinStartingIsFromCompletion,
    required this.bareNumberIsMonthDay,
  });

  /// Слово → смысл; формы слова перечислены явно: по основе «сред»
  /// распознавалось бы и «среди».
  final Map<String, Lex> words;

  /// Слитные формы: `everyday` → `every day`, `tommorning` → `tom morning`.
  final Map<String, List<String>> expansions;

  final List<Holiday> holidays;

  /// Фразы «без срока».
  final List<List<String>> noDate;

  /// Число перед «рабочим днём» в единственном числе — порядковое:
  /// «каждый 3 рабочий день» = третий рабочий день месяца (help ru); в en
  /// порядковое только с суффиксом (`3rd workday`), а `every 3 workday` —
  /// интервал (О-63).
  final bool singularWorkdayIsOrdinal;

  /// Часть суток без предлога — время («утром»); в en — только после даты
  /// (`tom morning`) или с `in the`, иначе `Good morning` дало бы срок.
  final Set<String> bareDayParts;

  /// Четыре цифры после `at` — время: `at 1900` (help en). По-русски «в 2027
  /// году» — год, поэтому там нет.
  final bool clockWithoutColon;

  /// `after 10 days` = `every! 10 days` (help en); «после 2 часов» — не
  /// повторение.
  final bool afterIsFromCompletion;

  /// «через 10 дней начиная с 10 авг» = «каждые! 10 дней» (help ru); без
  /// начала — дата (решение 7А), `in 10 days starting …` в help нет.
  final bool withinStartingIsFromCompletion;

  /// Одно число без суффикса после «каждый» — день месяца: «каждое 27» (help
  /// ru); в en — только `every 27th` или список `every 2, 15, 27`, иначе
  /// `Water every 3 plants` стало бы правилом.
  final bool bareNumberIsMonthDay;

  /// Словарь языка [lang] (`ru` или `en`).
  static Lexicon of(String lang) => switch (lang) {
    'ru' => ruLexicon,
    'en' => enLexicon,
    _ => throw ArgumentError.value(lang, 'lang', 'язык разбора — ru или en'),
  };
}
