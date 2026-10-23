import 'package:flutter_test/flutter_test.dart';
import 'package:oplog_sync/testing.dart';
import 'package:planner/data/app_database.dart';
import 'package:planner/sync/drift_sync_state_store.dart';

import 'support/drift_probe.dart';

// Те же сценарии, что пакет прогоняет на MemoryOpStore: база ведёт себя как эталон.
void main() {
  group('OpStore на DriftOpStore', () {
    for (final scenario in opStoreScenarios) {
      test(scenario.name, () => scenario.run(driftProbeFactory));
    }
  });

  group('SyncStateStore на DriftSyncStateStore', () {
    for (final scenario in syncStateScenarios) {
      test(
        scenario.name,
        () => scenario.run(() async => DriftSyncStateStore(memoryDatabase())),
      );
    }
  });

  test('AppDatabase — схема создаётся с текущей версией', () async {
    final db = memoryDatabase();
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.data.values.single, AppDatabase.currentSchemaVersion);
  });
}
