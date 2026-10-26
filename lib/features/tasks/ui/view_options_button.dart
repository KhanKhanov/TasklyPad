import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_palette.dart';
import '../../../l10n/app_localizations.dart';
import '../state/view_options.dart';

/// Кнопка «Просмотр» в заголовке вида. В M2.2 в ней один переключатель —
/// «Выполненные задачи»; сортировка и группировка — M4.
class ViewOptionsButton extends ConsumerWidget {
  const ViewOptionsButton({super.key, required this.viewId});

  final String viewId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final show = ref.watch(showCompletedProvider(viewId));
    return PopupMenuButton<void>(
      tooltip: l10n.viewOptions,
      itemBuilder: (context) => [
        CheckedPopupMenuItem<void>(
          checked: show,
          onTap: () =>
              ref.read(showCompletedProvider(viewId).notifier).toggle(),
          child: Text(l10n.completedTasks),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tune, size: 18, color: palette.textSecondary),
            const SizedBox(width: 4),
            Text(
              l10n.viewOptions,
              style: TextStyle(color: palette.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
