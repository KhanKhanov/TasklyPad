import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/data_providers.dart';
import '../../../domain/models.dart';
import '../../../l10n/app_localizations.dart';
import '../../common/ui/ui_kit.dart';
import 'label_dialog.dart';

enum _LabelAction { edit, favorite, delete }

/// Меню «⋯» метки, как в Todoist: Редактировать метку, Избранное, Удалить
/// метку (с подтверждением).
class LabelMenuButton extends ConsumerWidget {
  const LabelMenuButton({super.key, required this.label, this.size = 20});

  final Label label;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<_LabelAction>(
      tooltip: l10n.moreActions,
      iconSize: size,
      padding: EdgeInsets.zero,
      icon: const Icon(Icons.more_horiz),
      onSelected: (action) => _run(context, ref, action),
      itemBuilder: (context) => [
        PopupMenuItem(value: _LabelAction.edit, child: Text(l10n.editLabel)),
        PopupMenuItem(
          value: _LabelAction.favorite,
          child: Text(
            label.isFavorite ? l10n.removeFromFavorites : l10n.addToFavorites,
          ),
        ),
        PopupMenuItem(
          value: _LabelAction.delete,
          child: Text(l10n.deleteLabel),
        ),
      ],
    );
  }

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    _LabelAction action,
  ) async {
    final l10n = AppLocalizations.of(context);
    final commands = ref.read(labelCommandsProvider);
    final router = GoRouter.of(context);
    switch (action) {
      case _LabelAction.edit:
        await showLabelDialog(context, label: label);
      case _LabelAction.favorite:
        await runCommand(
          context,
          () => commands.setFavorite(label.id, !label.isFavorite),
        );
      case _LabelAction.delete:
        final ok = await confirmAction(
          context,
          title: l10n.deleteLabelTitle,
          body: l10n.deleteLabelBody(label.name),
          action: l10n.actionDelete,
          danger: true,
        );
        if (!ok || !context.mounted) return;
        final deleted = await runGuarded(
          ScaffoldMessenger.of(context),
          l10n,
          () => commands.delete(label.id),
        );
        // Открыт экран удалённой метки — уходим на «Фильтры и метки».
        if (deleted && router.state.uri.path == '/label/${label.id}') {
          router.go('/filters-labels');
        }
    }
  }
}
