import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_palette.dart';
import '../../../l10n/app_localizations.dart';
import '../../common/ui/ui_kit.dart';
import '../../settings/state/sync_controller.dart';
import '../../settings/ui/sync_section.dart';

/// «Синхронизировать» из меню и по `Ctrl+S`: без папки синхронизации — в
/// «Настройки», где её выбирают; пока идёт синхронизация или настройки ещё
/// не прочитаны (папка неизвестна) — ничего.
void syncFromShell(BuildContext context, WidgetRef ref) {
  final status = ref.read(syncControllerProvider);
  if (!status.loaded || status.running) return;
  if (status.folder == null) return navigate(context, '/settings');
  unawaited(ref.read(syncControllerProvider.notifier).syncNow());
}

/// Меню под названием в сайдбаре — как меню аватара в Todoist: «Настройки»
/// (`o s`) и «Синхронизировать» со временем последней синхронизации (help
/// «Troubleshoot syncing issues»: «Click your avatar at the top-left. Select
/// Sync»). Без папки синхронизации пункт ведёт в «Настройки», где её выбирают.
class AccountMenu extends ConsumerWidget {
  const AccountMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    return PopupMenuButton<void>(
      tooltip: l10n.settings,
      itemBuilder: (context) {
        final status = ref.read(syncControllerProvider);
        final last = status.lastSync;
        final line = status.running
            ? l10n.syncRunning
            : status.folder == null
            ? l10n.syncFolderNone
            : last == null
            ? l10n.syncNever
            : l10n.syncLast(formatSyncTime(context, last));
        return [
          PopupMenuItem<void>(
            onTap: () => navigate(context, '/settings'),
            child: Text(l10n.settings),
          ),
          const PopupMenuDivider(),
          PopupMenuItem<void>(
            enabled: !status.running,
            onTap: () => syncFromShell(context, ref),
            child: Row(
              children: [
                Icon(Icons.sync, size: 18, color: palette.textSecondary),
                const SizedBox(width: 12),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(l10n.syncNow),
                      Text(
                        line,
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ];
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.appTitle,
              style: TextStyle(
                color: palette.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down,
              size: 18,
              color: palette.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
