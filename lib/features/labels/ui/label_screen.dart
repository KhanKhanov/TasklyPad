import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/data_providers.dart';
import '../../../app/theme/app_palette.dart';
import '../../../domain/models.dart';
import '../../../domain/tree.dart';
import '../../../domain/view_options.dart';
import '../../../domain/view_order.dart';
import '../../../domain/workspace.dart';
import '../../../l10n/app_localizations.dart';
import '../../common/ui/ui_kit.dart';
import '../../common/ui/layout.dart';
import '../../shell/ui/shell_keys.dart';
import '../../tasks/ui/task_actions.dart';
import '../../tasks/ui/task_list.dart';
import '../../tasks/state/today.dart';
import '../../tasks/ui/task_order.dart';
import '../../views/state/view_options.dart';
import '../../views/ui/grouped_task_list.dart';
import '../../views/ui/view_options_button.dart';
import '../../views/ui/view_sort_keys.dart';
import 'label_menu.dart';

/// Экран метки: активные задачи с ней из всех проектов (у каждой — проект и
/// раздел), «Добавить задачу» — во «Входящие» с этой меткой; `a` / `Shift+A`,
/// `D` / `P` / `N`. «Отображение» — сортировка без «Вручную», группировка,
/// «Выполненные задачи» (О-27; решение 2А «Ход M4.5»).
class LabelScreen extends ConsumerStatefulWidget {
  const LabelScreen({super.key, required this.labelId});

  final String labelId;

  @override
  ConsumerState<LabelScreen> createState() => _LabelScreenState();
}

class _LabelScreenState extends ConsumerState<LabelScreen> {
  AddTaskAt _addAt = AddTaskAt.none;

  ViewOptions _options({bool watch = false}) {
    final provider = viewOptionsProvider(ViewType.label, widget.labelId);
    return watch ? ref.watch(provider) : ref.read(provider);
  }

  List<Task> _tasks(Workspace ws, ViewOptions options) => ws.labelTasks(
    widget.labelId,
    showCompleted: options.showCompletedTasks,
    order: _taskOrder(ws, options),
  );

  TaskOrder _taskOrder(Workspace ws, ViewOptions options) => ws.taskOrder(
    DefaultOrder.label,
    sorting: options.sorting,
    sortOrder: options.sortOrder,
  );

  List<TaskGroup> _groups(Workspace ws, ViewOptions options) => groupsFor(
    ws,
    _tasks(ws, options),
    options.grouping,
    order: _taskOrder(ws, options),
    today: ref.read(todayProvider),
    clock: ref.read(clockProvider),
  );

  List<String> _order(Workspace ws) {
    final options = _options();
    return options.grouping == Grouping.none
        ? [for (final t in _tasks(ws, options)) t.id]
        : groupedOrder(_groups(ws, options));
  }

  @override
  Widget build(BuildContext context) => WorkspaceView(builder: _build);

  Widget _build(BuildContext context, Workspace ws) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final label = ws.label(widget.labelId);
    final inbox = ws.inbox;
    if (label == null || inbox == null) {
      return Center(child: Text(l10n.rejectNotFound));
    }
    final options = _options(watch: true);
    // Подписка: группы по дням меняются в полночь.
    ref.watch(todayProvider);
    final grouped = options.grouping != Grouping.none;
    final tasks = grouped ? const <Task>[] : _tasks(ws, options);
    final groups = grouped ? _groups(ws, options) : const <TaskGroup>[];
    return ViewSortKeys(
      viewType: ViewType.label,
      objectId: label.id,
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
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(32, 8, 32, 48),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                label.name,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: palette.textPrimary,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            ViewOptionsButton(
                              viewType: ViewType.label,
                              objectId: label.id,
                            ),
                            LabelMenuButton(label: label, size: 22),
                          ],
                        ),
                      ),
                      if (grouped)
                        GroupedTaskList(
                          groups: groups,
                          grouping: options.grouping,
                          ws: ws,
                          place: (
                            projectId: inbox.id,
                            labelIds: {label.id},
                            due: null,
                            priority: null,
                            deadline: null,
                          ),
                          addAt: _addAt,
                          onAddAt: (at) => setState(() => _addAt = at),
                          showProject: true,
                        )
                      else
                        TaskList(
                          // Список плоский: подзадача с меткой — отдельной строкой.
                          items: [for (final t in tasks) TreeItem(t, 0, 0)],
                          ws: ws,
                          projectId: inbox.id,
                          labelIds: {label.id},
                          showProject: true,
                          hierarchy: false,
                          addAt: _addAt,
                          onAddAt: (at) => setState(() => _addAt = at),
                        ),
                      if (tasks.isEmpty &&
                          groups.isEmpty &&
                          _addAt == AddTaskAt.none)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Text(
                            l10n.inboxEmpty,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: palette.textSecondary),
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
