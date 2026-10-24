import 'package:oplog_sync/oplog_sync.dart';
import 'package:oplog_sync/testing.dart';
import 'package:test/test.dart';

// Контракт SyncFs на эталоне в памяти. Приложение прогоняет те же сценарии
// на папке на диске (IoSyncFs).
void main() {
  group('SyncFs на MemorySyncFs', () {
    for (final scenario in syncFsScenarios) {
      test(scenario.name, () => scenario.run(memorySyncFsFactory));
    }
  });

  test('readString несуществующего файла — StateError', () {
    expect(() => MemorySyncFs().readString('nope'), throwsStateError);
  });
}
