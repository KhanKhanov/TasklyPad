import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/data_providers.dart';
import '../../../domain/workspace.dart';
import 'task_actions.dart';
import 'task_dialog.dart';
import 'task_order.dart';

/// Открыть панель задачи. На desktop — окно поверх списка (допущение О-4:
/// в help не сказано, окно это или боковая панель). Соседи для `J`/`K` —
/// из [TaskOrderScope] списка, откуда открыли.
Future<void> showTaskDialog(BuildContext context, String taskId) {
  final order = TaskOrderScope.maybeOf(context);
  return showDialog<void>(
    context: context,
    builder: (_) => TaskPanel(taskId: taskId, order: order),
  );
}

/// Панель задачи с переходом к соседней задаче списка: стрелки в заголовке
/// (help «Use the task view»), `K` — предыдущая, `J` — следующая (клавиши в
/// help не описаны — допущение О-24). Окно задачи пересоздаётся для новой задачи; правка
/// прежней сохраняется, потому что её поле теряет фокус до перехода.
class TaskPanel extends ConsumerStatefulWidget {
  const TaskPanel({super.key, required this.taskId, this.order});

  final String taskId;
  final List<String> Function(Workspace ws)? order;

  @override
  ConsumerState<TaskPanel> createState() => _TaskPanelState();
}

class _TaskPanelState extends ConsumerState<TaskPanel> {
  final FocusNode _keys = FocusNode();
  late String _id = widget.taskId;

  @override
  void dispose() {
    _keys.dispose();
    super.dispose();
  }

  /// Задачи списка по порядку; пусто — порядок неизвестен.
  List<String> _ids(Workspace? ws) {
    final order = widget.order;
    return ws == null || order == null ? const [] : order(ws);
  }

  /// Соседняя задача через [delta] в порядке [ids] или `null`.
  String? _neighbour(List<String> ids, int delta) {
    final i = ids.indexOf(_id);
    final next = i + delta;
    return i < 0 || next < 0 || next >= ids.length ? null : ids[next];
  }

  void _go(String id) {
    // Фокус уходит из полей окна — их правка сохраняется для прежней задачи.
    _keys.requestFocus();
    setState(() => _id = id);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final keys = HardwareKeyboard.instance;
    if (event is! KeyDownEvent ||
        isTypingInTextField() ||
        keys.isControlPressed ||
        keys.isAltPressed ||
        keys.isMetaPressed ||
        keys.isShiftPressed) {
      return KeyEventResult.ignored;
    }
    final delta = switch (event.logicalKey) {
      LogicalKeyboardKey.keyJ => 1,
      LogicalKeyboardKey.keyK => -1,
      _ => 0,
    };
    if (delta == 0) return KeyEventResult.ignored;
    final id = _neighbour(_ids(ref.read(workspaceProvider).value), delta);
    if (id != null) _go(id);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final ids = _ids(ref.watch(workspaceProvider).value);
    final previous = _neighbour(ids, -1);
    final next = _neighbour(ids, 1);
    // Свой ScaffoldMessenger: тосты окна видны поверх затемнения и не
    // теряются при переходе к соседней задаче.
    return ScaffoldMessenger(
      child: Focus(
        focusNode: _keys,
        autofocus: true,
        onKeyEvent: _onKey,
        child: TaskDialog(
          key: ValueKey(_id),
          taskId: _id,
          onPrevious: previous == null ? null : () => _go(previous),
          onNext: next == null ? null : () => _go(next),
        ),
      ),
    );
  }
}
