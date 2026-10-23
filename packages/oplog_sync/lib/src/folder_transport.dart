import 'fs.dart';
import 'merge_engine.dart';

/// Обмен ops через общую папку (OneDrive, Google Drive, Syncthing, …).
///
/// Раскладка (docs/SYNC_DESIGN.md):
/// ```
/// <root>/format.json                 { "v": 1 }
/// <root>/nodes/<node_id>/info.json
/// <root>/nodes/<node_id>/<seq>.ndjson   append-only чанки ops
/// <root>/nodes/<node_id>/snapshot-<hlc>.ndjson
/// ```
/// Узел пишет только в свою папку, чужие читает. Реализуется на этапе M1.
final class FolderTransport {
  FolderTransport({required this.fs, required this.engine, this.root = ''});

  final SyncFs fs;
  final MergeEngine engine;

  /// Путь к `planner-sync` относительно корня [fs].
  final String root;

  /// Версия формата папки. Меняется только с миграцией.
  static const int formatVersion = 1;

  /// Выгрузить свои новые ops и вчитать чужие.
  Future<ApplyReport> sync() {
    // TODO(M1): чанки, курсоры по узлам, info.json, частично записанные строки.
    throw UnimplementedError('FolderTransport.sync — этап M1');
  }
}
