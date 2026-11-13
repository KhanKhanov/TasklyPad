import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/data_providers.dart';
import '../../../domain/models.dart';
import '../../../l10n/app_localizations.dart';
import '../../common/ui/layout.dart';
import '../../common/ui/ui_kit.dart';
import '../../tasks/ui/select_tasks_button.dart';
import 'filter_dialog.dart';

enum _FilterAction { selectTasks, edit, favorite, duplicate, delete }

/// Меню «⋯» фильтра, как у метки: «Изменить фильтр», избранное,
/// «Дублировать» (в help нет — допущение, О-69), «Удалить фильтр» с
/// подтверждением, без отмены.
class FilterMenuButton extends ConsumerWidget {
  const FilterMenuButton({
    super.key,
    required this.filter,
    this.size = 20,
    this.selectTasks = false,
  });

  final SavedFilter filter;
  final double size;

  /// Меню на экране фильтра: без мыши первым — «Выбрать задачи», как у
  /// метки (решение 9 плана M4).
  final bool selectTasks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<_FilterAction>(
      tooltip: l10n.moreActions,
      iconSize: size,
      padding: EdgeInsets.zero,
      icon: const Icon(Icons.more_horiz),
      onSelected: (action) => _run(context, ref, action),
      itemBuilder: (context) => [
        if (selectTasks && touchLayout(context))
          PopupMenuItem(
            value: _FilterAction.selectTasks,
            child: Text(l10n.selectTasks),
          ),
        PopupMenuItem(value: _FilterAction.edit, child: Text(l10n.editFilter)),
        PopupMenuItem(
          value: _FilterAction.favorite,
          child: Text(
            filter.isFavorite ? l10n.removeFromFavorites : l10n.addToFavorites,
          ),
        ),
        PopupMenuItem(
          value: _FilterAction.duplicate,
          child: Text(l10n.actionDuplicate),
        ),
        PopupMenuItem(
          value: _FilterAction.delete,
          child: Text(l10n.deleteFilter),
        ),
      ],
    );
  }

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    _FilterAction action,
  ) async {
    final l10n = AppLocalizations.of(context);
    final commands = ref.read(filterCommandsProvider);
    final router = GoRouter.of(context);
    switch (action) {
      case _FilterAction.selectTasks:
        startTaskSelection(context, ref);
      case _FilterAction.edit:
        await showFilterDialog(context, filter: filter);
      case _FilterAction.favorite:
        await runCommand(
          context,
          () => commands.setFavorite(filter.id, !filter.isFavorite),
        );
      case _FilterAction.duplicate:
        await runCommand(
          context,
          () => commands.duplicate(filter.id, name: l10n.copyOf(filter.name)),
        );
      case _FilterAction.delete:
        final ok = await confirmAction(
          context,
          title: l10n.deleteFilterTitle,
          body: l10n.deleteFilterBody(filter.name),
          action: l10n.actionDelete,
          danger: true,
        );
        if (!ok || !context.mounted) return;
        final deleted = await runGuarded(
          ScaffoldMessenger.of(context),
          l10n,
          () => commands.delete(filter.id),
        );
        // Открыт экран удалённого фильтра — уходим на «Фильтры и метки».
        if (deleted && router.state.uri.path == '/filter/${filter.id}') {
          router.go('/filters-labels');
        }
    }
  }
}
