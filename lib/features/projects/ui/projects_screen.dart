import 'package:flutter/material.dart';

import '../../../app/theme/app_palette.dart';
import '../../../domain/workspace.dart';
import '../../../l10n/app_localizations.dart';
import '../../common/ui/ui_kit.dart';
import 'project_dialog.dart';
import 'project_screen.dart';
import 'project_tile.dart';

/// Экран «Мои проекты», как в Todoist: активные проекты деревом и архив
/// (оттуда — «Вернуть из архива» и «Удалить»).
class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  bool _archived = false;

  @override
  Widget build(BuildContext context) => WorkspaceView(builder: _build);

  Widget _build(BuildContext context, Workspace ws) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final archived = ws.archivedProjects;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: contentMaxWidth),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(32, 8, 32, 48),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.myProjects,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l10n.addProject,
                  icon: const Icon(Icons.add),
                  onPressed: () => showProjectDialog(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: false, label: Text(l10n.projectsActive)),
                ButtonSegment(value: true, label: Text(l10n.projectsArchived)),
              ],
              selected: {_archived},
              onSelectionChanged: (v) => setState(() => _archived = v.single),
            ),
            const SizedBox(height: 12),
            if (_archived) ...[
              if (archived.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    l10n.noArchivedProjects,
                    style: TextStyle(color: palette.textSecondary),
                  ),
                ),
              for (final p in archived)
                ProjectTile(
                  key: ValueKey('arch-${p.id}'),
                  project: p,
                  count: 0,
                  archived: true,
                ),
            ] else
              for (final item in ws.projectTree())
                ProjectTile(
                  key: ValueKey(item.value.id),
                  project: item.value,
                  count: ws.activeTaskCount(item.value.id),
                  depth: item.depth,
                  childCount: item.childCount,
                ),
          ],
        ),
      ),
    );
  }
}
