import 'dart:async';
import 'dart:io';

import 'package:oplog_sync/oplog_sync.dart';
import 'package:path/path.dart' as p;

/// [SyncFs] поверх `dart:io` — папка синхронизации на диске (Windows).
///
/// Пути транспорта (`nodes/a/000001.ndjson`) отсчитываются от [root].
/// Файл пишется целиком во временный файл рядом с целевым и переименовывается:
/// облачный клиент видит либо старый файл, либо новый, но не половину.
/// Временное имя (`.000001.ndjson.<pid>-<n>.tmp`) не похоже на чанк, поэтому
/// читатели его пропускают, даже если после сбоя он остался в папке.
final class IoSyncFs implements SyncFs {
  IoSyncFs(this.root);

  /// Абсолютный путь к корню папки синхронизации.
  final String root;

  /// Счётчик временных файлов на процесс: два экземпляра в одном процессе
  /// не получат одно имя.
  static int _tempSeq = 0;

  String _resolve(String path) {
    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.any((s) => s == '..' || s == '.' || s.contains(r'\'))) {
      throw ArgumentError.value(path, 'path', 'путь выходит за корень папки');
    }
    return p.joinAll([root, ...segments]);
  }

  @override
  Future<bool> exists(String path) => _exists(_resolve(path));

  @override
  Future<List<String>> list(String dir) async {
    final directory = Directory(_resolve(dir));
    if (!await directory.exists()) return const [];
    final names = await directory
        .list()
        .map((entity) => p.basename(entity.path))
        .toList();
    return names..sort();
  }

  @override
  Future<String> readString(String path) => File(_resolve(path)).readAsString();

  @override
  Future<void> writeString(String path, String content) async {
    final target = _resolve(path);
    final temp = await _writeTemp(target, content);
    await _moveInto(temp, target);
  }

  /// Проверка «файла нет» — до записи и перед переименованием. Внутри
  /// процесса записи одного пути идут по очереди, поэтому точны. Между
  /// процессами между второй проверкой и `rename` остаётся узкое окно: в
  /// `dart:io` нет переименования без замены. Одного писателя в папку узла
  /// гарантируют аренда синхронизации и уникальный id узла; эта проверка —
  /// вторая линия защиты от списка файлов, отставшего от диска.
  @override
  Future<bool> writeStringIfAbsent(String path, String content) {
    final target = _resolve(path);
    return _queued(target, () async {
      if (await _exists(target)) return false;
      final temp = await _writeTemp(target, content);
      if (await _exists(target)) {
        await _deleteQuietly(temp);
        return false;
      }
      await _moveInto(temp, target);
      return true;
    });
  }

  /// Последняя запись каждого пути в этом процессе (ключ без учёта регистра
  /// на Windows — `canonicalize`).
  static final Map<String, Future<void>> _queue = {};

  static Future<T> _queued<T>(
    String target,
    Future<T> Function() action,
  ) async {
    final key = p.canonicalize(target);
    final previous = _queue[key] ?? Future<void>.value();
    final done = Completer<void>();
    _queue[key] = done.future;
    try {
      await previous;
      return await action();
    } finally {
      done.complete();
      // Убрать запись, если за нами никто не встал в очередь.
      _queue.removeWhere((k, last) => k == key && identical(last, done.future));
    }
  }

  static Future<bool> _exists(String path) async =>
      await FileSystemEntity.type(path) != FileSystemEntityType.notFound;

  @override
  Future<void> appendString(String path, String content) async {
    final file = File(_resolve(path));
    await file.parent.create(recursive: true);
    await file.writeAsString(content, mode: FileMode.append, flush: true);
  }

  @override
  Future<void> createDir(String path) async {
    await Directory(_resolve(path)).create(recursive: true);
  }

  /// Временный файл в той же папке: `rename` внутри одного тома атомарен.
  /// `flush` — данные на диске до переименования, иначе после сбоя питания
  /// под целевым именем может оказаться пустой файл.
  static Future<File> _writeTemp(String target, String content) async {
    final dir = Directory(p.dirname(target));
    await dir.create(recursive: true);
    final temp = File(
      p.join(dir.path, '.${p.basename(target)}.$pid-${_tempSeq++}.tmp'),
    );
    try {
      await temp.writeAsString(content, flush: true);
    } on Object {
      await _deleteQuietly(temp);
      rethrow;
    }
    return temp;
  }

  /// Коды Windows «отказано в доступе» и «файл занят другим процессом»:
  /// облачный клиент и антивирус ненадолго держат только что записанный файл.
  static const Set<int> _busyCodes = {5, 32};

  /// Паузы между повторами `rename`, пока целевой файл занят.
  static const List<Duration> _retryDelays = [
    Duration(milliseconds: 100),
    Duration(milliseconds: 200),
    Duration(milliseconds: 400),
    Duration(milliseconds: 800),
  ];

  static Future<void> _moveInto(File temp, String target) async {
    for (var attempt = 0; ; attempt++) {
      try {
        await temp.rename(target);
        return;
      } on FileSystemException catch (e) {
        final busy =
            Platform.isWindows && _busyCodes.contains(e.osError?.errorCode);
        if (busy && attempt < _retryDelays.length) {
          await Future<void>.delayed(_retryDelays[attempt]);
          continue;
        }
        await _deleteQuietly(temp);
        rethrow;
      } on Object {
        await _deleteQuietly(temp);
        rethrow;
      }
    }
  }

  static Future<void> _deleteQuietly(File file) async {
    try {
      await file.delete();
    } on FileSystemException {
      // Не удалось — останется мусорный .tmp, читатели его пропускают.
    }
  }
}
