import '../../../core/clock.dart';
import '../../../domain/models.dart';
import '../../../domain/view_options.dart';
import '../../../domain/view_order.dart';
import '../../../domain/workspace.dart';
import '../../tasks/logic/due_dates.dart';

/// Группы [grouping] задач [tasks] вида ([Workspace.groupsOf]): «сегодня» —
/// [today] устройства, день добавления — по часам приложения [clock];
/// [overdueOrder] — порядок «Просрочено».
List<TaskGroup> groupsFor(
  Workspace ws,
  Iterable<Task> tasks,
  Grouping grouping, {
  required TaskOrder order,
  required DateTime today,
  required AppClock clock,
  TaskOrder? overdueOrder,
}) => ws.groupsOf(
  tasks,
  grouping,
  order: order,
  today: isoDate(today),
  overdueOrder: overdueOrder,
  localDay: localDayBy(clock),
);

/// День `YYYY-MM-DD` времени UTC ISO-8601 по часам приложения [clock]: дата
/// добавления в группах, день выполнения в «Сегодня».
String Function(String utc) localDayBy(AppClock clock) => (utc) {
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
};

/// Id задач групп по порядку, без повторов (задача с двумя метками — в
/// двух группах), — соседи для `J` / `K` в панели задачи.
List<String> groupedOrder(List<TaskGroup> groups) => {
  for (final g in groups)
    for (final t in g.tasks) t.id,
}.toList();
