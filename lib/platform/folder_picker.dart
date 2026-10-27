/// Выбор папки синхронизации системным диалогом. Интерфейс — чтобы экран
/// настроек проверялся тестом без настоящего диалога.
abstract interface class FolderPicker {
  /// Можно ли на этой платформе выбрать папку и работать с ней через
  /// файловую систему. На Android папки других приложений (OneDrive,
  /// Syncthing) доступны только через SAF — это M6.
  bool get isSupported;

  /// Путь к выбранной папке или `null` — пользователь закрыл диалог.
  Future<String?> pickFolder({String? initialDirectory});
}

/// Выбора папки на этой платформе пока нет.
final class UnsupportedFolderPicker implements FolderPicker {
  const UnsupportedFolderPicker();

  @override
  bool get isSupported => false;

  @override
  Future<String?> pickFolder({String? initialDirectory}) async => null;
}
