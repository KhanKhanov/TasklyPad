import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_palette.dart';
import '../../../l10n/app_localizations.dart';
import '../../common/ui/ui_kit.dart';
import '../state/sidebar_state.dart';

/// Верхняя строка контента: кнопка открыть сайдбар, когда он скрыт; справа —
/// «Настройки», как в шапке Todoist (решение пользователя 2А «Ход M3.8»).
class TopBar extends ConsumerWidget {
  const TopBar({super.key, required this.showToggle});

  final bool showToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          if (showToggle)
            IconButton(
              tooltip: l10n.toggleSidebar,
              icon: const Icon(Icons.view_sidebar_outlined, size: 20),
              color: palette.textSecondary,
              onPressed: () {
                final scaffold = Scaffold.of(context);
                if (scaffold.hasDrawer) {
                  scaffold.openDrawer();
                } else {
                  ref.read(sidebarOpenProvider.notifier).toggle();
                }
              },
            ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: palette.textSecondary,
              ),
              icon: const Icon(Icons.settings_outlined, size: 20),
              label: Text(l10n.settings),
              onPressed: () => navigate(context, '/settings'),
            ),
          ),
        ],
      ),
    );
  }
}
