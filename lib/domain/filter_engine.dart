import 'filter_query.dart';
import 'markdown_text.dart';
import 'models.dart';
import 'text_fold.dart';
import 'view_options.dart';
import 'view_order.dart';
import 'workspace.dart';

// Вычисление запроса фильтра по снимку (TODOIST_SYNTAX §4, план M5 «Язык
// фильтров»). Только активные задачи (help: «Filters show only open tasks»),
// подзадачи — своими строками. Проект и раздел задачи — вычисленные: проект и
// раздел корневой задачи (О-6), а не записанные у подзадачи. Допущения (О-69)
// — в TODOIST_SYNTAX §4 «Допущения» и plans/m5 «Не найдено в help».

/// Список одной части запроса.
final class FilterList {
  const FilterList(this.title, this.tasks, this.order);

  /// Текст части запроса — заголовок списка (допущение, О-69).
  final String title;
  final List<Task> tasks;

  /// Порядок списка — им же упорядочены задачи в группах «Отображения».
  final TaskOrder order;
}

/// Задачи снимка [ws] по запросу [query]: по списку на каждую часть через
/// `,`. [now] — стенное время устройства в UTC-обёртке (`AppClock.nowWall`),
/// [wallOf] — стенное время для момента UTC ISO-8601 (дата создания; по
/// умолчанию — по поясу устройства). Порядок — [sorting] «Отображения», при
/// равенстве — порядок фильтра по умолчанию (help «Default sorting order»,
/// О-85).
List<FilterList> evaluateFilter(
  Workspace ws,
  FilterQuery query, {
  required DateTime now,
  DateTime? Function(String utc)? wallOf,
  Sorting sorting = Sorting.byDefault,
  SortOrder sortOrder = SortOrder.asc,
}) {
  final matcher = _Matcher(ws, now, wallOf ?? _deviceWall);
  final tasks = ws.activeTasks;
  return [
    for (final part in query.parts)
      if (ws.taskOrder(
            _hasDates(part.node)
                ? DefaultOrder.filterDated
                : DefaultOrder.label,
            sorting: sorting,
            sortOrder: sortOrder,
          )
          case final order)
        FilterList(
          part.text,
          [
            for (final t in tasks)
              if (matcher.matches(part.node, t)) t,
          ]..sort(order.compare),
          order,
        ),
  ];
}

/// В условии есть дата или дедлайн задачи — порядок «с датами» (О-85):
/// `date:`, `due:`, `deadline:` (не `created:`), дата без слова,
/// `overdue`, `N days`. «Без даты» и подобные — не даты (допущение, О-69).
bool _hasDates(FilterNode node) => switch (node) {
  AndNode(:final left, :final right) ||
  OrNode(:final left, :final right) => _hasDates(left) || _hasDates(right),
  NotNode(:final child) => _hasDates(child),
  DateNode(:final field) => field != DateField.created,
  OverdueNode() || NextDaysNode() => true,
  _ => false,
};

DateTime? _deviceWall(String utc) {
  final at = DateTime.tryParse(utc)?.toLocal();
  if (at == null) return null;
  return DateTime.utc(at.year, at.month, at.day, at.hour, at.minute);
}

String _iso(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';

int? _minutes(String? hhmm) => hhmm == null
    ? null
    : int.parse(hhmm.substring(0, 2)) * 60 + int.parse(hhmm.substring(3, 5));

final class _Matcher {
  _Matcher(this.ws, DateTime now, this.wallOf)
    : today = _iso(now),
      _todayDay = DateTime.utc(now.year, now.month, now.day);

  final Workspace ws;
  final DateTime? Function(String utc) wallOf;
  final String today;
  final DateTime _todayDay;

  bool matches(FilterNode node, Task t) => switch (node) {
    AndNode(:final left, :final right) => matches(left, t) && matches(right, t),
    OrNode(:final left, :final right) => matches(left, t) || matches(right, t),
    NotNode(:final child) => !matches(child, t),
    AllNode() => true,
    PriorityNode(:final priority) => t.priority == priority,
    ProjectNode(:final name, :final withSubprojects) => _inProject(
      t,
      name,
      withSubprojects: withSubprojects,
    ),
    SectionNode(:final name) => switch (ws.rootSectionOf(t.id)) {
      null => false,
      final section => name.matches(section.name),
    },
    LabelNode(:final name) => t.labelIds.any(
      (id) => switch (ws.label(id)) {
        null => false,
        final label => name.matches(label.name),
      },
    ),
    NoLabelsNode() => !t.labelIds.any((id) => ws.label(id) != null),
    SearchNode(:final words) => _search(t, words),
    SubtaskNode() => ws.taskParent(t.id) != null,
    RecurringNode() => t.due?.isRecurring ?? false,
    NoDateNode() => t.due == null,
    NoTimeNode() => t.due != null && t.due!.time == null,
    NoDeadlineNode() => t.deadline == null,
    // Просрочено — по дате: срок сегодня с прошедшим временем не входит
    // (help «Search for tasks by date»).
    OverdueNode() => (t.due?.date.compareTo(today) ?? 0) < 0,
    NextDaysNode(:final days) => _within(t.due?.date, days),
    DateNode() => _date(node, t),
    UncompletableNode() => false,
  };

  /// Проект корневой задачи (О-6) или, с [withSubprojects], любой его
  /// предок. «Входящие» — и под своим именем, и `Inbox` / «Входящие»
  /// (допущение).
  bool _inProject(Task t, NamePattern name, {required bool withSubprojects}) {
    for (String? id = ws.rootProjectOf(t.id); id != null;) {
      final project = ws.project(id);
      if (project == null) return false;
      final names = [
        project.name,
        if (project.isInbox) ...['Inbox', 'Входящие'],
      ];
      if (names.any(name.matches)) return true;
      if (!withSubprojects) return false;
      id = ws.projectParent(id);
    }
    return false;
  }

  /// Все слова — в видимом тексте названия, в любом порядке (help).
  bool _search(Task t, List<String> words) {
    final text = foldText(plainText(t.content));
    return words.every((w) => text.contains(foldText(w)));
  }

  /// Дата от сегодня на [days] дней вперёд, сегодня включительно.
  bool _within(String? date, int days) {
    if (date == null || date.compareTo(today) < 0) return false;
    final last = _iso(_todayDay.add(Duration(days: days - 1)));
    return date.compareTo(last) <= 0;
  }

  bool _date(DateNode node, Task t) {
    final due = t.due;
    bool scheduled() =>
        due != null && _compare(node, due.date, _minutes(due.time));
    bool deadline() => t.deadline != null && _compare(node, t.deadline!, null);
    return switch (node.field) {
      DateField.scheduled => scheduled(),
      DateField.scheduledOrDeadline => scheduled() || deadline(),
      DateField.deadline => deadline(),
      DateField.created => switch (t.addedAt) {
        null => false,
        final added => switch (wallOf(added)) {
          null => false,
          final at => _compare(node, _iso(at), at.hour * 60 + at.minute),
        },
      },
    };
  }

  /// Дата задачи [date] (и время [minutes], если есть) против значения
  /// условия. Значение без времени — сравнение по дням. Со временем — в его
  /// день сравнивается и время, а задача без времени в этот день не «до» и
  /// не «после» (допущение, О-69): `date before: +4 hours` — просроченные и
  /// задачи до этого часа.
  static bool _compare(DateNode node, String date, int? minutes) {
    final value = node.value;
    final byDay = date.compareTo(value.date);
    final at = value.minutes;
    return switch (node.relation) {
      DateRelation.on => byDay == 0,
      DateRelation.before =>
        byDay < 0 ||
            (byDay == 0 && at != null && minutes != null && minutes < at),
      DateRelation.after =>
        byDay > 0 ||
            (byDay == 0 && at != null && minutes != null && minutes > at),
    };
  }
}
