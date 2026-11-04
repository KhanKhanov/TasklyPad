import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/data_providers.dart';
import '../../../app/theme/app_palette.dart';
import '../../../domain/models.dart';
import '../../../domain/tree.dart';
import '../../../domain/workspace.dart';
import '../../common/ui/layout.dart';
import '../../common/ui/ui_kit.dart';
import '../../shell/ui/shell_keys.dart';
import 'task_actions.dart';
import '../state/selection.dart';
import 'task_order.dart';
import 'task_row_keys.dart';
import 'task_panel.dart';
import 'task_row_menu.dart';
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
    this.showProject = false,
    this.hierarchy = true,
    this.selectable = true,
  });

  final TreeItem<Task> item;
  final Workspace ws;

  /// `false` — подзадачи в панели задачи: там они показаны все, и
  /// сворачивание ничего бы не изменило на экране, но записалось бы в данные.
  final bool collapsible;

  /// Показать проект и раздел задачи (экран метки).
  final bool showProject;

  /// `false` — `Ctrl+]` / `Ctrl+[` не действуют: плоский список (экран метки).
  final bool hierarchy;

  /// `false` — `x` и клики с `Ctrl`/`Shift` не выделяют (подзадачи в окне
  /// задачи).
  final bool selectable;

  @override
  ConsumerState<TaskRow> createState() => _TaskRowState();
}

class _TaskRowState extends ConsumerState<TaskRow> {
  final FocusNode _focus = ListRowFocusNode();

  /// Кнопка «⋯»: под ней встаёт меню, открытое клавишей `.`.
  final GlobalKey _menuButton = GlobalKey();
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
  void initState() {
    super.initState();
    RendererBinding.instance.mouseTracker.addListener(_onMouseChanged);
  }

  /// Мышь подключили или отключили — меняется, виден ли «⋯» без наведения.
  void _onMouseChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    RendererBinding.instance.mouseTracker.removeListener(_onMouseChanged);
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final keys = HardwareKeyboard.instance;
    final key = event.logicalKey;
    if (keys.isAltPressed || keys.isMetaPressed) return KeyEventResult.ignored;
    if (ShellKeys.sequencePending(context)) {
      return KeyEventResult.ignored;
    }
    switch (key) {
      case LogicalKeyboardKey.enter
          when !keys.isControlPressed && !keys.isShiftPressed:
        _open();
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
    return taskRowEditKey(
      context: context,
      ref: ref,
      task: _task,
      key: key,
      hierarchy: widget.hierarchy,
      complete: _complete,
      openMenu: () {
        if (_menuButton.currentContext case final button?) {
          showTaskRowMenu(button, ref, _task);
        }
      },
      toggleSelected: _toggleSelected,
    );
  }

  /// Задачу можно выделить: строка списка вида, проект не в архиве.
  bool get _canSelect => widget.selectable && !_readOnly;

  /// `x`, клик с `Ctrl` или `Shift`: выделить задачу или снять выделение.
  void _toggleSelected() {
    if (!_canSelect) return;
    ref
        .read(taskSelectionProvider.notifier)
        .toggle(_task.id, order: TaskOrderScope.maybeOf(context));
  }

  /// Открыть панель задачи (клик, `Enter`): выделение списка снимается, как
  /// обычным кликом (решение 2А «Ход M4.8»).
  void _open() {
    if (widget.selectable) ref.read(taskSelectionProvider.notifier).clear();
    _focus.requestFocus();
    showTaskDialog(context, _task.id);
  }

  /// Клик по строке (help «Use keyboard shortcuts», «Add or manage multiple
  /// tasks»): `Ctrl+Shift` — диапазон от прошлой выделенной, `Ctrl` или
  /// `Shift` — выделить; в режиме выделения на телефоне касание выделяет;
  /// обычный клик снимает выделение и открывает панель (решение 2А «Ход
  /// M4.8»). Задачу архивного проекта не выделить: менять её нельзя.
  void _onTap() {
    final keys = HardwareKeyboard.instance;
    final ctrl = keys.isControlPressed;
    final shift = keys.isShiftPressed;
    if (_canSelect && ctrl && shift) {
      ref
          .read(taskSelectionProvider.notifier)
          .selectRange(
            _task.id,
            widget.ws,
            order: TaskOrderScope.maybeOf(context),
          );
    } else if (_canSelect &&
        (ctrl || shift || ref.read(taskSelectionProvider).touchMode)) {
      _toggleSelected();
    } else {
      _open();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = _task;
    final item = widget.item;
    final readOnly = _readOnly;
    // Без мыши наведения нет: на узком экране (решение 1А «Ход M4.7») и
    // без мыши — на широком сенсорном (О-48) «⋯» виден всегда; долгое
    // нажатие оставлено перетаскиванию (M4.9).
    final alwaysMenu = touchLayout(context);
    final selected = ref.watch(
      taskSelectionProvider.select((s) => s.contains(t.id)),
    );
    // В режиме выделения касаниями кружок и «⋯» строки не действуют: касание
    // по ним выполнило бы задачу вместо выделения.
    final touchSelecting =
        widget.selectable &&
        ref.watch(taskSelectionProvider.select((s) => s.touchMode));
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
          color: selected
              ? palette.accent.withValues(alpha: 0.16)
              : _focused
              ? palette.selected
              : Colors.transparent,
          child: InkWell(
            canRequestFocus: false,
            onTap: _onTap,
            // Правый клик — то же меню у курсора (решение 2А «Ход M4.7»).
            onSecondaryTapUp: readOnly
                ? null
                : (details) {
                    _focus.requestFocus();
                    showTaskRowMenu(
                      context,
                      ref,
                      t,
                      at: details.globalPosition,
                    );
                  },
            child: Container(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: palette.divider)),
              ),
              padding: EdgeInsets.only(left: item.depth * 28.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CollapseToggle(
                    collapsed: t.isCollapsed,
                    onToggle: _canCollapse ? _toggleCollapse : null,
                  ),
                  TaskCheckCircle(
                    task: t,
                    enabled: !readOnly && !touchSelecting,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TaskText(
                      task: t,
                      ws: widget.ws,
                      onToggleCollapse: _canCollapse ? _toggleCollapse : null,
                      showProject: widget.showProject,
                    ),
                  ),
                  Visibility(
                    visible:
                        !readOnly &&
                        !touchSelecting &&
                        (_hover || _focused || alwaysMenu),
                    maintainState: true,
                    maintainAnimation: true,
                    maintainSize: true,
                    child: TaskRowMenuButton(key: _menuButton, task: t),
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
