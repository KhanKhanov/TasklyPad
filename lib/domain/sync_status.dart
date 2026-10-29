/// Типы синхронизации, которые показывает интерфейс: устройства в папке,
/// итог смены папки и ошибки прохода. Их выдаёт `SyncRunner` (lib/sync),
/// а экраны читают отсюда, не завися от адаптеров синхронизации.
library;

/// Итог смены папки: [adopted] — узлы, чьи правки переизданы (у отмеченного
/// узла все поля могли быть уже переписаны другими); [unreadable] — отмеченные
/// узлы, часть правок которых прочитать не удалось (смена с `force`);
/// [issues] — файлы устройств, которые первый проход с
/// новой папкой не прочитал (как `FolderSyncReport.issues`); [error] — этот
/// проход не удался (папка уже сменена).
typedef FolderChange = ({
  Set<String> adopted,
  Set<String> unreadable,
  int issues,
  Object? error,
});

/// Устройство в папке синхронизации — строка списка «Устройства».
final class SyncDevice {
  const SyncDevice({
    required this.nodeId,
    required this.isThisDevice,
    this.name,
    this.platform,
    this.profile,
    this.updated,
    this.lastEdit,
    this.isFormerThisDevice = false,
  });

  final String nodeId;
  final bool isThisDevice;

  /// Имя компьютера или телефона из `info.json`.
  final String? name;
  final String? platform;

  /// Профиль данных (`--profile`): на одном ПК их может быть несколько.
  final String? profile;

  /// Когда устройство последний раз выгружало свои правки (`info.json`).
  final DateTime? updated;

  /// Время его последней правки в журнале этого устройства — у устройств
  /// из журнала (`SyncRunner.journalDevices`), у которых нет `info.json`.
  final DateTime? lastEdit;

  /// Прежний id этого устройства: база скопирована (перенос, резервная
  /// копия). Отмечать, если копией-источником больше не пользуются.
  final bool isFormerThisDevice;
}

/// Смена папки не начата: последний проход с прежней папкой не прочитал часть
/// правок отмеченных выбывших устройств — облако ещё докачивает файлы, файл
/// повреждён, часы устройства ушли вперёд или прежняя папка недоступна.
/// Пользователь ждёт или меняет папку с `force`.
final class RetiredUnreadException implements Exception {
  const RetiredUnreadException(this.nodes, {this.cause});

  final Set<String> nodes;

  /// Ошибка прохода, если прежняя папка недоступна целиком.
  final Object? cause;

  @override
  String toString() => 'RetiredUnreadException($nodes, $cause)';
}

/// Проход не состоялся: синхронизацию этой базы уже ведёт другой проход.
final class SyncBusyException implements Exception {
  const SyncBusyException();

  @override
  String toString() => 'SyncBusyException';
}
