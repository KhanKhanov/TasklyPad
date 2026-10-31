/// Контекст разбора дат: «сейчас», язык и настройки недели.
///
/// Разбор — чистая функция от текста и контекста: часов внутри нет, поэтому
/// тесты задают любой момент (test/fixtures, поле `now`).
final class ParseContext {
  ParseContext({
    required this.now,
    required this.lang,
    this.nextWeekDay = DateTime.monday,
    this.weekendDay = DateTime.saturday,
  }) {
    if (!now.isUtc) {
      throw ArgumentError.value(
        now,
        'now',
        'нужно стенное время в UTC-обёртке',
      );
    }
    if (!supportedLanguages.contains(lang)) {
      throw ArgumentError.value(lang, 'lang', 'язык разбора — ru или en');
    }
  }

  /// Языки разбора — языки интерфейса (решение 8А плана M3).
  static const Set<String> supportedLanguages = {'ru', 'en'};

  /// Стенное время устройства в UTC-обёртке (`AppClock.nowWall`), как
  /// момент выполнения у `nextOccurrence`.
  final DateTime now;

  /// Язык разбора: `ru` или `en`; пишется в срок (`Due.lang`).
  final String lang;

  /// «Следующая неделя» — этот день следующей недели; по умолчанию Todoist —
  /// понедельник (настройка — M10).
  final int nextWeekDay;

  /// «Выходные» — этот день; по умолчанию Todoist — суббота (настройка —
  /// M10).
  final int weekendDay;

  /// Сегодня в полночь.
  DateTime get today => DateTime.utc(now.year, now.month, now.day);

  /// Минуты от полуночи сейчас.
  int get nowMinutes => now.hour * 60 + now.minute;
}
