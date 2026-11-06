import 'package:flutter/material.dart';

import '../../../domain/models.dart';
import '../../../domain/tree.dart';
import '../../../domain/workspace.dart';
import '../../tasks/ui/add_task_editor.dart';
import '../../tasks/ui/task_drag.dart';
import '../../tasks/ui/task_drop_places.dart';
import '../../tasks/ui/task_row.dart';
import 'view_parts.dart';

/// День в списке: заголовок, задачи с проектом, «Добавить задачу» с его
/// датой. С [drop] задачи переставляются среди задач дня и приходят с других
/// дней; на заголовок дня — бросок меняет только дату.
class UpcomingDayView extends StatelessWidget {
  const UpcomingDayView({
    super.key,
    required this.date,
    required this.title,
    required this.tasks,
    required this.ws,
    required this.inboxId,
    required this.adding,
    required this.onAdding,
    this.drop,
  });

  final String date;
  final String title;
  final List<Task> tasks;
  final Workspace ws;
  final String inboxId;
  final bool adding;
  final ValueChanged<bool> onAdding;

  /// `null` — перетаскивание выключено.
  final DayDrop? drop;

  @override
  Widget build(BuildContext context) {
    final items = [for (final t in tasks) TreeItem(t, 0, 0)];
    final header = DayHeader(title: title);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DragGutter(
          child: drop == null ? header : DayDropSlot(date: date, child: header),
        ),
        for (final item in items)
          TaskDragRow(
            key: ValueKey('$date/${item.value.id}'),
            item: item,
            items: items,
            drop: drop,
            child: TaskRow(
              item: item,
              ws: ws,
              collapsible: false,
              showProject: true,
              hierarchy: false,
            ),
          ),
        TaskEndSlot(
          drop: drop,
          items: items,
          child: DragGutter(
            child: adding
                ? AddTaskEditor(
                    projectId: inboxId,
                    due: Due(date: date),
                    onClose: () => onAdding(false),
                  )
                : AddTaskButton(onPressed: () => onAdding(true)),
          ),
        ),
      ],
    );
  }
}

/// Помечает построенный день списка в [days], пока он на экране: по ним
/// «Предстоящее» находит день под верхним краем при прокрутке.
class DayMarker extends StatefulWidget {
  const DayMarker({
    super.key,
    required this.date,
    required this.days,
    required this.child,
  });

  final String date;
  final Map<String, BuildContext> days;
  final Widget child;

  @override
  State<DayMarker> createState() => _DayMarkerState();
}

class _DayMarkerState extends State<DayMarker> {
  @override
  void initState() {
    super.initState();
    widget.days[widget.date] = context;
  }

  @override
  void dispose() {
    if (identical(widget.days[widget.date], context)) {
      widget.days.remove(widget.date);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// День под верхним краем [viewport] среди построенных [days]; если выше
/// края ни одного нет — самый верхний. `null` — дней нет.
String? topVisibleDay(Map<String, BuildContext> days, RenderBox viewport) {
  String? top;
  double? topY;
  String? first;
  double? firstY;
  for (final MapEntry(key: date, value: context) in days.entries) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached) continue;
    final y = box.localToGlobal(Offset.zero, ancestor: viewport).dy;
    if (y <= 1 && (topY == null || y > topY)) (top, topY) = (date, y);
    if (firstY == null || y < firstY) (first, firstY) = (date, y);
  }
  return top ?? first;
}
