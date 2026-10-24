import 'package:flutter_test/flutter_test.dart';
import 'package:oplog_sync/testing.dart';
import 'package:planner/sync/drift_sync_state_store.dart';
import 'package:planner/sync/io_sync_fs.dart';

import '../data/support/drift_probe.dart';
import 'support/devices.dart';

// Сценарии из «Инвариантов реализации» (docs/SYNC_DESIGN.md) — те же, что
// пакет гоняет в памяти, но каждый узел — своя база drift, а общая папка —
// временная папка на диске через IoSyncFs.
void main() {
  Future<FolderSyncEnv> diskEnv() async => FolderSyncEnv(
    fs: IoSyncFs(tempDir('folder_sync_').path),
    storage: () async {
      final db = memoryDatabase();
      return (probe: DriftProbe(db), state: DriftSyncStateStore(db));
    },
  );

  for (final scenario in folderSyncScenarios) {
    test(scenario.name, () => scenario.run(diskEnv));
  }
}
