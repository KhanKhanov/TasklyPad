import 'package:flutter_test/flutter_test.dart';
import 'package:planner/core/clock.dart';
import 'package:planner/features/views/ui/view_groups.dart';

// День добавления в группах «по дате добавления» и день выполнения в
// «Сегодня» — по часам приложения (`AppClock.wallOf`), а не по поясу машины
// теста (О-102).
void main() {
  final instant = DateTime.utc(2026, 11, 13, 12);
  const added = '2026-11-13T10:30:00.000Z';

  test('localDayBy — день по поясу часов: +14 — 14-е, −11 — 12-е', () {
    String dayAt(Duration offset) =>
        localDayBy(FixedClock(instant, wallOffset: offset))(added);
    expect(dayAt(const Duration(hours: 14)), '2026-11-14');
    expect(dayAt(const Duration(hours: -11)), '2026-11-12');
  });

  test('localDayBy — неразборчивое время — его первые 10 символов', () {
    expect(localDayBy(FixedClock(instant))('2026-11-13 мусор'), '2026-11-13');
  });
}
