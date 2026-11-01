import '../domain/models.dart';
import 'calendar.dart';
import 'date_grammar.dart';
import 'parse_context.dart';
import 'scanner.dart';

// Разбор строки быстрого добавления: токены §1 docs/TODOIST_SYNTAX.md, потом
// срок (§2, §3) в оставшемся тексте. Распознанное убирается из названия и
// возвращается подсветкой; имена проекта, раздела и меток — как набраны, id
// по ним находит быстрое добавление (M3.6).

/// Что подсвечено в строке.
enum HighlightKind {
  due,
  deadline,
  duration,
  project,
  section,
  label,
  priority,
  description,
}

/// Подсвеченный участок строки.
final class Highlight {
  const Highlight(this.start, this.end, this.kind);
  final int start;
  final int end;
  final HighlightKind kind;

  Span get span => Span(start, end);
}

/// Итог разбора строки быстрого добавления.
final class QuickAddResult {
  const QuickAddResult({
    required this.title,
    required this.description,
    required this.labels,
    required this.priority,
    required this.highlights,
    this.project,
    this.section,
    this.due,
    this.noDate = false,
    this.deadline,
    this.duration,
  });

  /// Название без распознанного.
  final String title;

  /// Текст после `//`; нет — пустая строка.
  final String description;

  /// Имя проекта после `#` (без кавычек).
  final String? project;
  final String? section;

  /// Имена меток по порядку, без повторов.
  final List<String> labels;

  /// 1 = P1 … 4 = P4 (по умолчанию).
  final int priority;
  final Due? due;

  /// «no date», «без срока»: срок убирается.
  final bool noDate;

  /// Дедлайн `YYYY-MM-DD`.
  final String? deadline;
  final TaskDuration? duration;

  /// Подсветка по порядку в строке.
  final List<Highlight> highlights;
}

/// Наибольшая длительность — 24 ч (help «Set a task duration»).
const int maxDurationMinutes = 24 * 60;

/// Знак-граница: токен начинается в начале строки или после пробела.
const String _wordStart = r'(?<!\S)';

/// После токена — не буква и не цифра: `p1,` — приоритет, `p1x` — нет.
const String _wordEnd = r'(?![\p{L}\d])';

final RegExp _description = RegExp('$_wordStart//');
final RegExp _deadline = RegExp(r'\{([^{}]+)\}');
final RegExp _projectQuoted = RegExp('$_wordStart#"([^"]+)"');
final RegExp _project = RegExp('$_wordStart#([^\\s#"]+)');
final RegExp _section = RegExp('$_wordStart/([^\\s/]+)');
final RegExp _label = RegExp('$_wordStart[%@]([^\\s%@]+)');
final RegExp _priority = RegExp(
  '$_wordStart[pP]([1-4])$_wordEnd',
  unicode: true,
);

final Map<String, RegExp> _durations = {
  'en': RegExp(
    '${_wordStart}for\\s+(?:(\\d{1,4})h(?:(\\d{1,4})m)?|(\\d{1,4})m)$_wordEnd',
    caseSensitive: false,
    unicode: true,
  ),
  'ru': RegExp(
    '$_wordStartв\\s+течение\\s+'
    '(?:(\\d{1,4})ч(?:(\\d{1,4})мин)?|(\\d{1,4})мин)$_wordEnd',
    caseSensitive: false,
    unicode: true,
  ),
};

const String _clock = r'(\d{1,2}):(\d{2})';
final Map<String, RegExp> _ranges = {
  'en': RegExp(
    '${_wordStart}from\\s+$_clock\\s+to\\s+$_clock$_wordEnd',
    caseSensitive: false,
    unicode: true,
  ),
  'ru': RegExp(
    '$_wordStartс\\s+$_clock\\s+до\\s+$_clock$_wordEnd',
    caseSensitive: false,
    unicode: true,
  ),
};
final RegExp _dashRange = RegExp(
  '$_wordStart$_clock\\s*-\\s*$_clock$_wordEnd',
  unicode: true,
);

/// Знаки в конце имени — не имя: `#Работа,`.
final RegExp _trailingPunctuation = RegExp(r'[,.;:!?]+$');

/// Разбирает строку быстрого добавления [text].
///
/// [dismissed] — участки, подсветку которых пользователь отменил кликом:
/// они остаются текстом названия. [smartDates] — «Умное распознавание даты»:
/// выключено — срок, дедлайн и отрезок времени в названии не ищутся (help),
/// остальные токены §1 разбираются (допущение О-57).
QuickAddResult parseQuickAdd(
  String text,
  ParseContext ctx, {
  List<Span> dismissed = const [],
  bool smartDates = true,
}) {
  final consumed = <Highlight>[];
  bool free(Span s) =>
      !dismissed.any(s.overlaps) && !consumed.any((h) => h.span.overlaps(s));
  void take(int start, int end, HighlightKind kind) =>
      consumed.add(Highlight(start, end, kind));

  var description = '';
  final d = _description.firstMatch(text);
  if (d != null && free(Span(d.start, text.length))) {
    description = text.substring(d.end).trim();
    take(d.start, text.length, HighlightKind.description);
  }

  String? deadline;
  // Выключенное распознавание — дату и дедлайн ставит только планировщик
  // (help «Turn smart date recognition on or off»).
  for (final m in smartDates ? _deadline.allMatches(text) : <RegExpMatch>[]) {
    if (!free(Span(m.start, m.end))) continue;
    final date = parseDueText(m[1]!, ctx)?.due;
    if (date == null || date.rule != null) continue;
    deadline = date.date;
    take(m.start, m.end, HighlightKind.deadline);
    break;
  }

  TaskDuration? duration;
  (int, Span)? range;
  for (final m in _durations[ctx.lang]!.allMatches(text)) {
    if (!free(Span(m.start, m.end))) continue;
    final minutes = m[3] != null
        ? int.parse(m[3]!)
        : int.parse(m[1]!) * 60 + int.parse(m[2] ?? '0');
    if (minutes < 1 || minutes > maxDurationMinutes) continue;
    duration = TaskDuration(amount: minutes, unit: 'minute');
    take(m.start, m.end, HighlightKind.duration);
    break;
  }
  if (duration == null && smartDates) {
    for (final m in [
      ..._ranges[ctx.lang]!.allMatches(text),
      ..._dashRange.allMatches(text),
    ]) {
      if (!free(Span(m.start, m.end))) continue;
      final from = _minutes(m[1]!, m[2]!);
      final to = _minutes(m[3]!, m[4]!);
      if (from == null || to == null || to <= from) continue;
      duration = TaskDuration(amount: to - from, unit: 'minute');
      range = (from, Span(m.start, m.end));
      take(m.start, m.end, HighlightKind.duration);
      break;
    }
  }

  String? project;
  for (final pattern in [_projectQuoted, _project]) {
    if (project != null) break;
    project = _firstName(text, pattern, free, (s, e) {
      take(s, e, HighlightKind.project);
    });
  }
  final section = _firstName(text, _section, free, (s, e) {
    take(s, e, HighlightKind.section);
  });
  final labels = <String>[];
  for (;;) {
    final label = _firstName(text, _label, free, (s, e) {
      take(s, e, HighlightKind.label);
    });
    if (label == null) break;
    if (!labels.contains(label)) labels.add(label);
  }
  var priority = 4;
  for (final m in _priority.allMatches(text)) {
    if (!free(Span(m.start, m.end))) continue;
    priority = int.parse(m[1]!);
    take(m.start, m.end, HighlightKind.priority);
    break;
  }

  Due? due;
  var noDate = false;
  if (smartDates) {
    final match = _findDue(text, consumed, dismissed, ctx, timeHint: range?.$1);
    if (match != null) {
      take(match.start, match.end, HighlightKind.due);
      noDate = match.noDate;
      due = match.due?.copyWith(
        string: text.substring(match.start, match.end),
        lang: ctx.lang,
      );
    }
  }
  if (range case (final from, final span)) {
    final at = hhmm(from);
    if (due == null && !noDate) {
      final today = ctx.today;
      final day = from > ctx.nowMinutes ? today : addDays(today, 1);
      due = Due(
        date: isoDate(day),
        time: at,
        string: text.substring(span.start, span.end),
        lang: ctx.lang,
      );
    } else if (due != null && due.time == null) {
      due = due.copyWith(time: at);
    }
  }

  consumed.sort((a, b) => a.start.compareTo(b.start));
  return QuickAddResult(
    title: _title(text, consumed),
    description: description,
    project: project,
    section: section,
    labels: labels,
    priority: priority,
    due: due,
    noDate: noDate,
    deadline: deadline,
    duration: duration,
    highlights: consumed,
  );
}

/// Строка поля срока целиком ([text] — только дата): срок, «без срока» или
/// `null`, если строка — не дата. Здесь число без слова — день месяца.
DueMatch? parseDueText(String text, ParseContext ctx) {
  final tokens = scan(text);
  if (tokens.isEmpty) return null;
  final grammar = DateGrammar(tokens, ctx, field: true);
  final match = grammar.matchAt(0);
  if (match == null || match.end != tokens.last.end) return null;
  final due = match.due?.copyWith(string: text.trim(), lang: ctx.lang);
  return DueMatch(
    start: match.start,
    end: match.end,
    due: due,
    noDate: match.noDate,
  );
}

/// Разделитель на месте разобранного токена: рвёт фразу даты, чтобы
/// «tomorrow #Work at 5pm» не склеилось в одну дату через проект.
const String _gap = '\u0001';

/// Первый срок в тексте вне [consumed]: разобранные токены заменены
/// разделителем и пробелами (позиции не сдвигаются), напоминания `!…`,
/// отменённые участки и фраза `every`, которая не разобралась, пропускаются.
/// [timeHint] — время отрезка `9:30-10:00` для повторения без своего
/// времени.
DueMatch? _findDue(
  String text,
  List<Highlight> consumed,
  List<Span> dismissed,
  ParseContext ctx, {
  int? timeHint,
}) {
  final masked = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    final inside = consumed.where((h) => h.start <= i && i < h.end);
    masked.write(
      inside.isEmpty ? text[i] : (inside.any((h) => h.start == i) ? _gap : ' '),
    );
  }
  final grammar = DateGrammar(scan(masked.toString()), ctx, timeHint: timeHint);
  final blocked = [...dismissed, for (final h in consumed) h.span];
  for (var i = 0; i + 1 < grammar.length; i++) {
    final mark = grammar.tokenAt(i);
    final next = grammar.tokenAt(i + 1);
    // `!` перед словом, а не после (`every!`) — напоминание (M7): остаётся
    // в названии и сроком не считается.
    if (grammar.textAt(i) != '!' || mark.glued || !next.glued) continue;
    final end = grammar.reminderEnd(i + 1);
    final last = end == null ? next : grammar.tokenAt(end - 1);
    blocked.add(Span(mark.start, last.end));
  }
  for (var i = 0; i < grammar.length; i++) {
    final match = grammar.matchAt(i);
    if (match == null) {
      final end = grammar.everyPhraseEnd(i);
      if (end != null && end > i + 1) {
        final start = grammar.tokenAt(i).start;
        blocked.add(Span(start, grammar.tokenAt(end - 1).end));
      }
      continue;
    }
    if (blocked.any((s) => s.overlaps(Span(match.start, match.end)))) continue;
    return match;
  }
  return null;
}

/// Первое свободное имя токена [pattern]; знаки в конце имени остаются
/// текстом.
String? _firstName(
  String text,
  RegExp pattern,
  bool Function(Span) free,
  void Function(int start, int end) take,
) {
  for (final m in pattern.allMatches(text)) {
    final raw = m[1]!;
    final name = raw.replaceFirst(_trailingPunctuation, '');
    if (name.isEmpty) continue;
    final end = m.end - (raw.length - name.length);
    if (!free(Span(m.start, end))) continue;
    take(m.start, end);
    return name;
  }
  return null;
}

/// Знак, который пишется вплотную к слову слева: на стыке «Meet , then» →
/// «Meet, then»; `!14:00` — не такой знак.
final RegExp _joinsLeft = RegExp(r'^[,.;:!?](?:\s|$)');

/// Название — куски строки между распознанными участками, на стыках —
/// один пробел; внутри кусков текст не меняется.
String _title(String text, List<Highlight> consumed) {
  final pieces = <String>[];
  var at = 0;
  for (final h in consumed) {
    if (h.start > at) pieces.add(text.substring(at, h.start));
    if (h.end > at) at = h.end;
  }
  pieces.add(text.substring(at));
  final out = StringBuffer();
  for (final raw in pieces) {
    final piece = raw.trim();
    if (piece.isEmpty) continue;
    if (out.isNotEmpty && !_joinsLeft.hasMatch(piece)) out.write(' ');
    out.write(piece);
  }
  return out.toString();
}

int? _minutes(String h, String m) {
  final hours = int.parse(h);
  final minutes = int.parse(m);
  return hours > 23 || minutes > 59 ? null : hours * 60 + minutes;
}
