import 'lexicon.dart';

// Словарь ru — по help ru «Introduction to dates and time», «Introduction to
// recurring dates» (docs/TODOIST_SYNTAX.md §2, §3). Формы слов перечислены
// явно: «ё» уже заменена на «е» (scanner.dart).

Map<String, Lex> _each(List<String> forms, Lex lex) => {
  for (final f in forms) f: lex,
};

/// Формы слова: основа и окончания.
List<String> _forms(String stem, List<String> endings) => [
  for (final e in endings) '$stem$e',
];

const List<String> _adjEndings = [
  'ий',
  'ый',
  'ая',
  'яя',
  'ое',
  'ее',
  'юю',
  'ие',
  'ые',
  'ую',
  'ей',
  'ой',
  'ем',
  'ом',
  'его',
  'ого',
  'им',
  'ым',
];

/// Словарь русского разбора.
final Lexicon ruLexicon = Lexicon(
  words: {
    'сегодня': const KeyLex(Key.today),
    'завтра': const KeyLex(Key.tomorrow),
    'послезавтра': const KeyLex(Key.overmorrow),
    'вчера': const KeyLex(Key.yesterday),
    ..._each(_forms('следующ', _adjEndings), const KeyLex(Key.next)),
    ..._each([
      'этот',
      'эта',
      'это',
      'эту',
      'этой',
      'этом',
    ], const KeyLex(Key.current)),
    'через': const KeyLex(Key.within),
    'после': const KeyLex(Key.after),
    'до': const KeyLex(Key.before),
    'за': const KeyLex(Key.ahead),
    ..._each(['начиная', 'с', 'со'], const KeyLex(Key.starting)),
    'заканчивая': const KeyLex(Key.ending),
    'течение': const KeyLex(Key.span),
    ..._each(['в', 'во', '@'], const KeyLex(Key.at)),
    'на': const KeyLex(Key.on),
    ..._each(_forms('втор', _adjEndings), const KeyLex(Key.other)),
    ..._each(['выходные', 'выходных', 'выходным'], const KeyLex(Key.weekend)),
    ..._each(['утром', 'утро'], const KeyLex(Key.morning)),
    ..._each(['днем'], const KeyLex(Key.afternoon)),
    ..._each(['полдень'], const KeyLex(Key.noon)),
    ..._each(['вечером', 'вечер'], const KeyLex(Key.evening)),
    ..._each(['ночью', 'ночь'], const KeyLex(Key.night)),
    ..._each(['конец', 'конца'], const KeyLex(Key.end)),
    ..._each(['середина', 'середину', 'середины'], const KeyLex(Key.mid)),
    'и': const KeyLex(Key.and),
    'когда-нибудь': const KeyLex(Key.someday),
    ..._each([
      ..._forms('кажд', ['', 'ый', 'ая', 'ое', 'ую', 'ые', 'ого', 'ой']),
    ], const EveryLex()),
    ..._each([
      'пн',
      ..._forms('понедельник', ['', 'а', 'у', 'ам']),
    ], const WeekdayLex(DateTime.monday)),
    ..._each([
      'вт',
      ..._forms('вторник', ['', 'а', 'у', 'ам']),
    ], const WeekdayLex(DateTime.tuesday)),
    ..._each([
      'ср',
      ..._forms('сред', ['а', 'у', 'ы', 'е', 'ам', '']),
    ], const WeekdayLex(DateTime.wednesday)),
    ..._each([
      'чт',
      ..._forms('четверг', ['', 'а', 'у', 'ам']),
    ], const WeekdayLex(DateTime.thursday)),
    ..._each([
      'пт',
      ..._forms('пятниц', ['а', 'у', 'ы', 'е', 'ам']),
    ], const WeekdayLex(DateTime.friday)),
    ..._each([
      'сб',
      ..._forms('суббот', ['а', 'у', 'ы', 'е', 'ам']),
    ], const WeekdayLex(DateTime.saturday)),
    ..._each([
      'вс',
      ..._forms('воскресень', ['е', 'я', 'ю', 'ям']),
    ], const WeekdayLex(DateTime.sunday)),
    ..._each([
      'янв',
      ..._forms('январ', ['ь', 'я', 'е']),
    ], const MonthLex(1)),
    ..._each([
      'фев',
      'февр',
      ..._forms('феврал', ['ь', 'я', 'е']),
    ], const MonthLex(2)),
    ..._each([
      'мар',
      ..._forms('март', ['', 'а', 'е']),
    ], const MonthLex(3)),
    ..._each([
      'апр',
      ..._forms('апрел', ['ь', 'я', 'е']),
    ], const MonthLex(4)),
    ..._each(['май', 'мая', 'мае'], const MonthLex(5)),
    ..._each([
      'июн',
      ..._forms('июн', ['ь', 'я', 'е']),
    ], const MonthLex(6)),
    ..._each([
      'июл',
      ..._forms('июл', ['ь', 'я', 'е']),
    ], const MonthLex(7)),
    ..._each([
      'авг',
      ..._forms('август', ['', 'а', 'е']),
    ], const MonthLex(8)),
    ..._each([
      'сен',
      'сент',
      ..._forms('сентябр', ['ь', 'я', 'е']),
    ], const MonthLex(9)),
    ..._each([
      'окт',
      ..._forms('октябр', ['ь', 'я', 'е']),
    ], const MonthLex(10)),
    ..._each([
      'ноя',
      'нояб',
      ..._forms('ноябр', ['ь', 'я', 'е']),
    ], const MonthLex(11)),
    ..._each([
      'дек',
      ..._forms('декабр', ['ь', 'я', 'е']),
    ], const MonthLex(12)),
    ..._each([
      'мин',
      ..._forms('минут', ['а', 'у', 'ы', '']),
    ], const UnitLex(Unit.minute)),
    ..._each(['час', 'часа', 'часов'], const UnitLex(Unit.hour)),
    ..._each(['день', 'дня', 'дней', 'дни'], const UnitLex(Unit.day)),
    ..._each(
      _forms('недел', ['я', 'и', 'ь', 'ю', 'е']),
      const UnitLex(Unit.week),
    ),
    ..._each([
      'месяц',
      'месяца',
      'месяцев',
      'месяце',
    ], const UnitLex(Unit.month)),
    ..._each(['квартал', 'квартала', 'кварталов'], const UnitLex(Unit.quarter)),
    ..._each(['год', 'года', 'лет', 'году'], const UnitLex(Unit.year)),
    ..._each([
      'рабочий',
      'рабочую',
      'рабочего',
      'будний',
    ], const WorkdayLex(plural: false)),
    ..._each(['рабочих', 'будних'], const WorkdayLex(plural: true)),
    ..._each(_forms('перв', _adjEndings), const OrdinalLex(1)),
    ..._each([
      'третий',
      'третья',
      'третье',
      'третью',
      'третьего',
    ], const OrdinalLex(3)),
    ..._each(_forms('четверт', _adjEndings), const OrdinalLex(4)),
    ..._each(_forms('последн', _adjEndings), const OrdinalLex(-1)),
    ..._each(['один', 'одна', 'одну', 'одно'], const NumberLex(1)),
    ..._each(['два', 'две'], const NumberLex(2)),
    'три': const NumberLex(3),
    'четыре': const NumberLex(4),
    'пять': const NumberLex(5),
    'шесть': const NumberLex(6),
    'семь': const NumberLex(7),
    'восемь': const NumberLex(8),
    'девять': const NumberLex(9),
    'десять': const NumberLex(10),
    ..._each(['утра', 'ночи'], const MeridiemLex(pm: false)),
    'вечера': const MeridiemLex(pm: true),
    ..._each(
      _forms('ежечасн', ['о', ..._adjEndings]),
      const FrequencyLex(Unit.hour),
    ),
    ..._each(
      _forms('ежедневн', ['о', ..._adjEndings]),
      const FrequencyLex(Unit.day),
    ),
    ..._each(
      _forms('еженедельн', ['о', ..._adjEndings]),
      const FrequencyLex(Unit.week),
    ),
    ..._each(
      _forms('ежемесячн', ['о', ..._adjEndings]),
      const FrequencyLex(Unit.month),
    ),
    ..._each(
      _forms('ежеквартальн', ['о', ..._adjEndings]),
      const FrequencyLex(Unit.quarter),
    ),
    ..._each(
      _forms('ежегодн', ['о', ..._adjEndings]),
      const FrequencyLex(Unit.year),
    ),
  },
  expansions: const {},
  holidays: const [
    Holiday(['новый', 'год'], 1, 1),
    Holiday(['нового', 'года'], 1, 1),
    Holiday(['новому', 'году'], 1, 1),
    Holiday(['день', 'святого', 'валентина'], 2, 14),
    Holiday(['дня', 'святого', 'валентина'], 2, 14),
    Holiday(['день', 'валентина'], 2, 14),
    Holiday(['дня', 'валентина'], 2, 14),
    Holiday(['хэллоуин'], 10, 31),
    Holiday(['хеллоуин'], 10, 31),
    Holiday(['хэллоуина'], 10, 31),
    Holiday(['канун', 'нового', 'года'], 12, 31),
    Holiday(['кануна', 'нового', 'года'], 12, 31),
  ],
  noDate: const [
    ['без', 'срока'],
    ['нет', 'срока'],
  ],
  singularWorkdayIsOrdinal: true,
  bareDayParts: const {'утром', 'днем', 'вечером', 'ночью'},
  clockWithoutColon: false,
  afterIsFromCompletion: false,
  withinStartingIsFromCompletion: true,
  bareNumberIsMonthDay: true,
);
