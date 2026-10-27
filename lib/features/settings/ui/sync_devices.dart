import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_palette.dart';
import '../../../l10n/app_localizations.dart';
import '../../../sync/sync_runner.dart';
import '../state/sync_controller.dart';
import 'sync_section.dart';

/// «Устройства»: узлы в папке синхронизации по их `info.json` — имя
/// компьютера (с профилем), когда выгружало правки, «это устройство».
class SyncDevices extends ConsumerWidget {
  const SyncDevices({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final devices = ref.watch(syncDevicesProvider).value ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.devicesHeader,
          style: TextStyle(
            color: palette.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        for (final device in devices)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: Icon(
              device.platform == 'android'
                  ? Icons.smartphone_outlined
                  : Icons.computer_outlined,
              color: palette.textSecondary,
            ),
            title: Text(deviceTitle(l10n, device)),
            subtitle: device.updated == null
                ? null
                : Text(
                    l10n.deviceUpdated(
                      formatSyncTime(context, device.updated!),
                    ),
                  ),
          ),
      ],
    );
  }
}

/// Название устройства в списках: имя компьютера, профиль, «это устройство».
String deviceTitle(AppLocalizations l10n, SyncDevice device) {
  final name = device.name ?? l10n.deviceUnnamed;
  final profile = device.profile;
  final title = profile == null ? name : l10n.deviceWithProfile(name, profile);
  return device.isThisDevice ? l10n.deviceThis(title) : title;
}
