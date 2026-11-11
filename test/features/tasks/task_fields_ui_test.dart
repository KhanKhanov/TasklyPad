import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/domain/models.dart';
import 'package:planner/features/tasks/ui/task_dialog.dart';

import '../../app/support/pump_app.dart';
import '../support/app_commands.dart';

// Поля правой колонки панели задачи нажимаются целиком — подписью и значением
// (решение 11 и исправление «M4.10a» plans/m4). Локаль — en.
void main() {
  Future<String> openPanel(
    WidgetTester tester,
    AppCommands app, {
    Due? due,
  }) async {
    final id = (await tester.runAsync(
      () => app.tasks.add(content: 'Buy milk', due: due),
    ))!;
    await settle(tester);
    await tester.tap(find.text('Buy milk'));
    await settle(tester);
    expect(find.byType(TaskDialog), findsOneWidget);
    return id;
  }

  Finder inPanel(String text) =>
      find.descendant(of: find.byType(TaskDialog), matching: find.text(text));

  testWidgets('«Приоритет» — нажатие на подпись → меню, выбор сохраняется', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final id = await openPanel(tester, app);

      await tester.tap(inPanel('Priority'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(MenuItemButton, 'Priority 1'), findsOneWidget);

      await tester.tap(find.widgetWithText(MenuItemButton, 'Priority 1'));
      await settle(tester);
      final ws = (await tester.runAsync(app.read))!;
      expect(ws.task(id)!.priority, 1);
    });
  });

  testWidgets('«Длительность» — нажатие на подпись → меню, выбор сохраняется', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final id = await openPanel(
        tester,
        app,
        due: const Due(date: '2026-10-26', time: '09:00'),
      );

      await tester.tap(inPanel('Duration'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(MenuItemButton, '30 min'));
      await settle(tester);
      final ws = (await tester.runAsync(app.read))!;
      expect(
        ws.task(id)!.duration,
        const TaskDuration(amount: 30, unit: 'minute'),
      );
    });
  });

  testWidgets('повторное нажатие на поле с открытым меню → меню закрыто', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await openPanel(tester, app);

      await tester.tap(inPanel('Priority'));
      await tester.pumpAndSettle();
      expect(find.byType(MenuItemButton), findsWidgets);
      await tester.tap(inPanel('Priority'));
      await tester.pumpAndSettle();
      expect(find.byType(MenuItemButton), findsNothing);
    });
  });
}
