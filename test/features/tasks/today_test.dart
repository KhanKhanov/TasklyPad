import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/app/data_providers.dart';
import 'package:planner/core/clock.dart';
import 'package:planner/features/tasks/state/today.dart';

// «Сегодня» для подписей срока — по стенным часам устройства (`nowWall`), а
// не по поясу машины, на которой идёт тест.
void main() {
  // 23.10.2026 23:30 UTC: в поясе +14 уже 24-е, в поясе −12 ещё 23-е. Пояс
  // машины один — по нему оба ожидания сразу не выполнились бы.
  final instant = DateTime.utc(2026, 10, 23, 23, 30);

  DateTime todayAt(Duration wallOffset) {
    final container = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(
          FixedClock(instant, wallOffset: wallOffset),
        ),
      ],
    );
    try {
      return container.read(todayProvider);
    } finally {
      container.dispose();
    }
  }

  testWidgets('сегодня — дата стенных часов: +14 — 24-е, −12 — 23-е', (
    tester,
  ) async {
    expect(todayAt(const Duration(hours: 14)), DateTime(2026, 10, 24));
    expect(todayAt(const Duration(hours: -12)), DateTime(2026, 10, 23));
  });

  group('время срока сегодня прошло', () {
    // Пт 23.10.2026 09:00 по стенным часам.
    final at9 = DateTime.utc(2026, 10, 23, 9);

    testWidgets('сегодня до времени — нет, в момент и после — да; другой '
        'день и время без часов — нет', (tester) async {
      final container = ProviderContainer(
        overrides: [clockProvider.overrideWithValue(FixedClock(at9))],
      );
      bool passed(String date, String time) =>
          container.read(dueTimePassedProvider(date, time));
      expect(passed('2026-10-23', '08:59'), isTrue);
      expect(passed('2026-10-23', '09:00'), isTrue);
      expect(passed('2026-10-23', '09:01'), isFalse);
      expect(passed('2026-10-22', '08:00'), isFalse);
      expect(passed('2026-10-24', '08:00'), isFalse);
      expect(passed('2026-10-23', 'утро'), isFalse);
      // Таймеры провайдера — до проверки «таймеров не осталось».
      container.dispose();
    });

    testWidgets('сам становится «да» в момент срока', (tester) async {
      final clock = FixedClock(at9);
      final container = ProviderContainer(
        overrides: [clockProvider.overrideWithValue(clock)],
      );
      final provider = dueTimePassedProvider('2026-10-23', '09:30');
      final seen = <bool>[];
      container.listen(provider, (_, v) => seen.add(v), fireImmediately: true);
      clock.advance(const Duration(minutes: 30));
      await tester.pump(const Duration(minutes: 30));
      expect(seen, [false, true]);
      container.dispose();
    });
  });
}
