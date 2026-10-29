import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/data_providers.dart';
import '../../../app/theme/app_palette.dart';
import '../../../domain/models.dart';
import '../../../domain/workspace.dart';
import '../../../l10n/app_localizations.dart';
import '../../common/ui/layout.dart';
import '../../common/ui/ui_kit.dart';
import '../../sections/ui/section_block.dart';
import '../../sections/ui/section_editor.dart';
import '../../tasks/state/view_options.dart';
import '../../shell/ui/shell_keys.dart';
import '../../tasks/ui/task_actions.dart';
import '../../tasks/ui/task_list.dart';
import '../../tasks/ui/task_order.dart';
import '../../tasks/ui/view_options_button.dart';
import 'project_menu.dart';

/// Экран проекта (и «Входящих»): заголовок с «Отображение» и меню, задачи без
/// раздела, разделы со своими задачами и «Добавить раздел». Хоткеи `a`,
/// `Shift+A`, `S` — как в Todoist.
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

  /// Задачи экрана в порядке показа — соседи для `J`/`K` в панели задачи.
  List<String> _order(Workspace ws, String projectId) {
    final view = ws.projectView(
      projectId,
      showCompleted: ref.read(showCompletedProvider(projectId)),
    );
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
    final view = ws.projectView(
      project.id,
      showCompleted: ref.watch(showCompletedProvider(project.id)),
    );
    final canAdd = !archived;
    return Shortcuts(
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
          AddSectionIntent: HotkeyAction<AddSectionIntent>(
            blocked: () => ShellKeys.sequencePending(context),
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
                    _Header(project: project, archived: archived),
                    TaskList(
                      items: view.unsectioned,
                      ws: ws,
                      projectId: project.id,
                      addAt: _addAt(null),
                      onAddAt: (at) => _openAdd(null, at),
                      canAdd: canAdd,
                    ),
                    if (view.unsectioned.isEmpty && view.sections.isEmpty)
                      _Empty(),
                    for (final (:section, :tasks) in view.sections) ...[
                      SectionBlock(
                        key: ValueKey(section.id),
                        section: section,
                        count: ws.activeTaskCountIn(project.id, section.id),
                        readOnly: archived,
                      ),
                      if (!section.isCollapsed)
                        TaskList(
                          key: ValueKey('tasks-${section.id}'),
                          items: tasks,
                          ws: ws,
                          projectId: project.id,
                          sectionId: section.id,
                          addAt: _addAt(section.id),
                          onAddAt: (at) => _openAdd(section.id, at),
                          canAdd: canAdd && !section.isArchived,
                        ),
                    ],
                    if (canAdd)
                      _AddSection(
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
    );
  }
}

class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: Text(
      AppLocalizations.of(context).inboxEmpty,
      textAlign: TextAlign.center,
      style: TextStyle(color: AppPalette.of(context).textSecondary),
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header({required this.project, required this.archived});

  final Project project;

  /// Проект в архиве (сам или через предка) — меню архивного проекта.
  final bool archived;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              projectTitle(AppLocalizations.of(context), project),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 26,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ViewOptionsButton(viewId: project.id),
          if (!project.isInbox)
            ProjectMenuButton(project: project, archived: archived, size: 22),
        ],
      ),
    );
  }
}

/// «Добавить раздел» в конце проекта: по нажатию (или `S`) — встроенный
/// редактор.
class _AddSection extends ConsumerWidget {
  const _AddSection({
    required this.projectId,
    required this.open,
    required this.onOpen,
  });

  final String projectId;
  final bool open;
  final ValueChanged<bool> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    if (open) {
      return SectionEditor(
        submitLabel: l10n.addSection,
        onSubmit: (name) async {
          await ref.read(sectionCommandsProvider).add(projectId, name: name);
          onOpen(false);
        },
        onCancel: () => onOpen(false),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => onOpen(true),
          icon: Icon(Icons.add, color: palette.accent, size: 18),
          label: Text(
            l10n.addSection,
            style: TextStyle(color: palette.textSecondary),
          ),
        ),
      ),
    );
  }
}
