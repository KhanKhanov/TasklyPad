import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/data_providers.dart';
import '../../../app/theme/app_palette.dart';
import '../../../core/clock.dart';
import '../../../domain/filter_engine.dart';
import '../../../domain/models.dart';
import '../../../domain/tree.dart';
import '../../../domain/view_options.dart';
import '../../../domain/view_order.dart';
import '../../../domain/workspace.dart';
import '../../../l10n/app_localizations.dart';
import '../../tasks/state/today.dart';
import '../../tasks/ui/task_list.dart';
import '../../views/ui/grouped_task_list.dart';
import '../../views/ui/view_groups.dart';
import '../logic/filter_add_values.dart';

/// Список экрана фильтра, где открыт редактор «Добавить задачу», и его место.
typedef FilterAdding = ({int list, AddTaskAt at});

/// Списки экрана фильтра: по одному на часть запроса через `,` (help
/// «Introduction to filters»), над каждым при нескольких — текст части
/// (допущение, О-69). Список плоский, подзадача — своей строкой; на
/// компьютере у задачи с подзадачами — стрелка, раскрывает под ней все её
/// активные подзадачи только на этом экране (help: «On web and desktop, you
/// can expand a task to see its sub-tasks»; на телефоне — нет; решение 2А
/// plans/m5). При группировке «Отображения» — группы внутри списка, без
/// раскрытия. «Добавить задачу» — со значениями части ([values], решение 1А).
class FilterLists extends ConsumerWidget {
  const FilterLists({
    super.key,
    required this.lists,
    required this.values,
    required this.ws,
    required this.inboxId,
    required this.grouping,
    required this.adding,
    required this.onAdd,
    required this.expanded,
    required this.onToggle,
  });

  final List<FilterList> lists;

  /// Значения новой задачи каждого списка — по порядку [lists].
  final List<FilterAddValues> values;
  final Workspace ws;
  final String inboxId;
  final Grouping grouping;
  final FilterAdding adding;
  final void Function(int list, AddTaskAt at) onAdd;

  /// Задачи с раскрытыми подзадачами.
  final Set<String> expanded;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final canExpand = !_phone(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, list) in lists.indexed) ...[
          if (lists.length > 1)
            Container(
              key: ValueKey('filterList-$i'),
              margin: EdgeInsets.only(top: i == 0 ? 8 : 24),
              padding: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: palette.divider)),
              ),
              child: Text(
                list.title,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          if (list.tasks.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                l10n.filterPreview(0),
                style: TextStyle(color: palette.textSecondary),
              ),
            ),
          if (grouping != Grouping.none && list.tasks.isNotEmpty)
            GroupedTaskList(
              groups: _groups(ref, list),
              grouping: grouping,
              ws: ws,
              place: (
                projectId: values[i].projectId ?? inboxId,
                labelIds: values[i].labelIds,
                due: values[i].due,
                priority: values[i].priority,
                deadline: values[i].deadline,
              ),
              addAt: adding.list == i ? adding.at : AddTaskAt.none,
              onAddAt: (at) => onAdd(i, at),
              // Открыт один редактор на экране: редактор группы другого
              // списка закрывает свой.
              editorElsewhere: adding.list != i,
              showProject: true,
            )
          else
            TaskList(
              items: filterItems(ws, list, expanded, expandable: canExpand),
              ws: ws,
              projectId: values[i].projectId ?? inboxId,
              sectionId: values[i].sectionId,
              labelIds: values[i].labelIds,
              due: values[i].due,
              priority: values[i].priority,
              deadline: values[i].deadline,
              showProject: true,
              hierarchy: false,
              collapseOf: canExpand
                  ? (item) => item.depth == 0
                        ? (
                            collapsed: !expanded.contains(item.value.id),
                            toggle: () => onToggle(item.value.id),
                          )
                        : null
                  : null,
              addAt: adding.list == i ? adding.at : AddTaskAt.none,
              onAddAt: (at) => onAdd(i, at),
            ),
        ],
      ],
    );
  }

  List<TaskGroup> _groups(WidgetRef ref, FilterList list) => filterGroups(
    ws,
    list,
    grouping,
    today: ref.read(todayProvider),
    clock: ref.read(clockProvider),
  );

  /// Телефон (Android, iOS): задачу в фильтре не раскрыть (help).
  static bool _phone(BuildContext context) =>
      switch (Theme.of(context).platform) {
        TargetPlatform.android || TargetPlatform.iOS => true,
        _ => false,
      };
}

/// Строки плоского списка фильтра: задачи списка, под раскрытой ([expanded])
/// — её активные подзадачи деревом со сдвигом. У задачи списка число
/// прямых подзадач — для стрелки; у подзадач — `0`: раскрывается только
/// задача списка, её подзадачи видны все. Без [expandable] (телефон) — у всех
/// `0`: ни стрелки, ни сворачивания нажатием, которое записало бы поле
/// задачи. Задача списка, видная под раскрытым предком, своей строкой не
/// повторяется: строка на задачу одна (ключ строки — id).
List<TreeItem<Task>> filterItems(
  Workspace ws,
  FilterList list,
  Set<String> expanded, {
  required bool expandable,
}) {
  bool open(Task t) => expandable && expanded.contains(t.id);
  final nested = {
    for (final t in list.tasks)
      if (open(t))
        for (final s in ws.subtasksOf(t.id)) s.value.id,
  };
  return [
    for (final t in list.tasks)
      if (!nested.contains(t.id))
        if (ws.subtasksOf(t.id) case final subtasks) ...[
          TreeItem(
            t,
            0,
            expandable ? subtasks.where((s) => s.depth == 0).length : 0,
          ),
          if (open(t))
            for (final s in subtasks) TreeItem(s.value, s.depth + 1, 0),
        ],
  ];
}

/// Группы «Отображения» [grouping] одного списка фильтра, в его порядке.
List<TaskGroup> filterGroups(
  Workspace ws,
  FilterList list,
  Grouping grouping, {
  required DateTime today,
  required AppClock clock,
}) => groupsFor(
  ws,
  list.tasks,
  grouping,
  order: list.order,
  today: today,
  clock: clock,
);

/// Id задач списков по порядку экрана, с раскрытыми подзадачами, без
/// повторов (задача в двух частях запроса, в двух группах, задача списка и
/// подзадача раскрытой), — соседи для `J` / `K` в панели задачи.
List<String> filterOrder(
  Workspace ws,
  List<FilterList> lists,
  Grouping grouping, {
  required Set<String> expanded,
  required DateTime today,
  required AppClock clock,
}) => {
  for (final list in lists)
    if (grouping == Grouping.none)
      for (final item in filterItems(ws, list, expanded, expandable: true))
        item.value.id
    else
      ...groupedOrder(
        filterGroups(ws, list, grouping, today: today, clock: clock),
      ),
}.toList();
