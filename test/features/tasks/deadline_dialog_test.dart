import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/domain/models.dart';
import 'package:planner/features/tasks/ui/task_dialog.dart';

import '../../app/support/pump_app.dart';
import '../support/app_commands.dart';

// Окна выбора дедлайна и срока в одной раскладке (решение 1Б «Ход M3.8»).
// Часы устройства — пт 23.10.2026 09:00, локаль — en.
void main() {
  Future<String> addTask(
    WidgetTester tester,
    AppCommands app,
    String content, {
    String? deadline,
  }) async {
    final id = (await tester.runAsync(
      () => app.tasks.add(content: content, deadline: deadline),
    ))!;
    await settle(tester);
    return id;
  }

  Future<Task> task(WidgetTester tester, AppCommands app, String id) async =>
      (await tester.runAsync(app.read))!.task(id)!;

  Future<void> openDeadline(WidgetTester tester, String content) async {
    await tester.tap(find.text(content));
    await settle(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(TaskDialog),
        matching: find.text('Deadline'),
      ),
    );
    await tester.pumpAndSettle();
  }

  final deadlineField = find.widgetWithText(TextField, 'Type a deadline');

  testWidgets('дедлайн текстом: «next friday» — подсказка с датой, Enter '
      'ставит дату', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final id = await addTask(tester, app, 'Report');
      await openDeadline(tester, 'Report');
      await tester.enterText(deadlineField, 'next friday');
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);
      expect(deadlineField, findsNothing);
      expect((await task(tester, app, id)).deadline, '2026-10-30');
    });
  });

  testWidgets('дедлайн: повторение в тексте — не дедлайн, Enter ничего не '
      'ставит', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final id = await addTask(tester, app, 'Report');
      await openDeadline(tester, 'Report');
      await tester.enterText(deadlineField, 'every day');
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);
      expect(deadlineField, findsOneWidget);
      expect((await task(tester, app, id)).deadline, isNull);
    });
  });

  testWidgets('дедлайн: быстрый вариант «Tomorrow»; «No deadline» внизу '
      'убирает', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final id = await addTask(tester, app, 'Report');
      await openDeadline(tester, 'Report');
      await tester.tap(find.text('Tomorrow').last);
      await settle(tester);
      expect((await task(tester, app, id)).deadline, '2026-10-24');

      await tester.tap(find.byTooltip('Close'));
      await settle(tester);
      await openDeadline(tester, 'Report');
      await tester.tap(
        find.descendant(
          of: find.byType(Dialog).last,
          matching: find.text('No deadline'),
        ),
      );
      await settle(tester);
      expect((await task(tester, app, id)).deadline, isNull);
    });
  });

  testWidgets('одно «сейчас» на окно: часы ушли за полночь, пока окно '
      'открыто, — «Tomorrow» от дня открытия, у срока и дедлайна', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final id = await addTask(tester, app, 'Report');
      await openDeadline(tester, 'Report');
      device.clock.advance(const Duration(days: 1));
      // Правка поля перестраивает окно.
      await tester.enterText(deadlineField, 'x');
      await tester.pump();
      await tester.tap(find.text('Tomorrow').last);
      await settle(tester);
      expect((await task(tester, app, id)).deadline, '2026-10-24');

      await tester.tap(
        find.descendant(
          of: find.byType(TaskDialog),
          matching: find.text('Date'),
        ),
      );
      await tester.pumpAndSettle();
      device.clock.advance(const Duration(days: 1));
      await tester.enterText(
        find.widgetWithText(TextField, 'Type a due date'),
        'x',
      );
      await tester.pump();
      await tester.tap(find.text('Tomorrow').last);
      await settle(tester);
      // Окно открыто 24-го (часы уже сдвинуты раз), закрыто — 25-го.
      expect((await task(tester, app, id)).due?.date, '2026-10-25');
    });
  });

  testWidgets('компьютер: календарь справа от поля и вариантов, у срока и '
      'дедлайна одинаково', (tester) async {
    await withApp(tester, (device) async {
      await addTask(tester, AppCommands(device), 'Report');
      await openDeadline(tester, 'Report');
      final field = tester.getRect(deadlineField);
      final calendar = tester.getRect(find.byType(CalendarDatePicker));
      expect(calendar.left, greaterThanOrEqualTo(field.right));
      expect(calendar.top, lessThan(field.bottom + 40));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(TaskDialog),
          matching: find.text('Date'),
        ),
      );
      await tester.pumpAndSettle();
      final due = tester.getRect(
        find.widgetWithText(TextField, 'Type a due date'),
      );
      final dueCalendar = tester.getRect(find.byType(CalendarDatePicker));
      expect(dueCalendar.left, greaterThanOrEqualTo(due.right));
      expect(find.text('Repeat'), findsOneWidget);
    });
  });

  testWidgets('телефон: календарь под вариантами', (tester) async {
    await withApp(tester, size: const Size(400, 900), (device) async {
      await addTask(tester, AppCommands(device), 'Report');
      await openDeadline(tester, 'Report');
      final field = tester.getRect(deadlineField);
      final calendar = tester.getRect(find.byType(CalendarDatePicker));
      expect(calendar.top, greaterThan(field.bottom));
    });
  });
}
