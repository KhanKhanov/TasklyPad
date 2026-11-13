import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models.dart';
import '../../../domain/view_options.dart';
import '../../../domain/view_order.dart';
import '../../../domain/workspace.dart';
import '../../../l10n/app_localizations.dart';
import '../../common/ui/layout.dart';
import '../../common/ui/ui_kit.dart';
import '../../tasks/logic/due_dates.dart';
import '../../tasks/state/today.dart';
import '../../tasks/ui/task_drag.dart';
import '../../tasks/ui/task_order.dart';
import '../state/upcoming_day.dart';
import '../state/view_options.dart';
import 'day_titles.dart';
import 'overdue_block.dart';
import 'upcoming_day_view.dart';
import 'upcoming_keys.dart';
import 'view_parts.dart';
import 'view_sort_keys.dart';
import 'week_strip.dart';

/// «Предстоящее» (help «Plan your week with the Upcoming view»): полоса
/// недели, сверху «Просрочено» с «Перенести», дальше каждый день на два года
/// вперёд, пустые тоже (допущение, О-69), у дня — «Добавить задачу» с его
/// датой. Выбор дня в полосе прокручивает к нему, прокрутка списка выбирает
/// верхний день (допущение, О-69). Группировки нет (help «Customize views»),
/// сортировка — как в «Сегодня». `a` / `Shift+A` — задача в выбранный день.
class UpcomingScreen extends ConsumerStatefulWidget {
  const UpcomingScreen({super.key});

  @override
  ConsumerState<UpcomingScreen> createState() => _UpcomingScreenState();
}

class _UpcomingScreenState extends ConsumerState<UpcomingScreen> {
  final ScrollController _scroll = ScrollController();
  final GlobalKey _viewport = GlobalKey();
  static const Key _centerKey = ValueKey('upcoming-center');
  static const Key _overdueKey = ValueKey('upcoming-overdue');

  /// День, с которого список стоит в начале (центр прокрутки): дни раньше —
  /// выше него.
  DateTime? _anchor;

  /// День открытого редактора «Добавить задачу».
  String? _adding;

  /// Построенные дни списка — для дня под верхним краем при прокрутке.
  final Map<String, BuildContext> _days = {};

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Выбор дня в полосе: список встаёт на него.
  void _select(DateTime day) {
    ref.read(upcomingDayProvider.notifier).select(isoDate(day));
    setState(() {
      _anchor = day;
      _adding = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(0);
    });
  }

  bool _followPending = false;

  /// Уведомление о прокрутке приходит до раскладки нового кадра — места
  /// дней в нём старые; день ищется после кадра, один раз на кадр.
  void _scheduleFollow() {
    if (_followPending) return;
    _followPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _followPending = false;
      if (mounted) _followScroll();
    });
  }

  /// Выбранный день — верхний видимый день списка.
  void _followScroll() {
    final viewport = _viewport.currentContext?.findRenderObject();
    if (viewport is! RenderBox) return;
    final day = topVisibleDay(_days, viewport);
    if (day != null && day != ref.read(upcomingDayProvider)) {
      ref.read(upcomingDayProvider.notifier).select(day);
    }
  }

  ({List<Task> overdue, Map<String, List<Task>> days}) _content(Workspace ws) {
    final options = ref.read(viewOptionsProvider(ViewType.upcoming, null));
    final today = isoDate(ref.read(todayProvider));
    TaskOrder order(DefaultOrder fallback) => ws.taskOrder(
      fallback,
      sorting: options.sorting,
      sortOrder: options.sortOrder,
    );
    return (
      overdue: ws.overdueTasks(today, order: order(DefaultOrder.overdue)),
      days: ws.upcomingDays(
        today,
        order: order(DefaultOrder.smart),
        showCompleted: options.showCompletedTasks,
      ),
    );
  }

  List<String> _order(Workspace ws) {
    final (:overdue, :days) = _content(ws);
    return [
      for (final t in overdue) t.id,
      for (final tasks in days.values)
        for (final t in tasks) t.id,
    ];
  }

  void _addInSelected() =>
      setState(() => _adding = ref.read(upcomingDayProvider));

  @override
  Widget build(BuildContext context) {
    // В полночь выбранный день снова сегодня — и список встаёт на него.
    ref.listen(todayProvider, (_, today) => _select(today));
    return WorkspaceView(builder: _build);
  }

  Widget _build(BuildContext context, Workspace ws) {
    final l10n = AppLocalizations.of(context);
    final inbox = ws.inbox;
    if (inbox == null) return Center(child: Text(l10n.rejectNotFound));
    // Подписки: настройки вида и смена дня в полночь.
    final options = ref.watch(viewOptionsProvider(ViewType.upcoming, null));
    final drags = options.allowsDrag;
    final dayOrder = ws.taskOrder(
      DefaultOrder.smart,
      sorting: options.sorting,
      sortOrder: options.sortOrder,
    );
    final today = ref.watch(todayProvider);
    final selected = parseIsoDate(ref.watch(upcomingDayProvider)) ?? today;
    final anchor = switch (_anchor) {
      final a? when !a.isBefore(today) => a,
      _ => today,
    };
    final (:overdue, :days) = _content(ws);
    final last = WeekStrip.lastDay(today);
    int index(DateTime day) => DateTime.utc(
      day.year,
      day.month,
      day.day,
    ).difference(DateTime.utc(today.year, today.month, today.day)).inDays;
    final total = index(last) + 1;
    final at = index(anchor);
    Widget day(int i) {
      final date = isoDate(DateTime(today.year, today.month, today.day + i));
      return DayMarker(
        key: ValueKey(date),
        date: date,
        days: _days,
        child: UpcomingDayView(
          date: date,
          title: fullDayTitle(context, date, today),
          tasks: days[date] ?? const [],
          ws: ws,
          inboxId: inbox.id,
          adding: _adding == date,
          drop: drags
              ? DayDrop(date: date, sorting: options.sorting, order: dayOrder)
              : null,
          onAdding: (open) => setState(() {
            _adding = open ? date : null;
            if (open) ref.read(upcomingDayProvider.notifier).select(date);
          }),
        ),
      );
    }

    final overdueSliver = overdue.isEmpty
        ? null
        : SliverToBoxAdapter(
            key: _overdueKey,
            child: OverdueBlock(tasks: overdue, ws: ws, draggable: drags),
          );
    final centerList = SliverList.builder(
      key: _centerKey,
      itemCount: total - at,
      itemBuilder: (_, i) => day(at + i),
    );
    return ViewSortKeys(
      viewType: ViewType.upcoming,
      child: UpcomingKeys(
        selected: selected,
        today: today,
        onSelect: _select,
        onAdd: _addInSelected,
        child: Focus(
          autofocus: true,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: contentMaxWidth),
              // Порядок вида и у заголовка: «Выбрать задачи» в его «⋯».
              child: TaskOrderScope(
                order: _order,
                child: Padding(
                  // Слева 12 + поле под ручку 20 у строк и заголовков.
                  padding: const EdgeInsets.fromLTRB(12, 8, 32, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DragGutter(
                        child: ViewHeader(
                          title: l10n.upcomingView,
                          viewType: ViewType.upcoming,
                        ),
                      ),
                      DragGutter(
                        child: WeekStrip(
                          selected: selected,
                          today: today,
                          onSelect: _select,
                        ),
                      ),
                      Expanded(
                        child: TaskOrderScope(
                          order: _order,
                          child: NotificationListener<ScrollUpdateNotification>(
                            // Только сам список: поле ввода редактора дня
                            // тоже прокручивается (длинное название).
                            onNotification: (n) {
                              if (n.depth == 0 &&
                                  n.metrics.axis == Axis.vertical) {
                                _scheduleFollow();
                              }
                              return false;
                            },
                            child: CustomScrollView(
                              key: _viewport,
                              controller: _scroll,
                              // Выбранный день — в начале; при выбранном
                              // сегодня «Просрочено» — над ним, тоже видно.
                              center: at == 0 && overdueSliver != null
                                  ? _overdueKey
                                  : _centerKey,
                              slivers: [
                                if (at > 0) ...[
                                  ?overdueSliver,
                                  SliverList.builder(
                                    itemCount: at,
                                    itemBuilder: (_, i) => day(at - 1 - i),
                                  ),
                                ] else
                                  ?overdueSliver,
                                centerList,
                                const SliverPadding(
                                  padding: EdgeInsets.only(bottom: 48),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
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
