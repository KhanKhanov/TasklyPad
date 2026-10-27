import 'package:oplog_sync/oplog_sync.dart';
import 'package:planner/platform/folder_picker.dart';
import 'package:planner/sync/sync_runner.dart';

/// [SyncRunner] без папки на диске: считает вызовы, отдаёт заданные
/// устройства и ошибки. Настоящие проходы проверяет test/sync/sync_runner_test.
final class FakeSyncRunner implements SyncRunner {
  FakeSyncRunner({this.folder});

  String? folder;
  DateTime? last;
  int syncs = 0;
  int rebuilds = 0;
  Object? failNext;

  /// Ошибка следующего [setFolder] — один раз.
  Object? failSetFolder;
  bool busyNext = false;
  Object? failDevices;
  List<SyncDevice> deviceList = const [];
  final List<String> folders = [];

  /// Отмеченные «больше не используется» при каждой смене папки.
  final List<Set<String>> retiredSets = [];

  /// `force` каждого вызова [setFolder], в том числе неудачного.
  final List<bool> forces = [];

  /// Узлы, чьи правки «переизданы»; `null` — все отмеченные.
  Set<String>? adoptedResult;

  /// Отмеченные узлы, часть правок которых «не прочитана».
  Set<String> unreadableResult = const {};

  /// Непрочитанные файлы первого прохода с новой папкой.
  int issuesResult = 0;

  /// Сбой первого прохода с уже сменённой папкой.
  Object? passErrorResult;

  @override
  Future<String?> folderPath() async => folder;

  @override
  Future<DateTime?> lastSync() async => last;

  @override
  Future<FolderSyncReport?> syncNow() async {
    if (folder == null) return null;
    if (busyNext) {
      busyNext = false;
      return null;
    }
    syncs++;
    final error = failNext;
    if (error != null) {
      failNext = null;
      throw error;
    }
    last = DateTime.utc(2026, 10, 27, 12, syncs);
    return FolderSyncReport();
  }

  @override
  Future<FolderChange> setFolder(
    String path, {
    Set<String> retired = const {},
    bool force = false,
  }) async {
    forces.add(force);
    final error = failSetFolder;
    if (error != null) {
      failSetFolder = null;
      throw error;
    }
    folder = path;
    folders.add(path);
    retiredSets.add(retired);
    await syncNow();
    return (
      adopted: adoptedResult ?? retired,
      unreadable: unreadableResult,
      issues: issuesResult,
      error: passErrorResult,
    );
  }

  @override
  Future<List<SyncDevice>> devices() async {
    final error = failDevices;
    if (error != null) throw error;
    return folder == null ? const [] : deviceList;
  }

  @override
  Future<void> rebuild() async => rebuilds++;
}

/// Диалог выбора папки, который сразу «выбирает» [path] (или отмену).
final class FakeFolderPicker implements FolderPicker {
  FakeFolderPicker(this.path, {this.isSupported = true});

  String? path;
  String? lastInitial;

  @override
  final bool isSupported;

  @override
  Future<String?> pickFolder({String? initialDirectory}) async {
    lastInitial = initialDirectory;
    return path;
  }
}
