import 'package:freezed_annotation/freezed_annotation.dart';

import 'markdown_text.dart';
import 'models.dart';
import 'text_fold.dart';
import 'view_options.dart';

part 'view_order.freezed.dart';

// Порядок и группы задач вида (решения 2 и 3 плана M4, «Ход M4.4»). Что
// написано в help «Sort or group tasks» и «Default sorting order»:
// сортировка идёт внутри раздела и среди соседей одного родителя; обратное
// направление меняет только первый критерий, дальше — порядок вида по
// умолчанию; задачи без даты по возрастанию внизу; приоритет — P1 → P4.
// Порядок групп, дедлайн и регистр имени — допущения (О-69).

/// Порядок вида по умолчанию (help «Default sorting order»).
enum DefaultOrder {
  /// Проект — ручной порядок.
  manual,

  /// «Сегодня» и «Предстоящее»: дата и время → приоритет → дедлайн → ручной
  /// порядок дня → время создания.
  smart,

  /// «Просрочено» — как [smart], без ручного порядка дня: просроченные
  /// вручную не сортируются (help).
  overdue,

  /// Метка и фильтр без условий на дату: приоритет → дата и время → дедлайн
  /// → порядок проектов → порядок задач.
  label,

  /// Фильтр с условием на дату (О-85): дата и время, а без даты — дедлайн →
  /// приоритет → дедлайн → ручной порядок дня → время создания. «С датами» —
  /// в запросе есть условие на дату или дедлайн (толкование — допущение,
  /// О-69).
  filterDated,
}

/// Сравнение задач вида: выбранная сортировка ([sorting], [sortOrder]),
/// при равенстве — порядок вида [fallback], последним — id (порядок
/// одинаков на всех устройствах). Создаёт её `Workspace.taskOrder`: порядок
/// проектов [projectRank] — из снимка.
final class TaskOrder {
  const TaskOrder({
    required this.fallback,
    required this.projectRank,
    this.sorting = Sorting.byDefault,
    this.sortOrder = SortOrder.asc,
    this.nameOf = _content,
  });

  final DefaultOrder fallback;
  final Sorting sorting;
  final SortOrder sortOrder;

  /// Имя задачи для сортировки по имени — функцией; по умолчанию видимый
  /// текст названия без символов markdown ([plainText]).
  final String Function(Task) nameOf;

  /// Место задачи в порядке проектов и задач деревом — для порядка метки и
  /// ручного порядка: у задач разных родителей (группа) ключи порядка
  /// несравнимы, у соседей место повторяет ключ.
  final int Function(Task) projectRank;

  static String _content(Task t) => plainText(t.content);

  /// Отрицательное — [a] выше [b].
  int compare(Task a, Task b) {
    final primary = _primary(a, b);
    if (primary != 0) {
      // У «Вручную» направления нет — и `desc` из импорта его не разворачивает.
      final reversed = sortOrder == SortOrder.desc && sorting.hasDirection;
      return reversed ? -primary : primary;
    }
    final byDefault = _byDefault(a, b);
    return byDefault != 0 ? byDefault : a.id.compareTo(b.id);
  }

  /// В умном порядке [a] и [b] различает только ручной порядок дня: тот же
  /// срок, приоритет и дедлайн (help «Default sorting order»). Перестановка
  /// при «Умной» возможна только среди таких задач (решение 1А «Ход M4.9»).
  bool sameBeforeDayOrder(Task a, Task b) =>
      _byDue(a, b) == 0 &&
      _byPriority(a, b) == 0 &&
      _nullsLast(a.deadline, b.deadline) == 0;

  int _primary(Task a, Task b) => switch (sorting) {
    Sorting.byDefault => 0,
    // «Вручную» — в проекте, «Сегодня» и «Предстоящем» (help «Sort or group
    // tasks»). В «Сегодня» и «Предстоящем» — ручной порядок дня первым,
    // задачи без него — ниже в умном порядке (решение 1А «Ход M4.6»);
    // «Просрочено» вручную не сортируется, у метки «Вручную» нет.
    Sorting.manual => switch (fallback) {
      DefaultOrder.manual => _tree(a, b),
      DefaultOrder.smart => _nullsLast(
        _orNull(a.dayOrderKey),
        _orNull(b.dayOrderKey),
      ),
      DefaultOrder.overdue ||
      DefaultOrder.label ||
      DefaultOrder.filterDated => 0,
    },
    Sorting.alphabetically => _byName(a, b),
    Sorting.dueDate => _byDue(a, b),
    Sorting.addedDate => _nullsLast(a.addedAt, b.addedAt),
    Sorting.deadline => _nullsLast(a.deadline, b.deadline),
    Sorting.priority => _byPriority(a, b),
  };

  int _byDefault(Task a, Task b) {
    int first(List<int Function()> steps) {
      for (final step in steps) {
        final result = step();
        if (result != 0) return result;
      }
      return 0;
    }

    return switch (fallback) {
      DefaultOrder.manual => _tree(a, b),
      DefaultOrder.smart || DefaultOrder.overdue => first([
        () => _byDue(a, b),
        () => _byPriority(a, b),
        () => _nullsLast(a.deadline, b.deadline),
        if (fallback == DefaultOrder.smart)
          () => _nullsLast(_orNull(a.dayOrderKey), _orNull(b.dayOrderKey)),
        () => _nullsLast(a.addedAt, b.addedAt),
      ]),
      DefaultOrder.label => first([
        () => _byPriority(a, b),
        () => _byDue(a, b),
        () => _nullsLast(a.deadline, b.deadline),
        () => _tree(a, b),
      ]),
      DefaultOrder.filterDated => first([
        () => _nullsLast(_dueOrDeadlineKey(a), _dueOrDeadlineKey(b)),
        () => _byPriority(a, b),
        () => _nullsLast(a.deadline, b.deadline),
        () => _nullsLast(_orNull(a.dayOrderKey), _orNull(b.dayOrderKey)),
        () => _nullsLast(a.addedAt, b.addedAt),
      ]),
    };
  }

  int _tree(Task a, Task b) {
    final byRank = projectRank(a).compareTo(projectRank(b));
    return byRank != 0 ? byRank : a.orderKey.compareTo(b.orderKey);
  }

  static int _byPriority(Task a, Task b) => a.priority.compareTo(b.priority);

  /// Срок без времени — перед сроками со временем того же дня (допущение,
  /// О-69); без срока — внизу.
  static int _byDue(Task a, Task b) => _nullsLast(_dueKey(a), _dueKey(b));

  static String? _dueKey(Task t) => switch (t.due) {
    null => null,
    Due(:final date, :final time) => '$date ${time ?? ''}',
  };

  /// Дата и время, а без даты — дедлайн как дата без времени (О-85).
  static String? _dueOrDeadlineKey(Task t) =>
      _dueKey(t) ??
      switch (t.deadline) {
        null => null,
        final deadline => '$deadline ',
      };

  /// Без учёта регистра и «ё» как «е», при равенстве — как написано
  /// (допущение, О-69): код «ё» больше кода «я», и «Ёлка» ушла бы в конец.
  int _byName(Task a, Task b) {
    final (x, y) = (nameOf(a), nameOf(b));
    final folded = foldText(x).compareTo(foldText(y));
    return folded != 0 ? folded : x.compareTo(y);
  }

  static String? _orNull(String key) => key.isEmpty ? null : key;

  static int _nullsLast(String? a, String? b) => a == null
      ? (b == null ? 0 : 1)
      : b == null
      ? -1
      : a.compareTo(b);
}

/// Группа задач вида. Подпись пустой группы зависит от группировки: «Без
/// срока», «Без дедлайна», «Без метки».
@freezed
sealed class TaskGroupKey with _$TaskGroupKey {
  /// Срок или дедлайн раньше сегодняшнего дня.
  const factory TaskGroupKey.overdue() = OverdueGroup;

  /// День `YYYY-MM-DD`: срок, дедлайн или дата добавления.
  const factory TaskGroupKey.day(String date) = DayGroup;
  const factory TaskGroupKey.priority(int priority) = PriorityGroup;
  const factory TaskGroupKey.label(String labelId) = LabelGroup;
  const factory TaskGroupKey.project(String projectId) = ProjectGroup;

  /// Значения нет: без срока, дедлайна или метки.
  const factory TaskGroupKey.empty() = EmptyGroup;
}

/// Группа и её задачи по порядку вида.
typedef TaskGroup = ({TaskGroupKey key, List<Task> tasks});

/// Задачи [tasks] по группам [grouping] (help «Sort or group tasks»):
/// подзадача — в группе своих значений, не под родителем. Внутри группы —
/// [order]. Порядок групп (допущение, О-69): по сроку и дедлайну —
/// «Просрочено», дни по порядку, пустая последней; по дате добавления —
/// новые дни сверху; по приоритету — P1 → P4; по метке — порядок меток
/// [labelOrder], задача с двумя метками — в обеих, пустая последней; по
/// проекту — порядок проектов [projectOrder]; выполненные — после активных.
/// «Просрочено» — порядок [overdueOrder], если задан: просроченные вручную
/// не сортируются (help «Default sorting order»). [today] — `YYYY-MM-DD`,
/// [localDay] — день по времени UTC ISO-8601 (дата добавления; по умолчанию
/// — день по часовому поясу устройства),
/// [projectOf] — проект задачи по дереву. Пустые группы не выводятся;
/// [Grouping.none] — одна группа [EmptyGroup].
List<TaskGroup> groupTasks(
  Iterable<Task> tasks,
  Grouping grouping, {
  required TaskOrder order,
  required String today,
  TaskOrder? overdueOrder,
  List<String> labelOrder = const [],
  List<String> projectOrder = const [],
  String Function(Task)? projectOf,
  String Function(String utc)? localDay,
}) {
  TaskGroupKey byDay(String? date) => switch (date) {
    null => const TaskGroupKey.empty(),
    final d when d.compareTo(today) < 0 => const TaskGroupKey.overdue(),
    final d => TaskGroupKey.day(d),
  };
  List<TaskGroupKey> keysOf(Task t) => switch (grouping) {
    Grouping.none => const [TaskGroupKey.empty()],
    Grouping.dueDate => [byDay(t.due?.date)],
    Grouping.deadline => [byDay(t.deadline)],
    Grouping.addedDate => [
      switch (t.addedAt) {
        null => const TaskGroupKey.empty(),
        final at => TaskGroupKey.day((localDay ?? _localDay)(at)),
      },
    ],
    Grouping.priority => [TaskGroupKey.priority(t.priority)],
    Grouping.label => [
      if (t.labelIds.isEmpty) const TaskGroupKey.empty(),
      for (final id in t.labelIds) TaskGroupKey.label(id),
    ],
    Grouping.project => [
      TaskGroupKey.project(projectOf?.call(t) ?? t.projectId ?? ''),
    ],
  };
  final groups = <TaskGroupKey, List<Task>>{};
  for (final t in tasks) {
    for (final key in keysOf(t)) {
      (groups[key] ??= []).add(t);
    }
  }
  final labelRank = {for (final (i, id) in labelOrder.indexed) id: i};
  final projectRank = {for (final (i, id) in projectOrder.indexed) id: i};
  int rankOf(TaskGroupKey key) => switch (key) {
    OverdueGroup() => -1,
    PriorityGroup(:final priority) => priority,
    LabelGroup(:final labelId) => labelRank[labelId] ?? labelRank.length,
    ProjectGroup(:final projectId) =>
      projectRank[projectId] ?? projectRank.length,
    DayGroup() || EmptyGroup() => 0,
  };
  int compareKeys(TaskGroupKey a, TaskGroupKey b) {
    if (a is EmptyGroup || b is EmptyGroup) {
      return (a is EmptyGroup ? 1 : 0) - (b is EmptyGroup ? 1 : 0);
    }
    if (a is DayGroup && b is DayGroup) {
      final byDate = a.date.compareTo(b.date);
      return grouping == Grouping.addedDate ? -byDate : byDate;
    }
    final byRank = rankOf(a).compareTo(rankOf(b));
    if (byRank != 0) return byRank;
    // Метки и проекты вне порядка (ещё не пришли) — по id, одинаково везде.
    return switch ((a, b)) {
      (LabelGroup(labelId: final x), LabelGroup(labelId: final y)) ||
      (
        ProjectGroup(projectId: final x),
        ProjectGroup(projectId: final y),
      ) => x.compareTo(y),
      _ => 0,
    };
  }

  // Выполненные — после активных, позже выполненные выше, как в списке
  // проекта.
  int byState(Task a, Task b, TaskOrder order) {
    if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
    if (!a.isCompleted) return order.compare(a, b);
    final byTime = (b.completedAt ?? '').compareTo(a.completedAt ?? '');
    return byTime != 0 ? byTime : order.compare(a, b);
  }

  return [
    for (final key in groups.keys.toList()..sort(compareKeys))
      for (final within in [
        key is OverdueGroup ? overdueOrder ?? order : order,
      ])
        (key: key, tasks: groups[key]!..sort((a, b) => byState(a, b, within))),
  ];
}

/// День `YYYY-MM-DD` по часовому поясу устройства для времени UTC
/// ISO-8601; неразборчивое время — его первые 10 символов.
String _localDay(String utc) {
  final at = DateTime.tryParse(utc)?.toLocal();
  if (at == null) return utc.length >= 10 ? utc.substring(0, 10) : utc;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${at.year.toString().padLeft(4, '0')}-${two(at.month)}-${two(at.day)}';
}
