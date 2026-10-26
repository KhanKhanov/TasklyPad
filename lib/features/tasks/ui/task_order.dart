import 'package:flutter/widgets.dart';

import '../../../domain/workspace.dart';

/// Порядок задач списка, из которого открыта панель задачи: по нему `J`/`K`
/// и стрелки в панели переходят к соседней задаче, как в Todoist («tasks in
/// your current list»). Функция, а не готовый список: панель живёт дольше
/// снимка, и соседей ищем в свежем (задачу могли выполнить или перенести).
class TaskOrderScope extends InheritedWidget {
  const TaskOrderScope({super.key, required this.order, required super.child});

  final List<String> Function(Workspace ws) order;

  /// Без подписки на перестройку: порядок читается в момент открытия панели.
  static List<String> Function(Workspace ws)? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<TaskOrderScope>()?.order;

  @override
  bool updateShouldNotify(TaskOrderScope oldWidget) => false;
}
