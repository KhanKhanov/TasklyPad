import 'package:flutter_test/flutter_test.dart';
import 'package:planner/core/clock.dart';
import 'package:planner/features/tasks/state/title_date_controller.dart';

// Поле названия существующей задачи без окна: язык разбора и даты из базы.
void main() {
  TitleDateController controller() =>
      TitleDateController(clock: FixedClock(DateTime.utc(2026, 10, 23, 9)));

  test('смена языка не делает даты названия новым сроком', () {
    final c = controller()..configure(lang: 'en', smartDates: true);
    c.reset('Позвонить завтра');
    expect(c.parsed, isNull, reason: 'en не знает «завтра»');
    c.configure(lang: 'ru', smartDates: true);
    expect(c.parsed, isNull);
    c.dispose();
  });

  test('дата из базы — текст, набранная после — срок', () {
    final c = controller()..configure(lang: 'ru', smartDates: true);
    c.reset('Отчёт завтра');
    expect(c.parsed, isNull);
    c.text = 'Отчёт завтра пятница';
    expect(c.parsed?.due?.date, '2026-10-30');
    expect(c.parsed?.title, 'Отчёт завтра');
    c.dispose();
  });
}
