import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/data_providers.dart';
import '../../../app/theme/app_palette.dart';
import '../../../domain/models.dart';
import '../../../domain/tree.dart';
import '../../../domain/workspace.dart';
import '../../../l10n/app_localizations.dart';
import '../../common/ui/ui_kit.dart';
import 'task_actions.dart';
import 'task_dialog.dart';
import 'task_row_parts.dart';

/// Строка задачи, как в Todoist: кружок с обводкой цвета приоритета,
/// название, описание одной строкой и под ним — счётчик подзадач, срок,
/// дедлайн, метки. Клик — панель задачи; клавиши — когда строка в фокусе
/// (docs/TODOIST_PARITY.md §10).
class TaskRow extends ConsumerStatefulWidget {
  const TaskRow({
    super.key,
    required this.item,
    required this.ws,
    this.collapsible = true,
  });

  final TreeItem<Task> item;
  final Workspace ws;

  /// `false` — подзадачи в панели задачи: там они показаны все, и
  /// сворачивание ничего бы не изменило на экране, но записалось бы в данные.
  final bool collapsible;

  @override
  ConsumerState<TaskRow> createState() => _TaskRowState();
}

class _TaskRowState extends ConsumerState<TaskRow> {
  final FocusNode _focus = FocusNode();
  bool _hover = false;
  bool _focused = false;
  bool _completing = false;

  Task get _task => widget.item.value;

  /// Проект в архиве — задачи только для просмотра (допущение О-24).
  bool get _readOnly =>
      widget.ws.isProjectArchived(widget.ws.rootProjectOf(_task.id));

  bool get _canCollapse => widget.collapsible && widget.item.childCount > 0;

  void _toggleCollapse() => runCommand(
    context,
    () => ref
        .read(taskCommandsProvider)
        .setCollapsed(_task.id, !_task.isCollapsed),
  );

  /// `e`: повторное нажатие, пока первое пишется, не действует.
  Future<void> _complete() async {
    if (_completing) return;
    _completing = true;
    try {
      await toggleComplete(context, ref, _task);
    } finally {
      _completing = false;
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final keys = HardwareKeyboard.instance;
    final key = event.logicalKey;
    if (keys.isAltPressed || keys.isMetaPressed) return KeyEventResult.ignored;
    switch (key) {
      case LogicalKeyboardKey.enter
          when !keys.isControlPressed && !keys.isShiftPressed:
        showTaskDialog(context, _task.id);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.keyJ || LogicalKeyboardKey.arrowDown
          when !keys.isControlPressed && !keys.isShiftPressed:
        node.nextFocus();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.keyK || LogicalKeyboardKey.arrowUp
          when !keys.isControlPressed && !keys.isShiftPressed:
        node.previousFocus();
        return KeyEventResult.handled;
    }
    // Свернуть подзадачи можно и в архиве: это вид, а не правка задачи.
    if (keys.isShiftPressed && key == LogicalKeyboardKey.keyE && _canCollapse) {
      _toggleCollapse();
      return KeyEventResult.handled;
    }
    if (_readOnly) return KeyEventResult.ignored;
    final commands = ref.read(taskCommandsProvider);
    final t = _task;
    void run(Future<void> Function() action) =>
        runCommand(context, () async => action());
    if (keys.isControlPressed) {
      switch (key) {
        case LogicalKeyboardKey.bracketRight:
          run(() => commands.indent(t.id));
        case LogicalKeyboardKey.bracketLeft:
          run(() => commands.outdent(t.id));
        case LogicalKeyboardKey.arrowUp:
          run(() => commands.moveUp(t.id));
        case LogicalKeyboardKey.arrowDown:
          run(() => commands.moveDown(t.id));
        default:
          return KeyEventResult.ignored;
      }
      return KeyEventResult.handled;
    }
    if (keys.isShiftPressed) {
      switch (key) {
        case LogicalKeyboardKey.delete:
          deleteTask(context, ref, t);
        default:
          return KeyEventResult.ignored;
      }
      return KeyEventResult.handled;
    }
    switch (key) {
      case LogicalKeyboardKey.keyE:
        _complete();
      case LogicalKeyboardKey.digit1 ||
          LogicalKeyboardKey.digit2 ||
          LogicalKeyboardKey.digit3 ||
          LogicalKeyboardKey.digit4:
        final p = int.parse(key.keyLabel);
        run(() => commands.setPriority(t.id, p));
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = _task;
    final item = widget.item;
    final readOnly = _readOnly;
    return Focus(
      focusNode: _focus,
      // `j`/`k` и стрелки идут от строки к строке, минуя кнопки внутри неё.
      descendantsAreTraversable: false,
      onKeyEvent: _onKey,
      onFocusChange: (v) => setState(() => _focused = v),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: Material(
          color: _focused ? palette.selected : Colors.transparent,
          child: InkWell(
            canRequestFocus: false,
            onTap: () {
              _focus.requestFocus();
              showTaskDialog(context, t.id);
            },
            child: Container(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: palette.divider)),
              ),
              padding: EdgeInsets.only(left: item.depth * 28.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 24,
                    height: 40,
                    child: !_canCollapse
                        ? null
                        : IconButton(
                            padding: EdgeInsets.zero,
                            iconSize: 18,
                            color: palette.textSecondary,
                            icon: Icon(
                              t.isCollapsed
                                  ? Icons.chevron_right
                                  : Icons.expand_more,
                            ),
                            onPressed: _toggleCollapse,
                          ),
                  ),
                  TaskCheckCircle(task: t, enabled: !readOnly),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TaskText(
                      task: t,
                      ws: widget.ws,
                      onToggleCollapse: _canCollapse ? _toggleCollapse : null,
                    ),
                  ),
                  Visibility(
                    visible: !readOnly && (_hover || _focused),
                    maintainState: true,
                    maintainAnimation: true,
                    maintainSize: true,
                    child: _TaskMenu(task: t),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _TaskAction { edit, duplicate, delete }

class _TaskMenu extends ConsumerWidget {
  const _TaskMenu({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<_TaskAction>(
      tooltip: l10n.moreActions,
      iconSize: 20,
      icon: const Icon(Icons.more_horiz),
      onSelected: (action) => switch (action) {
        _TaskAction.edit => showTaskDialog(context, task.id),
        _TaskAction.duplicate => runCommand(
          context,
          () => ref.read(taskCommandsProvider).duplicate(task.id),
        ),
        _TaskAction.delete => deleteTask(context, ref, task),
      },
      itemBuilder: (context) => [
        PopupMenuItem(value: _TaskAction.edit, child: Text(l10n.actionEdit)),
        PopupMenuItem(
          value: _TaskAction.duplicate,
          child: Text(l10n.actionDuplicate),
        ),
        PopupMenuItem(
          value: _TaskAction.delete,
          child: Text(l10n.actionDelete),
        ),
      ],
    );
  }
}
