import '../../../domain/filter_query.dart';
import '../../../domain/models.dart';
import '../../../domain/workspace.dart';

/// Значения новой задачи, добавленной на экране фильтра (решение 1А plans/m5
/// «Решения M5.3»; в help не описано — допущение, О-69). `null` у поля и
/// пустые метки — без подстановки: проект — «Входящие».
final class FilterAddValues {
  const FilterAddValues({
    this.projectId,
    this.sectionId,
    this.labelIds = const {},
    this.priority,
    this.due,
    this.deadline,
  });

  final String? projectId;
  final String? sectionId;
  final Set<String> labelIds;
  final int? priority;

  /// Срок — дата без времени и повтора.
  final Due? due;

  /// Дедлайн `YYYY-MM-DD`.
  final String? deadline;
}

/// Значения части запроса [node] по снимку [ws]: берутся только условия,
/// связанные `&` на верхнем уровне части, и только однозначные — проект `#`
/// и `##`, раздел `/` этого проекта, метки `%`/`@` (имена без `*`, существуют и
/// не повторяются), приоритет, дата и дедлайн на один день (`today`, `date:
/// Jan 3`, `deadline: tomorrow`). Под `|` и `!`, диапазоны (`before`,
/// `after`, `N days`) и условия без значения не подставляются. Два разных
/// значения одного поля (`p1 & p2`) — поле не подставляется: задача в фильтр
/// всё равно не попадёт.
FilterAddValues filterAddValues(Workspace ws, FilterNode node) {
  final terms = <FilterNode>[];
  void flatten(FilterNode n) {
    if (n case AndNode(:final left, :final right)) {
      flatten(left);
      flatten(right);
    } else {
      terms.add(n);
    }
  }

  flatten(node);
  final projectId = _agreed([
    for (final t in terms)
      if (t case ProjectNode(:final name)) _project(ws, name),
  ]);
  final sectionId = projectId == null
      ? null
      : _agreed([
          for (final t in terms)
            if (t case SectionNode(:final name))
              _single([
                for (final s in ws.sectionsOf(projectId))
                  if (name.exact && name.matches(s.name)) s.id,
              ]),
        ]);
  final labelIds = {
    for (final t in terms)
      if (t case LabelNode(:final name))
        ?_single([
          for (final l in ws.labels)
            if (name.exact && name.matches(l.name)) l.id,
        ]),
  };
  final priority = _agreed([
    for (final t in terms)
      if (t case PriorityNode(:final priority)) priority,
  ]);
  final date = _agreed([
    for (final t in terms)
      if (t case DateNode(
        field: DateField.scheduled || DateField.scheduledOrDeadline,
        relation: DateRelation.on,
        :final value,
      ))
        value.date,
  ]);
  final deadline = _agreed([
    for (final t in terms)
      if (t case DateNode(
        field: DateField.deadline,
        relation: DateRelation.on,
        :final value,
      ))
        value.date,
  ]);
  return FilterAddValues(
    projectId: projectId,
    sectionId: sectionId,
    labelIds: labelIds,
    priority: priority,
    due: date == null ? null : Due(date: date),
    deadline: deadline,
  );
}

/// Активный проект с именем [name] (без `*`), если он один; «Входящие» — и
/// под именами `Inbox` / «Входящие», как при вычислении фильтра.
String? _project(Workspace ws, NamePattern name) {
  if (!name.exact) return null;
  final inbox = ws.inbox;
  return _single([
    if (inbox != null && [inbox.name, 'Inbox', 'Входящие'].any(name.matches))
      inbox.id,
    for (final item in ws.projectTree(expandCollapsed: true))
      if (name.matches(item.value.name)) item.value.id,
  ]);
}

/// Единственное значение списка; пусто или несколько — `null`.
T? _single<T>(List<T> values) => values.length == 1 ? values.single : null;

/// Общее значение всех условий поля: нет условий, неоднозначное условие
/// (`null`) или разные значения — `null`.
T? _agreed<T>(List<T?> values) {
  if (values.isEmpty || values.contains(null)) return null;
  return values.toSet().length == 1 ? values.first : null;
}
