import 'text_fold.dart';

// Разобранный запрос фильтра (TODOIST_SYNTAX §4): части через `,` и дерево
// условий каждой части. Разбор — lib/nlp/filter_parser.dart, вычисление —
// lib/domain/filter_engine.dart. Даты в условиях уже посчитаны от момента
// разбора: запрос сохранённого фильтра разбирается заново при каждом
// вычислении. `toString` узла — короткая запись для табличных тестов
// (test/fixtures/filters.json).

/// Запрос фильтра: каждая часть через `,` — отдельный список (help).
final class FilterQuery {
  const FilterQuery(this.parts);

  final List<FilterPart> parts;
}

/// Часть запроса: её текст (заголовок списка — допущение, О-69) и условие.
final class FilterPart {
  const FilterPart(this.text, this.node);

  /// Текст части без пробелов по краям.
  final String text;
  final FilterNode node;
}

/// Почему запрос не разобран; текст — l10n в интерфейсе.
enum FilterErrorKind {
  /// Пустой запрос или пустая часть между запятыми, пустые скобки.
  empty,

  /// Оператор не на своём месте: `p1 &`, `| p2`, `)`.
  unexpected,

  /// Скобка не закрыта.
  unclosed,

  /// Запятая внутри скобок: отдельные списки — только на верхнем уровне.
  commaInGroup,

  /// Условие не распознано.
  unknown,

  /// Значение даты не распознано: `date: вчера-позавчера`.
  badDate,

  /// Совместная работа — вне scope (TODOIST_PARITY §11): `assigned to:`.
  unsupported,
}

/// Ошибка синтаксиса запроса: участок [start]..[end] исходного текста.
final class FilterSyntaxError implements Exception {
  const FilterSyntaxError(this.kind, this.start, this.end);

  final FilterErrorKind kind;
  final int start;
  final int end;

  @override
  String toString() => 'FilterSyntaxError(${kind.name}, $start..$end)';
}

/// Имя проекта, раздела или метки с подстановкой `*` (help: в начале,
/// конце и середине). Сравнение — без учёта регистра, «ё» = «е».
final class NamePattern {
  /// [parts] — куски текста между звёздочками: `#*Work` — `['', 'Work']`.
  NamePattern(List<String> parts)
    : parts = List.unmodifiable(parts),
      _folded = [for (final p in parts) foldText(p)];

  final List<String> parts;
  final List<String> _folded;

  /// Звёздочек нет.
  bool get exact => parts.length == 1;

  bool matches(String name) {
    final text = foldText(name);
    if (exact) return text == _folded.single;
    if (!text.startsWith(_folded.first)) return false;
    var at = _folded.first.length;
    for (final part in _folded.sublist(1, _folded.length - 1)) {
      final found = text.indexOf(part, at);
      if (found < 0) return false;
      at = found + part.length;
    }
    final last = _folded.last;
    return text.length - last.length >= at && text.endsWith(last);
  }

  @override
  String toString() => parts.map((p) => p.replaceAll('*', r'\*')).join('*');
}

/// Какая дата задачи сравнивается.
enum DateField {
  /// Запланированная дата: `date:`, «срок:».
  scheduled('date'),

  /// Дата или дедлайн: `due:`, «к выполнению:».
  scheduledOrDeadline('due'),

  /// `deadline:`, «дедлайн:».
  deadline('deadline'),

  /// Дата создания: `created:`, «создано:».
  created('created');

  const DateField(this.keyword);

  /// Слово запроса на английском — для [toString].
  final String keyword;
}

/// Сравнение даты: на этот день, до, после.
enum DateRelation { on, before, after }

/// Значение даты условия: день и, если названо, время.
final class FilterDate {
  const FilterDate(this.date, [this.minutes]);

  /// `YYYY-MM-DD`.
  final String date;

  /// Минуты от полуночи; `null` — без времени.
  final int? minutes;

  @override
  bool operator ==(Object other) =>
      other is FilterDate && other.date == date && other.minutes == minutes;

  @override
  int get hashCode => Object.hash(date, minutes);

  @override
  String toString() {
    final m = minutes;
    if (m == null) return date;
    String two(int n) => n.toString().padLeft(2, '0');
    return '$date ${two(m ~/ 60)}:${two(m % 60)}';
  }
}

/// Условие запроса.
sealed class FilterNode {
  const FilterNode();
}

final class AndNode extends FilterNode {
  const AndNode(this.left, this.right);
  final FilterNode left;
  final FilterNode right;

  @override
  String toString() => 'and($left, $right)';
}

final class OrNode extends FilterNode {
  const OrNode(this.left, this.right);
  final FilterNode left;
  final FilterNode right;

  @override
  String toString() => 'or($left, $right)';
}

final class NotNode extends FilterNode {
  const NotNode(this.child);
  final FilterNode child;

  @override
  String toString() => 'not($child)';
}

/// `view all`, `All` — все активные задачи.
final class AllNode extends FilterNode {
  const AllNode();

  @override
  String toString() => 'all';
}

/// `p1`…`p4`; `No priority` — `p4`.
final class PriorityNode extends FilterNode {
  const PriorityNode(this.priority);
  final int priority;

  @override
  String toString() => 'p$priority';
}

/// `#Проект`; `##Проект` — с подпроектами.
final class ProjectNode extends FilterNode {
  const ProjectNode(this.name, {required this.withSubprojects});
  final NamePattern name;
  final bool withSubprojects;

  @override
  String toString() => '${withSubprojects ? '##' : '#'}$name';
}

/// `/Раздел` — раздел с этим именем во всех проектах; `/*` — любой раздел.
final class SectionNode extends FilterNode {
  const SectionNode(this.name);
  final NamePattern name;

  @override
  String toString() => '/$name';
}

/// `%метка` (и `@метка`).
final class LabelNode extends FilterNode {
  const LabelNode(this.name);
  final NamePattern name;

  @override
  String toString() => '%$name';
}

/// `no labels`, «без меток».
final class NoLabelsNode extends FilterNode {
  const NoLabelsNode();

  @override
  String toString() => 'no_labels';
}

/// `search: слова` — все слова в названии, в любом порядке.
final class SearchNode extends FilterNode {
  const SearchNode(this.words);
  final List<String> words;

  @override
  String toString() => 'search(${words.join(', ')})';
}

/// `subtask`, «подзадача».
final class SubtaskNode extends FilterNode {
  const SubtaskNode();

  @override
  String toString() => 'subtask';
}

/// `recurring`, «повторяющиеся».
final class RecurringNode extends FilterNode {
  const RecurringNode();

  @override
  String toString() => 'recurring';
}

/// `no date`, «без даты» — нет запланированной даты.
final class NoDateNode extends FilterNode {
  const NoDateNode();

  @override
  String toString() => 'no_date';
}

/// `no time`, «без времени» — дата без времени.
final class NoTimeNode extends FilterNode {
  const NoTimeNode();

  @override
  String toString() => 'no_time';
}

/// `no deadline`, «без дедлайна».
final class NoDeadlineNode extends FilterNode {
  const NoDeadlineNode();

  @override
  String toString() => 'no_deadline';
}

/// `overdue`, «просрочено» — дата раньше сегодня (на часы — не входит).
final class OverdueNode extends FilterNode {
  const OverdueNode();

  @override
  String toString() => 'overdue';
}

/// `5 days`, `next 5 days` — дата от сегодня на [days] дней вперёд, сегодня
/// включительно (допущение, О-69).
final class NextDaysNode extends FilterNode {
  const NextDaysNode(this.days);
  final int days;

  @override
  String toString() => 'days($days)';
}

/// `date:`, `due:`, `deadline:`, `created:` с `before`, `after` или без; и
/// дата без слова (`today`, `Jan 3`) — запланированная на этот день.
final class DateNode extends FilterNode {
  const DateNode(this.field, this.relation, this.value);
  final DateField field;
  final DateRelation relation;
  final FilterDate value;

  @override
  String toString() => '${field.keyword}(${relation.name}, $value)';
}

/// `uncompletable`, «незавершаемые» — таких задач пока нет (О-88).
final class UncompletableNode extends FilterNode {
  const UncompletableNode();

  @override
  String toString() => 'uncompletable';
}
