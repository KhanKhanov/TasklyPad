import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/data_providers.dart';
import '../../../app/theme/app_palette.dart';
import '../../../domain/models.dart';
import '../../../domain/view_options.dart';
import '../../../l10n/app_localizations.dart';
import '../../common/ui/layout.dart';
import '../../common/ui/ui_kit.dart';
import '../../sections/ui/section_editor.dart';
import '../../tasks/ui/select_tasks_button.dart';
import '../../views/ui/view_options_button.dart';
import 'project_description.dart';
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

/// Заголовок проекта: название, «Отображение», меню проекта и описание.
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
    final title = Row(
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
          ProjectMenuButton(
            project: project,
            archived: archived,
            size: 22,
            selectTasks: true,
          )
        else if (touchLayout(context))
          const SelectTasksMenuButton(),
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: project.isInbox
          ? title
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                title,
                ProjectDescription(project: project, readOnly: archived),
              ],
            ),
    );
  }
}

/// «Новый раздел» в конце проекта: по нажатию (или `S`) — встроенный
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
      child: _NewSectionLine(
        label: l10n.newSection,
        color: palette.accent,
        onTap: () => onOpen(true),
      ),
    );
  }
}

/// Строка «+ Новый раздел ———»: видна всегда, цветом акцента, при наведении
/// фон, текст и линия становятся заметно сильнее (решение 9Б M4.10a).
class _NewSectionLine extends StatefulWidget {
  const _NewSectionLine({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_NewSectionLine> createState() => _NewSectionLineState();
}

class _NewSectionLineState extends State<_NewSectionLine> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: Material(
        color: _hover ? color.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                Icon(Icons.add, color: color, size: 18),
                const SizedBox(width: 6),
                Text(
                  widget.label,
                  style: TextStyle(
                    color: color,
                    fontWeight: _hover ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: _hover ? 2 : 1,
                    color: color.withValues(alpha: _hover ? 1 : 0.45),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
