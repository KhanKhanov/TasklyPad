import 'package:flutter/material.dart';

import '../../../app/theme/app_palette.dart';
import '../../../l10n/app_localizations.dart';
import '../../../domain/sync_status.dart';
import '../../common/ui/device_title.dart';
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
}) {
  final l10n = AppLocalizations.of(context);
  return showDialog<Set<String>>(
    context: context,
    builder: (_) => _ChangeFolderDialog(
      title: l10n.changeFolderTitle,
      body: l10n.changeFolderBody(path),
      hint: l10n.changeFolderRetiredHint,
      noDevices: l10n.changeFolderNoDevices,
      action: l10n.changeFolderAction,
      devices: devices,
    ),
  );
}

/// Подтверждение «Создать папку заново» (план M2.3, коммит 2а): то же, но
/// устройства — из журнала этого устройства, без имён (решение пользователя
/// 5А): папки с их `info.json` больше нет.
Future<Set<String>?> confirmFolderRecreate(
  BuildContext context, {
  required List<SyncDevice>? devices,
}) {
  final l10n = AppLocalizations.of(context);
  return showDialog<Set<String>>(
    context: context,
    builder: (_) => _ChangeFolderDialog(
      title: l10n.recreateFolderTitle,
      body: l10n.recreateFolderBody,
      hint: l10n.recreateFolderRetiredHint,
      noDevices: l10n.recreateFolderNoDevices,
      action: l10n.recreateFolderAction,
      devices: devices,
    ),
  );
}

class _ChangeFolderDialog extends StatefulWidget {
  const _ChangeFolderDialog({
    required this.title,
    required this.body,
    required this.hint,
    required this.noDevices,
    required this.action,
    required this.devices,
  });

  final String title;
  final String body;

  /// Пояснение к списку устройств.
  final String hint;

  /// Текст, если устройства прочитать не удалось ([devices] — `null`).
  final String noDevices;
  final String action;
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
      title: Text(widget.title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.body),
              if (devices == null) ...[
                const SizedBox(height: 12),
                Text(widget.noDevices, style: secondary),
              ] else if (devices.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(widget.hint, style: secondary),
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
                    subtitle: _subtitle(context, l10n, device),
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
          child: Text(widget.action),
        ),
      ],
    );
  }

  /// Когда устройство выгружало правки (папка) или когда последний раз вносило
  /// их (журнал); у устройства из журнала — ещё конец id: имён у них нет.
  static Widget? _subtitle(
    BuildContext context,
    AppLocalizations l10n,
    SyncDevice device,
  ) {
    if (device.lastEdit case final lastEdit?) {
      final id = device.nodeId;
      return Text(
        l10n.deviceLastEdit(
          formatSyncTime(context, lastEdit),
          id.length > 6 ? id.substring(id.length - 6) : id,
        ),
      );
    }
    final updated = device.updated;
    return updated == null
        ? null
        : Text(l10n.deviceUpdated(formatSyncTime(context, updated)));
  }
}
