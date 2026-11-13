import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/data_providers.dart';
import '../../../core/clock.dart';
import '../../../app/theme/app_palette.dart';
import '../../../domain/filter_engine.dart';
import '../../../domain/view_order.dart';
import '../../../domain/tree.dart';
import '../../../domain/view_options.dart';
import '../../../domain/workspace.dart';
import '../../../l10n/app_localizations.dart';
import '../../tasks/state/today.dart';
import '../../tasks/ui/task_list.dart';
import '../../views/ui/grouped_task_list.dart';
import '../../views/ui/view_groups.dart';

/// Списки экрана фильтра: по одному на часть запроса через `,` (help
/// «Introduction to filters»), над каждым при нескольких — текст части
/// (допущение, О-69). Список плоский, подзадача — своей строкой; при
/// группировке «Отображения» — группы внутри списка.
class FilterLists extends ConsumerWidget {
  const FilterLists({
    super.key,
    required this.lists,
    required this.ws,
    required this.inboxId,
    required this.grouping,
  });

  final List<FilterList> lists;
  final Workspace ws;
  final String inboxId;
  final Grouping grouping;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
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
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                l10n.filterPreview(0),
                style: TextStyle(color: palette.textSecondary),
              ),
            )
          else if (grouping != Grouping.none)
            GroupedTaskList(
              groups: _groups(ref, list),
              grouping: grouping,
              ws: ws,
              place: (
                projectId: inboxId,
                labelIds: const {},
                due: null,
                priority: null,
                deadline: null,
              ),
              addAt: AddTaskAt.none,
              onAddAt: (_) {},
              canAdd: false,
              showProject: true,
            )
          else
            TaskList(
              items: [for (final t in list.tasks) TreeItem(t, 0, 0)],
              ws: ws,
              projectId: inboxId,
              showProject: true,
              hierarchy: false,
              canAdd: false,
              addAt: AddTaskAt.none,
              onAddAt: (_) {},
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

/// Id задач списков по порядку экрана, без повторов (задача в двух частях
/// запроса или в двух группах), — соседи для `J` / `K` в панели задачи.
List<String> filterOrder(
  Workspace ws,
  List<FilterList> lists,
  Grouping grouping, {
  required DateTime today,
  required AppClock clock,
}) => {
  for (final list in lists)
    if (grouping == Grouping.none)
      for (final t in list.tasks) t.id
    else
      ...groupedOrder(
        filterGroups(ws, list, grouping, today: today, clock: clock),
      ),
}.toList();
