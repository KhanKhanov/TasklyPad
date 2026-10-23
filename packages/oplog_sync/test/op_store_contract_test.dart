import 'package:oplog_sync/testing.dart';
import 'package:test/test.dart';

// Контракт хранилищ на эталонных реализациях в памяти. Приложение прогоняет
// те же сценарии на базе drift.
void main() {
  group('OpStore на MemoryOpStore', () {
    for (final scenario in opStoreScenarios) {
      test(scenario.name, () => scenario.run(memoryProbeFactory));
    }
  });

  group('SyncStateStore на MemorySyncStateStore', () {
    for (final scenario in syncStateScenarios) {
      test(scenario.name, () => scenario.run(memorySyncStateFactory));
    }
  });

  group('помощники проверок', () {
    test('check — расхождение даёт ContractFailure с обоими значениями', () {
      expect(
        () => check(1, 2, 'число'),
        throwsA(
          isA<ContractFailure>().having(
            (f) => f.message,
            'message',
            'число: ожидал <2>, получил <1>',
          ),
        ),
      );
    });

    test('checkThrows — нет исключения → ContractFailure', () async {
      await expectLater(
        checkThrows<StateError>(() async => 1, 'действие'),
        throwsA(isA<ContractFailure>()),
      );
    });

    test('checkThrows — исключение другого типа → ContractFailure', () async {
      await expectLater(
        checkThrows<StateError>(() async => throw ArgumentError(), 'действие'),
        throwsA(isA<ContractFailure>()),
      );
    });
  });
}
