import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:oplog_sync/oplog_sync.dart';

import '../../../app/sync_providers.dart';
import '../../../app/theme/app_palette.dart';
import '../../../l10n/app_localizations.dart';
import '../../../domain/sync_status.dart';
import '../../common/ui/ui_kit.dart';
import '../state/sync_controller.dart';
import 'change_folder_dialog.dart';
import 'settings_screen.dart';
import 'sync_devices.dart';

/// «Настройки → Синхронизация»: папка, статус, «Синхронизировать»,
/// устройства и «Пересобрать базу из журнала» (docs/plans/m2-core-app.md,
/// M2.3, коммит 2).
class SyncSection extends ConsumerWidget {
  const SyncSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final status = ref.watch(syncControllerProvider);
    final folder = status.folder;
    final supported = ref.watch(folderPickerProvider).isSupported;
    final secondary = TextStyle(color: palette.textSecondary, fontSize: 13);
    final recreatable = switch (status.error) {
      SyncFolderMissingException(:final path) => path.isNotEmpty,
      _ => false,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsHeader(l10n.syncSection),
        Text(
          l10n.syncFolder,
          style: TextStyle(
            color: palette.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        SelectableText(
          folder ?? l10n.syncFolderNone,
          style: TextStyle(
            color: folder == null ? palette.textSecondary : palette.textPrimary,
          ),
        ),
        if (folder == null) ...[
          const SizedBox(height: 4),
          Text(l10n.syncFolderHint, style: secondary),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (supported)
              OutlinedButton(
                onPressed: status.running
                    ? null
                    : () => _pickFolder(context, ref),
                child: Text(
                  folder == null ? l10n.chooseFolder : l10n.changeFolder,
                ),
              )
            else
              Text(l10n.syncUnsupported, style: secondary),
            if (folder != null)
              FilledButton.icon(
                onPressed: status.running
                    ? null
                    : () => ref.read(syncControllerProvider.notifier).syncNow(),
                icon: const Icon(Icons.sync, size: 18),
                label: Text(l10n.syncNow),
              ),
          ],
        ),
        if (folder != null) ...[
          const SizedBox(height: 12),
          Text(_statusText(context, status), style: secondary),
        ],
        // И без папки: первый выбор мог не сохраниться — причина видна здесь.
        if (status.error case final error?)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _errorText(l10n, error),
              style: TextStyle(color: palette.danger, fontSize: 13),
            ),
          ),
        // Папку удалили намеренно — начать заново в том же месте (решение
        // пользователя 1А к коммиту 2а M2.3).
        // Только когда сама выбранная папка на месте: без неё пересоздать
        // нельзя, а «забыть папку» сняло бы защиту — вернувшееся облако без
        // докачанного format.json получило бы вторую папку.
        if (folder != null && recreatable)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: status.running
                  ? null
                  : () => _recreateFolder(context, ref, folder),
              child: Text(l10n.recreateFolderAction),
            ),
          ),
        if (folder != null) ...[
          if (status.error == null && status.issues > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(l10n.syncIssues(status.issues), style: secondary),
            ),
          const SizedBox(height: 24),
          const SyncDevices(),
        ],
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => _rebuild(context, ref),
            child: Text(l10n.rebuildTitle),
          ),
        ),
      ],
    );
  }

  String _statusText(BuildContext context, SyncStatus status) {
    final l10n = AppLocalizations.of(context);
    if (status.running) return l10n.syncRunning;
    final last = status.lastSync;
    return last == null
        ? l10n.syncNever
        : l10n.syncLast(formatSyncTime(context, last));
  }

  static String _errorText(AppLocalizations l10n, Object error) =>
      switch (error) {
        SyncFormatException() => l10n.syncErrorFormat,
        SyncFolderMissingException(path: '') => l10n.syncErrorRootMissing,
        SyncFolderMissingException() => l10n.syncErrorFolderMissing,
        SyncBusyException() => l10n.syncErrorBusy,
        RetiredUnreadException() => l10n.syncErrorRetiredUnread,
        _ => l10n.syncErrorOther('$error'),
      };

  /// Выбрать папку; смена уже выбранной — после подтверждения, в котором
  /// отмечают устройства прежней папки, которыми больше не пользуются.
  Future<void> _pickFolder(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(syncControllerProvider.notifier);
    final current = ref.read(syncControllerProvider).folder;
    final path = await ref
        .read(folderPickerProvider)
        .pickFolder(initialDirectory: current);
    if (path == null || path == current || !context.mounted) return;
    var retired = const <String>{};
    if (current != null) {
      final devices = await controller.otherDevices();
      if (!context.mounted) return;
      final chosen = await confirmFolderChange(
        context,
        path: path,
        devices: devices,
      );
      if (chosen == null || !context.mounted) return;
      retired = chosen;
    }
    // Ошибка — текстом под статусом (состояние раздела), без второго тоста.
    var change = await controller.setFolder(path, retired: retired);
    // Часть правок отмеченных не прочитана: пройдёт ли это само, по ошибке
    // не понять (решение 12) — подождать или сменить всё равно решает
    // пользователь. Отказ — текст ошибки под статусом (до следующего
    // прохода). Раздел закрыли, пока шла смена, — спрашивать негде.
    if (change == null && !context.mounted) return;
    if (change == null &&
        ref.read(syncControllerProvider).error is RetiredUnreadException) {
      final force = await confirmAction(
        context,
        title: l10n.retiredUnreadTitle,
        body: l10n.retiredUnreadBody,
        action: l10n.retiredUnreadAction,
      );
      if (!force || !context.mounted) return;
      change = await controller.setFolder(path, retired: retired, force: true);
    }
    if (change == null || !messenger.mounted) return;
    final (:adopted, :unreadable, issues: _, error: _) = change;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          unreadable.isNotEmpty && adopted.isEmpty
              ? l10n.folderUnreadable(unreadable.length)
              : unreadable.isNotEmpty
              ? l10n.folderAdoptedPartial(adopted.length, unreadable.length)
              : adopted.isEmpty
              ? l10n.folderConnected
              : l10n.folderAdopted(adopted.length),
        ),
        // Предупреждение о непрочитанных правках — дольше обычного тоста.
        duration: unreadable.isNotEmpty
            ? const Duration(seconds: 10)
            : const Duration(seconds: 4),
      ),
    );
  }

  /// Создать пропавшую папку синхронизации заново в той же папке: после
  /// подтверждения — тот же выбор папки ([SyncController.setFolder]), который
  /// разрешает проходу её создать; правки отмеченных выбывших устройств из
  /// журнала переиздаются. Остальные устройства подхватят папку сами.
  Future<void> _recreateFolder(
    BuildContext context,
    WidgetRef ref,
    String folder,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(syncControllerProvider.notifier);
    final devices = await controller.journalDevices();
    if (!context.mounted) return;
    final retired = await confirmFolderRecreate(context, devices: devices);
    if (retired == null || !context.mounted) return;
    // «Всё равно»: прежней папки нет, прочитать отмеченных негде — их правки
    // берутся из журнала этого устройства.
    final change = await controller.setFolder(
      folder,
      retired: retired,
      force: true,
    );
    if (change == null || change.error != null || !messenger.mounted) return;
    final adopted = change.adopted.length;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          adopted == 0
              ? l10n.folderRecreated
              : l10n.folderRecreatedAdopted(adopted),
        ),
      ),
    );
  }

  Future<void> _rebuild(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await confirmAction(
      context,
      title: l10n.rebuildTitle,
      body: l10n.rebuildBody,
      action: l10n.rebuildAction,
    );
    if (!ok || !context.mounted) return;
    final done = await runGuarded(
      messenger,
      l10n,
      () => ref.read(syncControllerProvider.notifier).rebuild(),
    );
    if (done && messenger.mounted) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.rebuildDone)));
    }
  }
}

/// Время синхронизации в формате локали: дата и время на этом устройстве.
String formatSyncTime(BuildContext context, DateTime utc) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  return DateFormat.yMMMd(locale).add_Hm().format(utc.toLocal());
}
