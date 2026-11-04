import 'package:flutter/material.dart';

import '../../../domain/models.dart';
import '../../../domain/tree.dart';
import '../../../domain/workspace.dart';
import '../../tasks/ui/add_task_editor.dart';
import '../../tasks/ui/task_row.dart';
import 'view_parts.dart';

/// День в списке: заголовок, задачи с проектом, «Добавить задачу» с его
/// датой.
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
  });

  final String date;
  final String title;
  final List<Task> tasks;
  final Workspace ws;
  final String inboxId;
  final bool adding;
  final ValueChanged<bool> onAdding;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      DayHeader(title: title),
      for (final task in tasks)
        TaskRow(
          key: ValueKey('$date/${task.id}'),
          item: TreeItem(task, 0, 0),
          ws: ws,
          collapsible: false,
          showProject: true,
          hierarchy: false,
        ),
      if (adding)
        AddTaskEditor(
          projectId: inboxId,
          due: Due(date: date),
          onClose: () => onAdding(false),
        )
      else
        AddTaskButton(onPressed: () => onAdding(true)),
    ],
  );
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
