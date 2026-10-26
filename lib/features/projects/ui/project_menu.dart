import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/data_providers.dart';
import '../../../domain/models.dart';
import '../../../l10n/app_localizations.dart';
import '../../common/ui/ui_kit.dart';
import 'project_dialog.dart';

enum _ProjectAction { edit, favorite, duplicate, archive, unarchive, delete }

/// Меню «⋯» проекта, как в Todoist: Редактировать, Избранное, Дублировать,
/// Архивировать, Удалить; у архивного — Вернуть из архива и Удалить.
/// У «Входящих» меню нет: их нельзя менять (О-4).
class ProjectMenuButton extends ConsumerWidget {
  const ProjectMenuButton({
    super.key,
    required this.project,
    this.archived = false,
    this.size = 20,
  });

  final Project project;
  final bool archived;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<_ProjectAction>(
      tooltip: l10n.moreActions,
      iconSize: size,
      padding: EdgeInsets.zero,
      icon: const Icon(Icons.more_horiz),
      onSelected: (action) => _run(context, ref, action),
      itemBuilder: (context) => [
        if (archived) ...[
          PopupMenuItem(
            value: _ProjectAction.unarchive,
            child: Text(l10n.actionUnarchive),
          ),
        ] else ...[
          PopupMenuItem(
            value: _ProjectAction.edit,
            child: Text(l10n.actionEdit),
          ),
          PopupMenuItem(
            value: _ProjectAction.favorite,
            child: Text(
              project.isFavorite
                  ? l10n.removeFromFavorites
                  : l10n.addToFavorites,
            ),
          ),
          PopupMenuItem(
            value: _ProjectAction.duplicate,
            child: Text(l10n.actionDuplicate),
          ),
          PopupMenuItem(
            value: _ProjectAction.archive,
            child: Text(l10n.actionArchive),
          ),
        ],
        PopupMenuItem(
          value: _ProjectAction.delete,
          child: Text(l10n.actionDelete),
        ),
      ],
    );
  }

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    _ProjectAction action,
  ) async {
    final l10n = AppLocalizations.of(context);
    final commands = ref.read(projectCommandsProvider);
    final id = project.id;
    final router = GoRouter.of(context);
    // Поддерево запоминается до действия: после удаления или архива
    // подпроекты уже не найти в снимке. Открыт любой из них — уходим на
    // «Входящие», а не остаёмся на «Не найдено» или на архивном проекте.
    final subtree =
        ref.read(workspaceProvider).value?.projectSubtree(id).toSet() ?? {id};
    void leaveIfOpen() {
      final path = router.state.uri.path;
      if (subtree.any((p) => path == '/project/$p')) router.go('/');
    }

    switch (action) {
      case _ProjectAction.edit:
        await showProjectDialog(context, project: project);
      case _ProjectAction.favorite:
        await runCommand(
          context,
          () => commands.setFavorite(id, !project.isFavorite),
        );
      case _ProjectAction.duplicate:
        await runCommand(
          context,
          () => commands.duplicate(id, name: l10n.copyOf(project.name)),
        );
      case _ProjectAction.archive:
        final ok = await confirmAction(
          context,
          title: l10n.archiveProjectTitle,
          body: l10n.archiveProjectBody(project.name),
          action: l10n.actionArchive,
        );
        if (!ok || !context.mounted) return;
        await runCommand(context, () => commands.archive(id));
        leaveIfOpen();
      case _ProjectAction.unarchive:
        await runCommand(context, () => commands.unarchive(id));
      case _ProjectAction.delete:
        final ok = await confirmAction(
          context,
          title: l10n.deleteProjectTitle,
          body: l10n.deleteProjectBody(project.name),
          action: l10n.actionDelete,
          danger: true,
        );
        if (!ok || !context.mounted) return;
        await runCommand(context, () => commands.delete(id));
        leaveIfOpen();
    }
  }
}
