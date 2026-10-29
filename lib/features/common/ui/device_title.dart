import '../../../domain/sync_status.dart';
import '../../../l10n/app_localizations.dart';

/// Название устройства в списках: имя компьютера, профиль, «это устройство».
String deviceTitle(AppLocalizations l10n, SyncDevice device) {
  final name =
      device.name ??
      (device.isFormerThisDevice ? l10n.deviceFormerThis : l10n.deviceUnnamed);
  final profile = device.profile;
  final title = profile == null ? name : l10n.deviceWithProfile(name, profile);
  return device.isThisDevice ? l10n.deviceThis(title) : title;
}
