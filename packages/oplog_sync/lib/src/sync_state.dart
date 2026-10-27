import 'hlc.dart';

/// Локальное состояние транспорта через папку: что уже прочитано и выгружено.
///
/// Не синхронизируется — у каждого устройства своё. В приложении — таблица
/// `sync_cursors` в той же базе, что и журнал; в тестах — [MemorySyncStateStore].
/// Обновляется после применения ops, а не в одной транзакции с ними: если
/// приложение упадёт между этими шагами, чанк перечитается, и дубликаты ops
/// отбросит идемпотентность движка.
///
/// Всё состояние относится к одной папке синхронизации ([folderId]): когда
/// пользователь выбирает папку, его забывают ([forgetFolder]); другой
/// `folder_id` в папке сбрасывает его через [resetForFolder].
abstract interface class SyncStateStore {
  /// Id папки (`folder_id` из `format.json`), к которой относятся курсоры,
  /// или `null`, если синхронизации ещё не было.
  Future<String?> folderId();

  /// Забыть курсоры и [uploadedUpTo] и запомнить новую папку [folderId].
  Future<void> resetForFolder(String folderId);

  /// Забыть папку, курсоры и [uploadedUpTo]: пользователь выбрал папку
  /// (другую или ту же заново). Пока папка не известна, транспорт может
  /// создать в ней `format.json`; известная папка без него — ошибка
  /// (`SyncFolderMissingException`), а не новая папка.
  Future<void> forgetFolder();

  /// Номер последнего полностью применённого чанка узла [nodeId] (0 — ничего).
  Future<int> chunkCursor(String nodeId);

  Future<void> setChunkCursor(String nodeId, int seq);

  /// HLC последней своей op, уже записанной в папку (`null` — ничего).
  ///
  /// Работает как «водяной знак», потому что HLC своих ops строго растёт —
  /// при условии, что приложение восстанавливает часы движка между запусками
  /// (транспорт проверяет это и бросает [StateError]).
  Future<Hlc?> uploadedUpTo();

  Future<void> setUploadedUpTo(Hlc hlc);
}

/// Состояние транспорта в памяти — для тестов.
final class MemorySyncStateStore implements SyncStateStore {
  final Map<String, int> _cursors = <String, int>{};
  String? _folderId;
  Hlc? _uploaded;

  @override
  Future<String?> folderId() async => _folderId;

  @override
  Future<void> resetForFolder(String folderId) async {
    _cursors.clear();
    _uploaded = null;
    _folderId = folderId;
  }

  @override
  Future<void> forgetFolder() async {
    _cursors.clear();
    _uploaded = null;
    _folderId = null;
  }

  @override
  Future<int> chunkCursor(String nodeId) async => _cursors[nodeId] ?? 0;

  @override
  Future<void> setChunkCursor(String nodeId, int seq) async =>
      _cursors[nodeId] = seq;

  @override
  Future<Hlc?> uploadedUpTo() async => _uploaded;

  @override
  Future<void> setUploadedUpTo(Hlc hlc) async => _uploaded = hlc;
}
