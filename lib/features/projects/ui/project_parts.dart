import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/data_providers.dart';
import '../../../app/theme/app_palette.dart';
import '../../../domain/models.dart';
import '../../../domain/view_options.dart';
import '../../../l10n/app_localizations.dart';
import '../../common/ui/ui_kit.dart';
import '../../sections/ui/section_editor.dart';
import '../../views/ui/view_options_button.dart';
import 'project_menu.dart';

/// «Пусто» под заголовком проекта без задач и разделов.
class ProjectEmpty extends StatelessWidget {
  const ProjectEmpty({super.key});

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

/// Заголовок проекта: название, «Отображение» и меню проекта.
class ProjectHeader extends StatelessWidget {
  const ProjectHeader({
    super.key,
    required this.project,
    required this.archived,
  });

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
          ViewOptionsButton(viewType: ViewType.project, objectId: project.id),
          if (!project.isInbox)
            ProjectMenuButton(project: project, archived: archived, size: 22),
        ],
      ),
    );
  }
}

/// «Добавить раздел» в конце проекта: по нажатию (или `S`) — встроенный
/// редактор.
class AddSectionButton extends ConsumerWidget {
  const AddSectionButton({
    super.key,
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
