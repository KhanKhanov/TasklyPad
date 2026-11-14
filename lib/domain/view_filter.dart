// Фильтр «Отображения» вида (решения 3А, 5А plans/m5 «Решения M5.3»): выбор в
// подменю «Дата», «Дедлайн», «Приоритет», «Метка» хранится в `filtered_by`
// запросом через `&` (язык фильтров, TODOIST_SYNTAX §4) и читается обратно для
// галочек меню. Условия запроса, которых меню не знает (импорт из Todoist),
// сохраняются как есть. Варианты дат в help не перечислены — допущение, О-69.

/// Вариант подменю «Дата» или «Дедлайн».
enum ViewDateChoice { today, thisWeek, next7Days, thisMonth, next30Days, none }

/// Выбор фильтра «Отображения»; `null` у поля — «Все».
final class ViewFilter {
  const ViewFilter({
    this.date,
    this.deadline,
    this.priority,
    this.label,
    this.extra = const [],
  });

  /// Выбор из запроса [query] (`filtered_by`); `null` — без фильтра.
  factory ViewFilter.parse(String? query) {
    if (query == null || query.trim().isEmpty) return const ViewFilter();
    // `|` или `,` вне скобок связывают слабее `&`: деление по `&` изменило бы
    // смысл (`p1 | p2 & today` — это `p1 | (p2 & today)`). Такой запрос (импорт)
    // меню не разбирает — он целиком одно незнакомое условие.
    if (_outside(query, '|') || _outside(query, ',')) {
      return ViewFilter(extra: [query.trim()]);
    }
    ViewDateChoice? date, deadline;
    int? priority;
    String? label;
    final extra = <String>[];
    for (final term in _topLevelTerms(query)) {
      // Регистр и лишние пробелы не важны, как в языке фильтров: `P1`,
      // `Today` из импорта — тоже пункты меню.
      final key = _normalized(term);
      final d = _dateTerms.entries
          .where((e) => _normalized(e.value) == key)
          .firstOrNull;
      final dl = _deadlineTerms.entries
          .where((e) => _normalized(e.value) == key)
          .firstOrNull;
      final p = RegExp(r'^p([1-4])$').firstMatch(key);
      if (d != null && date == null) {
        date = d.key;
      } else if (dl != null && deadline == null) {
        deadline = dl.key;
      } else if (p != null && priority == null) {
        priority = int.parse(p[1]!);
      } else if (term.startsWith('%') && term.length > 1 && label == null) {
        label = _unescape(term.substring(1));
      } else {
        extra.add(term);
      }
    }
    return ViewFilter(
      date: date,
      deadline: deadline,
      priority: priority,
      label: label,
      extra: extra,
    );
  }

  final ViewDateChoice? date;
  final ViewDateChoice? deadline;

  /// 1–4, как `p1`…`p4`.
  final int? priority;

  /// Имя метки (запрос хранит имена, как сохранённый фильтр).
  final String? label;

  /// Условия запроса, которых меню не знает, — как были.
  final List<String> extra;

  /// Сколько выбрано — в «Отображение: N» (решение 5А): каждый вид фильтра и
  /// каждое незнакомое условие.
  int get count =>
      (date == null ? 0 : 1) +
      (deadline == null ? 0 : 1) +
      (priority == null ? 0 : 1) +
      (label == null ? 0 : 1) +
      extra.length;

  /// Запрос для `filtered_by`; ничего не выбрано — `null`.
  String? get query {
    final date = this.date, deadline = this.deadline, label = this.label;
    final terms = [
      if (date != null) _dateTerms[date]!,
      if (deadline != null) _deadlineTerms[deadline]!,
      if (priority != null) 'p$priority',
      if (label != null) '%${_escape(label)}',
      // `|` слабее `&`: незнакомое условие с ним — в скобках, иначе
      // соседний выбор связался бы только с его половиной.
      // Условие с `,` (несколько списков) к выбору не присоединить: запятая
      // разделила бы весь запрос, а в скобках она — ошибка. Оно отбрасывается.
      for (final t in extra)
        if (!_outside(t, ',')) _outside(t, '|') ? '($t)' : t,
    ];
    return terms.isEmpty ? null : terms.join(' & ');
  }

  ViewFilter withDate(ViewDateChoice? value) => ViewFilter(
    date: value,
    deadline: deadline,
    priority: priority,
    label: label,
    extra: extra,
  );

  ViewFilter withDeadline(ViewDateChoice? value) => ViewFilter(
    date: date,
    deadline: value,
    priority: priority,
    label: label,
    extra: extra,
  );

  ViewFilter withPriority(int? value) => ViewFilter(
    date: date,
    deadline: deadline,
    priority: value,
    label: label,
    extra: extra,
  );

  ViewFilter withLabel(String? value) => ViewFilter(
    date: date,
    deadline: deadline,
    priority: priority,
    label: value,
    extra: extra,
  );
}

/// «Эта неделя» — с сегодня до конца недели (начало следующей — `next week`,
/// понедельник; настройка начала недели — M10), «этот месяц» — до первого дня
/// следующего (`first day`); «следующие N дней» — с сегодня включительно.
/// Просроченные не входят.
const Map<ViewDateChoice, String> _dateTerms = {
  ViewDateChoice.today: 'today',
  ViewDateChoice.thisWeek: '(date after: yesterday & date before: next week)',
  ViewDateChoice.next7Days: '7 days',
  ViewDateChoice.thisMonth: '(date after: yesterday & date before: first day)',
  ViewDateChoice.next30Days: '30 days',
  ViewDateChoice.none: 'no date',
};

const Map<ViewDateChoice, String> _deadlineTerms = {
  ViewDateChoice.today: 'deadline: today',
  ViewDateChoice.thisWeek:
      '(deadline after: yesterday & deadline before: next week)',
  ViewDateChoice.next7Days:
      '(deadline after: yesterday & deadline before: in 7 days)',
  ViewDateChoice.thisMonth:
      '(deadline after: yesterday & deadline before: first day)',
  ViewDateChoice.next30Days:
      '(deadline after: yesterday & deadline before: in 30 days)',
  ViewDateChoice.none: 'no deadline',
};

/// Знаки языка фильтров, которые в имени метки экранируются `\`.
final RegExp _special = RegExp(r'[\\&|!(),*]');

String _escape(String name) =>
    name.replaceAllMapped(_special, (m) => '\\${m[0]}');

String _unescape(String text) =>
    text.replaceAllMapped(RegExp(r'\\(.)'), (m) => m[1]!);

/// Условие [term] для сравнения с пунктами меню: строчными буквами, пробелы
/// — по одному.
String _normalized(String term) =>
    term.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');

/// В условии [term] есть знак [char] вне скобок.
bool _outside(String term, String char) {
  var depth = 0;
  for (var i = 0; i < term.length; i++) {
    final c = term[i];
    if (c == r'\') {
      i++;
    } else if (c == '(') {
      depth++;
    } else if (c == ')') {
      depth--;
    } else if (c == char && depth == 0) {
      return true;
    }
  }
  return false;
}

/// Условия запроса, связанные `&` вне скобок, — как набраны, без пробелов по
/// краям; `\` экранирует следующий знак.
List<String> _topLevelTerms(String query) {
  final terms = <String>[];
  final current = StringBuffer();
  var depth = 0;
  for (var i = 0; i < query.length; i++) {
    final c = query[i];
    if (c == r'\' && i + 1 < query.length) {
      current
        ..write(c)
        ..write(query[++i]);
      continue;
    }
    if (c == '(') depth++;
    if (c == ')') depth--;
    if (c == '&' && depth == 0) {
      terms.add(current.toString().trim());
      current.clear();
    } else {
      current.write(c);
    }
  }
  terms.add(current.toString().trim());
  return [
    for (final t in terms)
      if (t.isNotEmpty) t,
  ];
}
