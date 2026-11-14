import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/domain/models.dart';
import 'package:planner/features/shell/ui/sidebar.dart';

import '../../app/support/pump_app.dart';
import '../support/app_commands.dart';

// Заголовок группы «Просрочено» при группировке «Сегодня» по сроку: кнопка
// «Перенести» — у правого края заголовка, как без группировки (ручная
// проверка пользователя 12.11.2026). Часы теста — 23.10.2026, локаль — en.
void main() {
  testWidgets('«Today» по сроку — «Reschedule» у правого края заголовка '
      '«Overdue»', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await tester.runAsync(
        () => app.tasks.add(
          content: 'Late',
          due: const Due(date: '2026-10-20'),
        ),
      );
      await settle(tester);
      await tester.tap(
        find.descendant(of: find.byType(Sidebar), matching: find.text('Today')),
      );
      await settle(tester);
      await tester.tap(find.textContaining('Display'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Grouping'));
      await tester.pumpAndSettle();
      // Пункт группировки, а не подменю фильтра «Date».
      await tester.tap(
        find
            .descendant(
              of: find.byType(MenuItemButton),
              matching: find.text('Date'),
            )
            .last,
      );
      await settle(tester);

      final header = find
          .ancestor(of: find.text('Overdue'), matching: find.byType(Container))
          .first;
      final button = find.widgetWithText(TextButton, 'Reschedule');
      // Правый край кнопки — у правого края заголовка (в пределах отступа).
      expect(
        tester.getTopRight(header).dx - tester.getTopRight(button).dx,
        lessThan(16),
      );
    });
  });
}
