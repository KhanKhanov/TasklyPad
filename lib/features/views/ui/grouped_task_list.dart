import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_palette.dart';
import '../../../core/clock.dart';
import '../../../domain/models.dart';
import '../../../domain/tree.dart';
import '../../../domain/view_options.dart';
import '../../../domain/view_order.dart';
import '../../../domain/workspace.dart';
import '../../../l10n/app_localizations.dart';
import '../../common/ui/ui_kit.dart';
import '../../tasks/logic/due_dates.dart';
import '../../tasks/state/today.dart';
import '../../tasks/ui/add_task_editor.dart';
import '../../tasks/ui/due_ui.dart';
import '../../tasks/ui/task_list.dart';
import '../../tasks/ui/task_row.dart';

/// Значение группы, которое получает добавленная в неё задача.
typedef GroupValue = ({
  String projectId,
  Set<String> labelIds,
  Due? due,
  int? priority,
  String? deadline,
});

/// Задачи вида по группам «Отображения» (help «Sort or group tasks»):
/// заголовок группы, задачи плоским списком (подзадача — в группе своих
/// значений, не под родителем) и «Добавить задачу» внизу группы — новая
/// задача получает значение группы. У «Просрочено», групп без значения и
/// групп по дате добавления кнопки нет (help); значение группы дедлайна —
/// дедлайн (допущение, О-69). Открыт один редактор: группы или верхний — по
/// `a` / `Shift+A` ([addAt]).
class GroupedTaskList extends StatefulWidget {
  const GroupedTaskList({
    super.key,
    required this.groups,
    required this.grouping,
    required this.ws,
    required this.place,
    required this.addAt,
    required this.onAddAt,
    this.canAdd = true,
    this.showProject = false,
  });

  final List<TaskGroup> groups;
  final Grouping grouping;
  final Workspace ws;

  /// Место и метки новой задачи без значения группы: проект экрана или
  /// «Входящие» с меткой экрана метки.
  final GroupValue place;
  final AddTaskAt addAt;
  final ValueChanged<AddTaskAt> onAddAt;

  /// `false` — проект в архиве: задачи только для просмотра.
  final bool canAdd;
  final bool showProject;

  @override
  State<GroupedTaskList> createState() => _GroupedTaskListState();
}

class _GroupedTaskListState extends State<GroupedTaskList> {
  TaskGroupKey? _adding;

  @override
  void didUpdateWidget(GroupedTaskList old) {
    super.didUpdateWidget(old);
    if (widget.addAt != AddTaskAt.none) _adding = null;
  }

  void _open(TaskGroupKey? key) {
    setState(() => _adding = key);
    if (key != null) widget.onAddAt(AddTaskAt.none);
  }

  GroupValue? _valueOf(TaskGroupKey key) {
    final p = widget.place;
    return switch ((key, widget.grouping)) {
      (DayGroup(:final date), Grouping.dueDate) => (
        projectId: p.projectId,
        labelIds: p.labelIds,
        due: Due(date: date),
        priority: null,
        deadline: null,
      ),
      (DayGroup(:final date), Grouping.deadline) => (
        projectId: p.projectId,
        labelIds: p.labelIds,
        due: null,
        priority: null,
        deadline: date,
      ),
      (PriorityGroup(:final priority), _) => (
        projectId: p.projectId,
        labelIds: p.labelIds,
        due: null,
        priority: priority,
        deadline: null,
      ),
      // Удалённая метка видна на выполненных до удаления задачах — новой
      // задаче её не поставить.
      (LabelGroup(:final labelId), _) when widget.ws.label(labelId) != null => (
        projectId: p.projectId,
        labelIds: {...p.labelIds, labelId},
        due: null,
        priority: null,
        deadline: null,
      ),
      (ProjectGroup(:final projectId), _) => (
        projectId: projectId,
        labelIds: p.labelIds,
        due: null,
        priority: null,
        deadline: null,
      ),
      _ => null,
    };
  }

  Widget _editor(GroupValue value, {bool atTop = false}) => AddTaskEditor(
    projectId: value.projectId,
    labelIds: value.labelIds,
    due: value.due,
    priority: value.priority,
    deadline: value.deadline,
    atTop: atTop,
    onClose: () => atTop ? widget.onAddAt(AddTaskAt.none) : _open(null),
  );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (widget.canAdd && widget.addAt != AddTaskAt.none)
        _editor(widget.place, atTop: widget.addAt == AddTaskAt.top)
      else if (widget.canAdd && widget.groups.isEmpty)
        // Групп нет — некуда нажать «Добавить задачу» группы.
        AddTaskButton(onPressed: () => widget.onAddAt(AddTaskAt.bottom)),
      for (final group in widget.groups) ...[
        _GroupHeader(group: group, grouping: widget.grouping, ws: widget.ws),
        for (final task in group.tasks)
          TaskRow(
            key: ValueKey('${group.key}/${task.id}'),
            item: TreeItem(task, 0, 0),
            ws: widget.ws,
            collapsible: false,
            showProject: widget.showProject,
            hierarchy: false,
          ),
        if (widget.canAdd)
          if (_valueOf(group.key) case final value?)
            if (_adding == group.key)
              _editor(value)
            else
              AddTaskButton(onPressed: () => _open(group.key)),
      ],
    ],
  );
}

class _GroupHeader extends ConsumerWidget {
  const _GroupHeader({
    required this.group,
    required this.grouping,
    required this.ws,
  });

  final TaskGroup group;
  final Grouping grouping;
  final Workspace ws;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final count = group.tasks.where((t) => !t.isCompleted).length;
    final title = switch (group.key) {
      OverdueGroup() => l10n.groupOverdue,
      DayGroup(:final date) => _dayTitle(
        context,
        date,
        ref.watch(todayProvider),
      ),
      PriorityGroup(:final priority) => l10n.priorityN(priority),
      // Живая метка — текущее имя; удалённая — как на задачах группы (имя на
      // момент выполнения).
      LabelGroup(:final labelId) =>
        ws.label(labelId)?.name ??
            ws.taskLabel(group.tasks.first, labelId)?.name ??
            '',
      ProjectGroup(:final projectId) => switch (ws.project(projectId)) {
        final project? => projectTitle(l10n, project),
        null => '',
      },
      EmptyGroup() => switch (grouping) {
        Grouping.dueDate => l10n.noDue,
        Grouping.deadline => l10n.noDeadline,
        Grouping.label => l10n.groupNoLabel,
        Grouping.addedDate => l10n.groupNoAddedDate,
        Grouping.none || Grouping.priority || Grouping.project => '',
      },
    };
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.divider)),
      ),
      height: 40,
      child: Row(
        children: [
          Flexible(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: group.key is OverdueGroup
                    ? palette.danger
                    : palette.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (count > 0)
            Text(
              '$count',
              style: TextStyle(color: palette.textSecondary, fontSize: 12),
            ),
        ],
      ),
    );
  }
}

/// Заголовок дня: «5 нояб. · Завтра», «7 нояб. · пятница» на ближайшую
/// неделю, дальше и в прошлом — дата (подписи — О-68).
String _dayTitle(BuildContext context, String date, DateTime today) {
  final day = parseIsoDate(date);
  if (day == null) return date;
  final name = dueLabel(context, date, null, today).text;
  final relative = switch (dueKind(day, today)) {
    DueKind.overdueYesterday ||
    DueKind.today ||
    DueKind.tomorrow ||
    DueKind.thisWeek => true,
    DueKind.overdue || DueKind.later => false,
  };
  if (!relative) return name;
  final locale = Localizations.localeOf(context).toLanguageTag();
  return AppLocalizations.of(context)
      .groupDay(DateFormat.MMMd(locale).format(day), name);
}

/// Группы [grouping] задач [tasks] вида ([Workspace.groupsOf]): «сегодня» —
/// [today] устройства, день добавления — по часам приложения [clock].
List<TaskGroup> groupsFor(
  Workspace ws,
  Iterable<Task> tasks,
  Grouping grouping, {
  required TaskOrder order,
  required DateTime today,
  required AppClock clock,
}) => ws.groupsOf(
  tasks,
  grouping,
  order: order,
  today: isoDate(today),
  localDay: (utc) {
    final at = DateTime.tryParse(utc);
    if (at == null) return utc.length >= 10 ? utc.substring(0, 10) : utc;
    // Пояс устройства сейчас; у дат по другую сторону перехода на летнее
    // время день может сдвинуться у задач, добавленных около полуночи.
    // Округление до минут: два вызова часов расходятся на доли миллисекунды.
    final offset = Duration(
      minutes: (clock.nowWall().difference(clock.nowUtc()).inSeconds / 60)
          .round(),
    );
    return isoDate(at.toUtc().add(offset));
  },
);

/// Id задач групп по порядку, без повторов (задача с двумя метками — в
/// двух группах), — соседи для `J` / `K` в панели задачи.
List<String> groupedOrder(List<TaskGroup> groups) => {
  for (final g in groups)
    for (final t in g.tasks) t.id,
}.toList();
