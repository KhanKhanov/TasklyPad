import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_palette.dart';
import '../../../domain/models.dart';
import '../../../domain/tree.dart';
import '../../../domain/view_options.dart';
import '../../../domain/view_order.dart';
import '../../../domain/workspace.dart';
import '../../../l10n/app_localizations.dart';
import '../../common/ui/ui_kit.dart';
import '../../tasks/state/today.dart';
import '../../tasks/ui/add_task_editor.dart';
import '../../tasks/ui/task_list.dart';
import '../../tasks/ui/task_row.dart';
import 'day_titles.dart';

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
    this.overdueAction,
    this.keepsInView,
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

  /// Кнопка в заголовке «Просрочено» — «Перенести» в «Сегодня» при
  /// группировке по сроку (help «Plan your week with the Upcoming view»:
  /// «Reschedule» видна только при группировке по дате).
  final Widget? overdueAction;

  /// Задача со значением группы останется в виде; нет — у группы нет
  /// «Добавить задачу» (в «Сегодня» с «Выполненными задачами» есть группы
  /// других дней — задача с их сроком из вида сразу бы ушла).
  final bool Function(GroupValue value)? keepsInView;

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

  /// Значение группы [key] поверх места вида: поля, которых группа не
  /// задаёт, — как у вида (в «Сегодня» задача группы P1 получает и срок
  /// сегодня, иначе ушла бы из вида).
  GroupValue? _valueOf(TaskGroupKey key) {
    final p = widget.place;
    return switch ((key, widget.grouping)) {
      (DayGroup(:final date), Grouping.dueDate) => (
        projectId: p.projectId,
        labelIds: p.labelIds,
        due: Due(date: date),
        priority: p.priority,
        deadline: p.deadline,
      ),
      (DayGroup(:final date), Grouping.deadline) => (
        projectId: p.projectId,
        labelIds: p.labelIds,
        due: p.due,
        priority: p.priority,
        deadline: date,
      ),
      (PriorityGroup(:final priority), _) => (
        projectId: p.projectId,
        labelIds: p.labelIds,
        due: p.due,
        priority: priority,
        deadline: p.deadline,
      ),
      // Удалённая метка видна на выполненных до удаления задачах — новой
      // задаче её не поставить.
      (LabelGroup(:final labelId), _) when widget.ws.label(labelId) != null => (
        projectId: p.projectId,
        labelIds: {...p.labelIds, labelId},
        due: p.due,
        priority: p.priority,
        deadline: p.deadline,
      ),
      (ProjectGroup(:final projectId), _) => (
        projectId: projectId,
        labelIds: p.labelIds,
        due: p.due,
        priority: p.priority,
        deadline: p.deadline,
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
        _GroupHeader(
          group: group,
          grouping: widget.grouping,
          ws: widget.ws,
          action: group.key is OverdueGroup ? widget.overdueAction : null,
        ),
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
          if (_valueOf(group.key) case final value?
              when widget.keepsInView?.call(value) ?? true)
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
    this.action,
  });

  final TaskGroup group;
  final Grouping grouping;
  final Workspace ws;
  final Widget? action;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final count = group.tasks.where((t) => !t.isCompleted).length;
    final title = switch (group.key) {
      OverdueGroup() => l10n.groupOverdue,
      DayGroup(:final date) => dayTitle(
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
      // Название с числом занимают всё место до кнопки, а кнопка — у правого
      // края (`Flexible` и `Spacer` делили бы место пополам).
      child: Row(
        children: [
          Expanded(
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
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}
