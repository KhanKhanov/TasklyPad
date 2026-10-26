import 'package:flutter/material.dart';

import '../../../app/theme/app_palette.dart';
import '../../../domain/tree.dart';
import '../../../domain/workspace.dart';
import '../../../l10n/app_localizations.dart';
import '../../common/ui/ui_kit.dart';
import '../../projects/ui/project_screen.dart';
import '../../tasks/ui/task_actions.dart';
import '../../tasks/ui/task_list.dart';
import '../../tasks/ui/task_order.dart';
import 'label_menu.dart';

/// Экран метки: активные задачи с ней из всех проектов (у каждой — проект и
/// раздел), «Добавить задачу» — во «Входящие» с этой меткой; `a` / `Shift+A`.
/// Сортировка, группировка и показ выполненных для этого вида — M4.
class LabelScreen extends StatefulWidget {
  const LabelScreen({super.key, required this.labelId});

  final String labelId;

  @override
  State<LabelScreen> createState() => _LabelScreenState();
}

class _LabelScreenState extends State<LabelScreen> {
  AddTaskAt _addAt = AddTaskAt.none;

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
    final tasks = ws.labelTasks(label.id);
    return Shortcuts(
      shortcuts: projectShortcuts,
      child: Actions(
        actions: {
          AddTaskBottomIntent: HotkeyAction<AddTaskBottomIntent>(
            () => setState(() => _addAt = AddTaskAt.bottom),
          ),
          AddTaskTopIntent: HotkeyAction<AddTaskTopIntent>(
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
                order: (ws) => [for (final t in ws.labelTasks(label.id)) t.id],
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
                          LabelMenuButton(label: label, size: 22),
                        ],
                      ),
                    ),
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
                    if (tasks.isEmpty && _addAt == AddTaskAt.none)
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
    );
  }
}
