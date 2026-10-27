import 'package:file_selector/file_selector.dart';

import '../folder_picker.dart';

/// [FolderPicker] через `file_selector` — системный диалог выбора папки
/// Windows. На Android папка выбирается через SAF (M6).
final class FileSelectorFolderPicker implements FolderPicker {
  const FileSelectorFolderPicker();

  @override
  bool get isSupported => true;

  @override
  Future<String?> pickFolder({String? initialDirectory}) =>
      getDirectoryPath(initialDirectory: initialDirectory);
}
