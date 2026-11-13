import 'package:flutter/material.dart';

import '../../../domain/models.dart';
import '../../../domain/tree.dart';
import '../../common/ui/drag_layer.dart';
import '../../common/ui/drag_source.dart';
import 'task_drag.dart';
import 'task_drop_calc.dart';

/// Конец списка («Добавить задачу» или открытый редактор): место «последней»
/// и, в «Сегодня», зона «на завтра»; верхний редактор — место «первой». [child] уже со своим полем слева.
class TaskEndSlot extends StatelessWidget {
  const TaskEndSlot({
    super.key,
    required this.drop,
    required this.items,
    required this.child,
    this.atStart = false,
  });

  final TaskListDrop? drop;
  final List<TreeItem<Task>> items;
  final Widget child;

  /// Редактор сверху (`Shift+A`): бросок на него — место перед первой строкой,
  /// а не конец списка.
  final bool atStart;

  /// Дерево постоянно, как у [TaskDragRow]: слот без [drop] просто отвечает
  /// «не моё». Иначе смена сортировки пересоздала бы открытый редактор.
  @override
  Widget build(BuildContext context) {
    final drop = this.drop;
    return DropMarker(
      owner: drop?.endOwner ?? 'end:none',
      child: DropSlotRegion(
        resolve: (query, box) => drop == null || drop is OverdueDrop
            ? null
            : taskDropPlace(drop, query, box, items: items, atStart: atStart),
        child: child,
      ),
    );
  }
}
