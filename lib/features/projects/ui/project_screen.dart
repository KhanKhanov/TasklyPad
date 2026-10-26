import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/data_providers.dart';
import '../../../app/theme/app_palette.dart';
import '../../../domain/models.dart';
import '../../../domain/workspace.dart';
import '../../../l10n/app_localizations.dart';
import '../../common/ui/ui_kit.dart';
import '../../sections/ui/section_block.dart';
import '../../sections/ui/section_editor.dart';
import 'project_menu.dart';

/// Ширина колонки контента, как у Todoist на широком экране.
const double contentMaxWidth = 800;

/// Экран проекта (и «Входящих»): заголовок с меню, разделы и «Добавить
/// раздел». Список задач добавляет коммит 2 M2.2.
class ProjectScreen extends StatelessWidget {
  /// [projectId] `null` — «Входящие».
  const ProjectScreen({super.key, this.projectId});

  final String? projectId;

  @override
  Widget build(BuildContext context) => WorkspaceView(builder: _build);

  Widget _build(BuildContext context, Workspace ws) {
    final project = projectId == null ? ws.inbox : ws.project(projectId!);
    if (project == null) {
      return Center(child: Text(AppLocalizations.of(context).rejectNotFound));
    }
    final archived = ws.isProjectArchived(project.id);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: contentMaxWidth),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(32, 8, 32, 48),
          children: [
            _Header(project: project, archived: archived),
            ..._sections(context, ws, project),
            if (!archived) _AddSection(projectId: project.id),
          ],
        ),
      ),
    );
  }

  List<Widget> _sections(BuildContext context, Workspace ws, Project project) {
    final sections = ws.sectionsOf(project.id);
    if (sections.isEmpty && ws.activeTaskCountIn(project.id, null) == 0) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Text(
            AppLocalizations.of(context).inboxEmpty,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppPalette.of(context).textSecondary),
          ),
        ),
      ];
    }
    return [
      for (final s in sections)
        SectionBlock(
          key: ValueKey(s.id),
          section: s,
          count: ws.activeTaskCountIn(project.id, s.id),
        ),
    ];
  }
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
          if (!project.isInbox)
            ProjectMenuButton(project: project, archived: archived, size: 22),
        ],
      ),
    );
  }
}

/// «Добавить раздел» в конце проекта: по нажатию — встроенный редактор.
class _AddSection extends ConsumerStatefulWidget {
  const _AddSection({required this.projectId});

  final String projectId;

  @override
  ConsumerState<_AddSection> createState() => _AddSectionState();
}

class _AddSectionState extends ConsumerState<_AddSection> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    if (_open) {
      return SectionEditor(
        submitLabel: l10n.addSection,
        onSubmit: (name) async {
          await ref
              .read(sectionCommandsProvider)
              .add(widget.projectId, name: name);
          if (mounted) setState(() => _open = false);
        },
        onCancel: () => setState(() => _open = false),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => setState(() => _open = true),
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
