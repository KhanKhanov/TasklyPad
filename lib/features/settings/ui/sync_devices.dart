import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_palette.dart';
import '../../../l10n/app_localizations.dart';
import '../../../domain/sync_status.dart';
import '../../common/ui/device_title.dart';
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
    final async = ref.watch(syncDevicesProvider);
    // При ошибке AsyncValue хранит и прежний список — показывать его нельзя:
    // папки, из которой он прочитан, уже может не быть.
    final unread = async.hasError;
    final devices = unread ? const <SyncDevice>[] : async.value ?? const [];
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
        if (unread)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              l10n.devicesUnread,
              style: TextStyle(color: palette.textSecondary, fontSize: 13),
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
