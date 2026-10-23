/// Минимальный интерфейс файловой системы для транспорта через папку.
///
/// Пути — строки с разделителем `/`, относительно корня папки синхронизации.
/// Реализации: `dart:io` на Windows, Storage Access Framework на Android,
/// [MemorySyncFs] в тестах. Пакет не импортирует `dart:io`, поэтому тесты
/// слияния не трогают диск.
abstract interface class SyncFs {
  Future<bool> exists(String path);

  /// Имена (не пути) файлов и папок непосредственно внутри [dir].
  Future<List<String>> list(String dir);

  Future<String> readString(String path);

  /// Записать файл целиком. Реализация обязана делать это атомарно
  /// (временный файл + переименование), чтобы облачный клиент не увидел
  /// полузаписанный файл.
  Future<void> writeString(String path, String content);

  /// Дописать в конец файла (создать, если нет).
  Future<void> appendString(String path, String content);

  /// Создать папку вместе с родителями; существующая — не ошибка.
  Future<void> createDir(String path);
}

/// Файловая система в памяти для тестов.
final class MemorySyncFs implements SyncFs {
  final Map<String, String> _files = <String, String>{};
  final Set<String> _dirs = <String>{};

  static String _norm(String path) =>
      path.split('/').where((s) => s.isNotEmpty).join('/');

  static String _parent(String path) {
    final i = path.lastIndexOf('/');
    return i < 0 ? '' : path.substring(0, i);
  }

  /// Содержимое для проверок в тестах.
  Map<String, String> get files => Map.unmodifiable(_files);

  @override
  Future<bool> exists(String path) async {
    final p = _norm(path);
    return p.isEmpty || _files.containsKey(p) || _dirs.contains(p);
  }

  @override
  Future<List<String>> list(String dir) async {
    final d = _norm(dir);
    final prefix = d.isEmpty ? '' : '$d/';
    final names = <String>{};
    for (final path in _files.keys.followedBy(_dirs)) {
      if (!path.startsWith(prefix) || path == d) continue;
      final rest = path.substring(prefix.length);
      final slash = rest.indexOf('/');
      names.add(slash < 0 ? rest : rest.substring(0, slash));
    }
    return names.toList()..sort();
  }

  @override
  Future<String> readString(String path) async {
    final content = _files[_norm(path)];
    if (content == null) throw StateError('Файл не найден: $path');
    return content;
  }

  @override
  Future<void> writeString(String path, String content) async {
    final p = _norm(path);
    await createDir(_parent(p));
    _files[p] = content;
  }

  @override
  Future<void> appendString(String path, String content) async {
    final p = _norm(path);
    await createDir(_parent(p));
    _files[p] = (_files[p] ?? '') + content;
  }

  @override
  Future<void> createDir(String path) async {
    var p = _norm(path);
    while (p.isNotEmpty) {
      _dirs.add(p);
      p = _parent(p);
    }
  }
}
