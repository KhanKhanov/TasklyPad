import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/data_providers.dart';
import '../../../domain/models.dart';
import '../../../l10n/app_localizations.dart';
import '../../common/ui/description_line.dart';

/// Описание под названием проекта (help «Introduction to projects») —
/// [DescriptionLine] с записью в проект. У проекта в архиве — только текст.
class ProjectDescription extends ConsumerWidget {
  const ProjectDescription({
    super.key,
    required this.project,
    required this.readOnly,
  });

  final Project project;
  final bool readOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) => DescriptionLine(
    text: project.description,
    readOnly: readOnly,
    placeholder: AppLocalizations.of(context).addProjectDescription,
    onSave: (text) =>
        ref.read(projectCommandsProvider).setDescription(project.id, text),
  );
}
