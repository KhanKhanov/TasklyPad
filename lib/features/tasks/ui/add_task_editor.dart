import 'package:flutter/material.dart';

import '../../../app/theme/app_palette.dart';
import '../../../domain/models.dart';
import '../../../l10n/app_localizations.dart';
import '../../quick_add/logic/quick_add_draft.dart';
import '../../quick_add/ui/quick_add_composer.dart';

/// Встроенный редактор «Добавить задачу» и «Добавить подзадачу», как в
/// Todoist: тот же редактор быстрого добавления, что и окно `q` (решение 6А
/// «Ход M3.6»), с местом списка по умолчанию. Enter — добавить и остаться в
/// редакторе для следующей задачи, Esc — закрыть.
class AddTaskEditor extends StatelessWidget {
  const AddTaskEditor({
    super.key,
    required this.projectId,
    this.sectionId,
    this.parentId,
    this.atTop = false,
    this.labelIds = const {},
    this.due,
    this.priority,
    this.deadline,
    required this.onClose,
  });

  final String projectId;
  final String? sectionId;
  final String? parentId;
  final bool atTop;
  final Set<String> labelIds;

  /// Значение группы — [QuickAddDefaults.due].
  final Due? due;
  final int? priority;
  final String? deadline;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      decoration: BoxDecoration(
        border: Border.all(color: palette.outline),
        borderRadius: BorderRadius.circular(10),
      ),
      child: QuickAddComposer(
        defaults: QuickAddDefaults(
          projectId: projectId,
          sectionId: sectionId,
          parentId: parentId,
          labelIds: labelIds,
          due: due,
          priority: priority,
          deadline: deadline,
        ),
        atTop: atTop,
        onClose: onClose,
      ),
    );
  }
}

/// «+ Добавить задачу» в конце списка; по нажатию — редактор.
class AddTaskButton extends StatelessWidget {
  const AddTaskButton({super.key, required this.onPressed, this.label});

  final VoidCallback onPressed;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(Icons.add, color: palette.accent, size: 18),
        label: Text(
          label ?? AppLocalizations.of(context).addTask,
          style: TextStyle(color: palette.textSecondary),
        ),
      ),
    );
  }
}
