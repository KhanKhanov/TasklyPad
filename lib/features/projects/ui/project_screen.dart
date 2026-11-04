import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/data_providers.dart';
import '../../../domain/view_options.dart';
import '../../../domain/view_order.dart';
import '../../../domain/workspace.dart';
import '../../../l10n/app_localizations.dart';
import '../../common/ui/layout.dart';
import '../../common/ui/ui_kit.dart';
import '../../sections/ui/section_block.dart';
import '../../shell/ui/shell_keys.dart';
import '../../tasks/state/today.dart';
import '../../tasks/ui/task_actions.dart';
import '../../tasks/ui/task_list.dart';
import '../../tasks/ui/task_order.dart';
import '../../views/state/view_options.dart';
import '../../views/ui/grouped_task_list.dart';
import '../../views/ui/view_sort_keys.dart';
import 'project_parts.dart';

/// Экран проекта (и «Входящих»): заголовок с «Отображение» и меню, задачи без
/// раздела, разделы со своими задачами и «Добавить раздел». Сортировка
/// «Отображения» — внутри раздела и среди соседей одного родителя; при
/// группировке группы заменяют разделы (допущение, О-69). Хоткеи `a`,
/// `Shift+A`, `S`, `D` / `P` / `N` — как в Todoist.
class ProjectScreen extends ConsumerStatefulWidget {
  /// [projectId] `null` — «Входящие».
  const ProjectScreen({super.key, this.projectId});

  final String? projectId;

  @override
  ConsumerState<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends ConsumerState<ProjectScreen> {
  /// Открытый редактор задачи: раздел (`null` — без раздела) и место.
  /// Одновременно открыт один редактор, как в Todoist.
  ({String? sectionId, AddTaskAt at})? _adding;
  bool _addingSection = false;

  void _openAdd(String? sectionId, AddTaskAt at) => setState(() {
    _adding = at == AddTaskAt.none ? null : (sectionId: sectionId, at: at);
    if (_adding != null) _addingSection = false;
  });

  AddTaskAt _addAt(String? forSection) => switch (_adding) {
    (:final sectionId, :final at) when sectionId == forSection => at,
    _ => AddTaskAt.none,
  };

  TaskOrder _taskOrder(Workspace ws, ViewOptions options) => ws.taskOrder(
    DefaultOrder.manual,
    sorting: options.sorting,
    sortOrder: options.sortOrder,
  );

  ProjectView _view(Workspace ws, ViewOptions options) => ws.projectView(
    options.objectId!,
    showCompleted: options.showCompletedTasks,
    order: _taskOrder(ws, options),
  );

  /// Группы проекта: подзадача — в группе своих значений.
  List<TaskGroup> _groups(Workspace ws, ViewOptions options) => groupsFor(
    ws,
    ws.projectTasks(
      options.objectId!,
      showCompleted: options.showCompletedTasks,
    ),
    options.grouping,
    order: _taskOrder(ws, options),
    today: ref.read(todayProvider),
    clock: ref.read(clockProvider),
  );

  /// Задачи экрана в порядке показа — соседи для `J`/`K` в панели задачи.
  List<String> _order(Workspace ws, String projectId) {
    final options = ref.read(viewOptionsProvider(ViewType.project, projectId));
    if (options.grouping != Grouping.none) {
      return groupedOrder(_groups(ws, options));
    }
    final view = _view(ws, options);
    return [
      for (final item in view.unsectioned) item.value.id,
      for (final (:section, :tasks) in view.sections)
        if (!section.isCollapsed)
          for (final item in tasks) item.value.id,
    ];
  }

  @override
  Widget build(BuildContext context) => WorkspaceView(builder: _build);

  Widget _build(BuildContext context, Workspace ws) {
    final project = widget.projectId == null
        ? ws.inbox
        : ws.project(widget.projectId!);
    if (project == null) {
      return Center(child: Text(AppLocalizations.of(context).rejectNotFound));
    }
    final archived = ws.isProjectArchived(project.id);
    final options = ref.watch(
      viewOptionsProvider(ViewType.project, project.id),
    );
    // Подписка: группы по дням меняются в полночь.
    ref.watch(todayProvider);
    final grouped = options.grouping != Grouping.none;
    final canAdd = !archived;
    return ViewSortKeys(
      viewType: ViewType.project,
      objectId: project.id,
      child: Shortcuts(
        shortcuts: canAdd ? projectShortcuts : const {},
        child: Actions(
          actions: {
            AddTaskBottomIntent: HotkeyAction<AddTaskBottomIntent>(
              blocked: () => ShellKeys.sequencePending(context),
              () => _openAdd(null, AddTaskAt.bottom),
            ),
            AddTaskTopIntent: HotkeyAction<AddTaskTopIntent>(
              blocked: () => ShellKeys.sequencePending(context),
              () => _openAdd(null, AddTaskAt.top),
            ),
            // При группировке разделов не видно — `S` ничего не делает.
            AddSectionIntent: HotkeyAction<AddSectionIntent>(
              blocked: () => grouped || ShellKeys.sequencePending(context),
              () => setState(() {
                _addingSection = true;
                _adding = null;
              }),
            ),
          },
          child: Focus(
            autofocus: true,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: contentMaxWidth),
                child: TaskOrderScope(
                  order: (ws) => _order(ws, project.id),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(32, 8, 32, 48),
                    children: [
                      ProjectHeader(project: project, archived: archived),
                      if (grouped)
                        ..._grouped(ws, options, canAdd: canAdd)
                      else
                        ..._sectioned(ws, options, canAdd: canAdd),
                      if (canAdd && !grouped)
                        AddSectionButton(
                          projectId: project.id,
                          open: _addingSection,
                          // Вызывается и после записи раздела — экран к тому
                          // времени мог уйти (переход по сайдбару).
                          onOpen: (v) {
                            if (!mounted) return;
                            setState(() {
                              _addingSection = v;
                              if (v) _adding = null;
                            });
                          },
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

  List<Widget> _grouped(
    Workspace ws,
    ViewOptions options, {
    required bool canAdd,
  }) {
    final groups = _groups(ws, options);
    return [
      GroupedTaskList(
        groups: groups,
        grouping: options.grouping,
        ws: ws,
        place: (
          projectId: options.objectId!,
          labelIds: const {},
          due: null,
          priority: null,
          deadline: null,
        ),
        addAt: _addAt(null),
        onAddAt: (at) => _openAdd(null, at),
        canAdd: canAdd,
      ),
      if (groups.isEmpty && _addAt(null) == AddTaskAt.none)
        const ProjectEmpty(),
    ];
  }

  List<Widget> _sectioned(
    Workspace ws,
    ViewOptions options, {
    required bool canAdd,
  }) {
    final projectId = options.objectId!;
    final view = _view(ws, options);
    return [
      TaskList(
        items: view.unsectioned,
        ws: ws,
        projectId: projectId,
        addAt: _addAt(null),
        onAddAt: (at) => _openAdd(null, at),
        canAdd: canAdd,
      ),
      if (view.unsectioned.isEmpty && view.sections.isEmpty)
        const ProjectEmpty(),
      for (final (:section, :tasks) in view.sections) ...[
        SectionBlock(
          key: ValueKey(section.id),
          section: section,
          count: ws.activeTaskCountIn(projectId, section.id),
          readOnly: !canAdd,
        ),
        if (!section.isCollapsed)
          TaskList(
            key: ValueKey('tasks-${section.id}'),
            items: tasks,
            ws: ws,
            projectId: projectId,
            sectionId: section.id,
            addAt: _addAt(section.id),
            onAddAt: (at) => _openAdd(section.id, at),
            canAdd: canAdd && !section.isArchived,
          ),
      ],
    ];
  }
}
