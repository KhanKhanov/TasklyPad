import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/app/theme/app_palette.dart';
import 'package:planner/domain/models.dart';
import 'package:planner/features/tasks/ui/task_row.dart';

import '../../app/support/pump_app.dart';
import '../support/app_commands.dart';

// Цвет срока в строке задачи (решение 3А конца M3, help «Introduction to dates
// and time»). Часы — пт 23.10.2026 9:00, локаль — en.
void main() {
  Finder row(String content) =>
      find.ancestor(of: find.text(content), matching: find.byType(TaskRow));

  /// Цвет подписи срока строки [content] (рядом со значком календаря).
  Color dueColor(WidgetTester tester, String content) => tester
      .widget<Icon>(
        find.descendant(
          of: row(content),
          matching: find.byIcon(Icons.calendar_today_outlined),
        ),
      )
      .color!;

  testWidgets('просрочено, сегодня, завтра, через 2–7 дней, дальше — цвета по '
      'help', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      for (final (content, date) in [
        ('Late', '2026-10-22'),
        ('Now', '2026-10-23'),
        ('Next', '2026-10-24'),
        ('Soon', '2026-10-25'),
        ('Week', '2026-10-30'),
        ('Far', '2026-10-31'),
      ]) {
        await tester.runAsync(
          () => app.tasks.add(
            content: content,
            due: Due(date: date),
          ),
        );
        // Поток первой правки держит базу, пока экран её не прочитал
        // (ловушка M3.6): следующая правка — после перестройки.
        await settle(tester);
      }
      final p = AppPalette.of(tester.element(find.byType(TaskRow).first));
      expect(
        [
          for (final c in ['Late', 'Now', 'Next', 'Soon', 'Week', 'Far'])
            dueColor(tester, c),
        ],
        [
          p.danger,
          p.dateToday,
          p.dateTomorrow,
          p.dateNextWeek,
          p.dateNextWeek,
          p.textSecondary,
        ],
      );
    });
  });

  testWidgets('срок сегодня со временем краснеет в момент срока', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await tester.runAsync(
        () => app.tasks.add(
          content: 'Call',
          due: const Due(date: '2026-10-23', time: '09:30'),
        ),
      );
      await settle(tester);
      final p = AppPalette.of(tester.element(find.byType(TaskRow).first));
      expect(dueColor(tester, 'Call'), p.dateToday);

      device.clock.advance(const Duration(minutes: 30));
      await tester.pump(const Duration(minutes: 30));
      expect(dueColor(tester, 'Call'), p.danger);
    });
  });
}
