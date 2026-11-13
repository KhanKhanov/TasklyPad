import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/data_providers.dart';
import '../../../domain/models.dart';
import '../../../domain/tree.dart';
import '../../../domain/view_options.dart';
import '../../../domain/view_order.dart';
import '../../../domain/workspace.dart';
import '../../../l10n/app_localizations.dart';
import '../../common/ui/drag_rows.dart';
import '../../common/ui/layout.dart';
import '../../common/ui/ui_kit.dart';
import '../../shell/ui/shell_keys.dart';
import '../../tasks/logic/due_dates.dart';
import '../../tasks/state/today.dart';
import '../../tasks/ui/task_actions.dart';
import '../../tasks/ui/task_drag.dart';
import '../../tasks/ui/task_drop_places.dart';
import '../../tasks/ui/task_list.dart';
import '../../tasks/ui/task_order.dart';
import '../state/view_options.dart';
import 'day_titles.dart';
import 'grouped_task_list.dart';
import 'overdue_block.dart';
import 'tomorrow_drop_zone.dart';
import 'view_groups.dart';
import 'view_parts.dart';
import 'view_sort_keys.dart';

/// «Сегодня» (help «Plan your day with the Today view»): задачи со сроком на
/// сегодня из всех проектов, сверху — «Просрочено» с «Перенести»; новая
/// задача — во «Входящие» со сроком сегодня. «Отображение» — сортировка с
/// «Умная» и «Вручную», группировка, «Выполненные задачи» — выполненное
/// сегодня (решение 1А «Ход M4.6»). Хоткеи `a`, `Shift+A`, `D` / `P` / `N`.
class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  AddTaskAt _addAt = AddTaskAt.none;

  /// Задачи экрана: просроченные, на сегодня (с выполненными сегодня) и
  /// группы, если выбрана группировка.
  ({List<Task> overdue, List<Task> today, List<TaskGroup> groups}) _content(
    Workspace ws,
    ViewOptions options,
  ) {
    final today = ref.read(todayProvider);
    final iso = isoDate(today);
    final clock = ref.read(clockProvider);
    TaskOrder order(DefaultOrder fallback) => _taskOrder(ws, options, fallback);
    final overdue = ws.overdueTasks(iso, order: order(DefaultOrder.overdue));
    final tasks = ws.todayTasks(
      iso,
      order: order(DefaultOrder.smart),
      completedDay: options.showCompletedTasks ? localDayBy(clock) : null,
    );
    if (options.grouping == Grouping.none) {
      return (overdue: overdue, today: tasks, groups: const []);
    }
    return (
      overdue: const [],
      today: const [],
      groups: groupsFor(
        ws,
        [...overdue, ...tasks],
        options.grouping,
        order: order(DefaultOrder.smart),
        overdueOrder: order(DefaultOrder.overdue),
        today: today,
        clock: clock,
      ),
    );
  }

  TaskOrder _taskOrder(
    Workspace ws,
    ViewOptions options,
    DefaultOrder fallback,
  ) => ws.taskOrder(
    fallback,
    sorting: options.sorting,
    sortOrder: options.sortOrder,
  );

  List<String> _order(Workspace ws) {
    final content = _content(ws, _options());
    return content.groups.isEmpty
        ? [
            for (final t in [...content.overdue, ...content.today]) t.id,
          ]
        : groupedOrder(content.groups);
  }

  ViewOptions _options({bool watch = false}) {
    final provider = viewOptionsProvider(ViewType.today, null);
    return watch ? ref.watch(provider) : ref.read(provider);
  }

  /// Заголовок дня под «Просрочено»: на него можно бросить просроченную, когда
  /// на сегодня активных задач нет (решение 3А «Ход M4.9»).
  Widget _dayHeader(Widget header, String date, bool drags) =>
      drags ? DayDropSlot(date: date, child: header) : header;

  @override
  Widget build(BuildContext context) => WorkspaceView(builder: _build);

  Widget _build(BuildContext context, Workspace ws) {
    final l10n = AppLocalizations.of(context);
    final inbox = ws.inbox;
    if (inbox == null) return Center(child: Text(l10n.rejectNotFound));
    final options = _options(watch: true);
    // Подписка: в полночь «сегодня» становится «просрочено».
    final today = ref.watch(todayProvider);
    final due = Due(date: isoDate(today));
    final content = _content(ws, options);
    final grouped = options.grouping != Grouping.none;
    final drags = options.allowsDrag;
    final tomorrow = isoDate(DateTime(today.year, today.month, today.day + 1));
    final empty =
        content.overdue.isEmpty &&
        content.today.isEmpty &&
        content.groups.isEmpty &&
        _addAt == AddTaskAt.none;
    return ViewSortKeys(
      viewType: ViewType.today,
      child: Shortcuts(
        shortcuts: projectShortcuts,
        child: Actions(
          actions: {
            AddTaskBottomIntent: HotkeyAction<AddTaskBottomIntent>(
              blocked: () => ShellKeys.sequencePending(context),
              () => setState(() => _addAt = AddTaskAt.bottom),
            ),
            AddTaskTopIntent: HotkeyAction<AddTaskTopIntent>(
              blocked: () => ShellKeys.sequencePending(context),
              () => setState(() => _addAt = AddTaskAt.top),
            ),
          },
          child: Focus(
            autofocus: true,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: contentMaxWidth),
                child: TaskOrderScope(
                  order: _order,
                  child: CustomScrollView(
                    slivers: [
                      // Слева 12 + поле под ручку 20 у строк и заголовков.
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 32, 0),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            DragGutter(
                              child: ViewHeader(
                                title: l10n.todayView,
                                viewType: ViewType.today,
                              ),
                            ),
                            if (grouped)
                              DragGutter(
                                child: GroupedTaskList(
                                  groups: content.groups,
                                  grouping: options.grouping,
                                  ws: ws,
                                  place: (
                                    projectId: inbox.id,
                                    labelIds: const {},
                                    due: due,
                                    priority: null,
                                    deadline: null,
                                  ),
                                  addAt: _addAt,
                                  onAddAt: (at) => setState(() => _addAt = at),
                                  showProject: true,
                                  keepsInView: (value) => value.due == due,
                                  overdueAction:
                                      options.grouping == Grouping.dueDate
                                      ? RescheduleButton(
                                          ids: [
                                            for (final g in content.groups)
                                              if (g.key is OverdueGroup)
                                                for (final t in g.tasks) t.id,
                                          ],
                                        )
                                      : null,
                                ),
                              )
                            else ...[
                              if (content.overdue.isNotEmpty) ...[
                                OverdueBlock(
                                  tasks: content.overdue,
                                  ws: ws,
                                  draggable: drags,
                                ),
                                DragGutter(
                                  child: _dayHeader(
                                    DayHeader(
                                      title: fullDayTitle(
                                        context,
                                        due.date,
                                        today,
                                      ),
                                    ),
                                    due.date,
                                    drags,
                                  ),
                                ),
                              ],
                              TaskList(
                                // Плоский список: подзадача — своей строкой.
                                items: [
                                  for (final t in content.today)
                                    TreeItem(t, 0, 0),
                                ],
                                ws: ws,
                                projectId: inbox.id,
                                due: due,
                                showProject: true,
                                hierarchy: false,
                                addAt: _addAt,
                                onAddAt: (at) => setState(() => _addAt = at),
                                gutter: true,
                                // Всё ниже последней активной строки — зона
                                // «на завтра».
                                drop: drags
                                    ? DayDrop(
                                        date: due.date,
                                        sorting: options.sorting,
                                        order: _taskOrder(
                                          ws,
                                          options,
                                          DefaultOrder.smart,
                                        ),
                                        tomorrow: tomorrow,
                                        tomorrowLabel: l10n.dueTomorrow,
                                      )
                                    : null,
                              ),
                            ],
                            if (empty) const DragGutter(child: ViewEmpty()),
                          ]),
                        ),
                      ),
                      if (drags && !grouped)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: TomorrowDropZone(
                              date: tomorrow,
                              label: l10n.dueTomorrow,
                            ),
                          ),
                        )
                      else
                        const SliverToBoxAdapter(child: SizedBox(height: 48)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
