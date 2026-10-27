import 'package:flutter/material.dart';

import '../../../app/theme/app_palette.dart';
import '../../../l10n/app_localizations.dart';
import '../../../sync/sync_runner.dart';
import 'sync_devices.dart';
import 'sync_section.dart';

/// Подтверждение смены папки (docs/plans/m2-core-app.md, решение 12):
/// пояснение и другие устройства прежней папки с отметкой «больше не
/// используется» — по умолчанию не отмечены. Возвращает отмеченные узлы;
/// `null` — смену отменили. [devices] `null` — устройства прежней папки
/// прочитать не удалось.
Future<Set<String>?> confirmFolderChange(
  BuildContext context, {
  required String path,
  required List<SyncDevice>? devices,
}) => showDialog<Set<String>>(
  context: context,
  builder: (_) => _ChangeFolderDialog(path: path, devices: devices),
);

class _ChangeFolderDialog extends StatefulWidget {
  const _ChangeFolderDialog({required this.path, required this.devices});

  final String path;
  final List<SyncDevice>? devices;

  @override
  State<_ChangeFolderDialog> createState() => _ChangeFolderDialogState();
}

class _ChangeFolderDialogState extends State<_ChangeFolderDialog> {
  final Set<String> _retired = {};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final secondary = TextStyle(color: palette.textSecondary, fontSize: 13);
    final devices = widget.devices;
    return AlertDialog(
      title: Text(l10n.changeFolderTitle),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.changeFolderBody(widget.path)),
              if (devices == null) ...[
                const SizedBox(height: 12),
                Text(l10n.changeFolderNoDevices, style: secondary),
              ] else if (devices.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(l10n.changeFolderRetiredHint, style: secondary),
                for (final device in devices)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _retired.contains(device.nodeId),
                    onChanged: (on) => setState(
                      () => (on ?? false)
                          ? _retired.add(device.nodeId)
                          : _retired.remove(device.nodeId),
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
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, Set.of(_retired)),
          child: Text(l10n.changeFolderAction),
        ),
      ],
    );
  }
}
