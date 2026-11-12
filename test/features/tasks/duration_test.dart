import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/domain/models.dart';
import 'package:planner/domain/rules.dart';
import 'package:planner/features/tasks/logic/duration_text.dart';
import 'package:planner/features/tasks/ui/task_dialog.dart';

import '../../app/support/pump_app.dart';
import '../../sync/support/devices.dart';
import '../support/app_commands.dart';

// Длительность задачи (help «Set a task duration», О-47; решения 13А и 1А
// «Часть M4.11» plans/m4). Локаль виджет-тестов — en.
Matcher _rejected(RejectReason reason) =>
    throwsA(isA<CommandRejected>().having((e) => e.reason, 'reason', reason));

const _minutes = TaskDuration(amount: 0, unit: 'minute');

void main() {
  group('разбор своего значения', () {
    const cases = <String, int?>{
      '90': 90,
      '5': 5,
      '1:30': 90,
      '0:45': 45,
      '1h30m': 90,
      '1h 30m': 90,
      '2h': 120,
      '3 h': 180,
      '45m': 45,
      '45 min': 45,
      '1 h 30 min': 90,
      '1ч 30м': 90,
      '1ч30мин': 90,
      '2 ч': 120,
      '45 мин': 45,
      '1 ч 30 мин': 90,
      '': null,
      'час': null,
      '1:75': null,
      'abc': null,
      '1.5h': null,
    };
    for (final MapEntry(key: text, value: minutes) in cases.entries) {
      test('«$text» → $minutes', () {
        expect(parseDurationMinutes(text), minutes);
      });
    }
  });

  group('команды', () {
    late TestDevice device;
    late AppCommands app;

    setUp(() async {
      device = await TestDevice.start();
      app = AppCommands(device);
    });

    test('от 1 минуты до 24 часов; больше суток и ноль — отказ без '
        'записи', () async {
      final id = await app.tasks.add(content: 'Задача');
      await app.tasks.setDuration(id, _minutes.copyWith(amount: 1440));
      expect((await app.read()).task(id)!.duration!.amount, 1440);

      final before = (await device.ownOps()).length;
      await expectLater(
        app.tasks.setDuration(id, _minutes.copyWith(amount: 1441)),
        _rejected(RejectReason.badDuration),
      );
      await expectLater(
        app.tasks.setDuration(id, _minutes),
        _rejected(RejectReason.badDuration),
      );
      await expectLater(
        app.tasks.add(
          content: 'Длинная',
          duration: const TaskDuration(amount: 2, unit: 'day'),
        ),
        _rejected(RejectReason.badDuration),
      );
      expect((await device.ownOps()).length, before);
    });

    test('удаление срока длительность не убирает (help)', () async {
      final id = await app.tasks.add(
        content: 'Задача',
        due: const Due(date: '2026-11-12', time: '09:00'),
        duration: _minutes.copyWith(amount: 30),
      );
      await app.tasks.setDue(id, null);
      expect((await app.read()).task(id)!.duration!.amount, 30);
    });
  });

  group('поле панели', () {
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
      return id;
    }

    Finder inPanel(String text) =>
        find.descendant(of: find.byType(TaskDialog), matching: find.text(text));

    Future<TaskDuration?> durationOf(
      WidgetTester tester,
      AppCommands app,
      String id,
    ) async => (await tester.runAsync(app.read))!.task(id)!.duration;

    Future<void> custom(WidgetTester tester, String text) async {
      await tester.tap(inPanel('Duration'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(MenuItemButton, 'Custom duration…'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        text,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await settle(tester);
    }

    testWidgets('видно и без срока; своё значение 5 мин и 3 ч', (tester) async {
      await withApp(tester, (device) async {
        final app = AppCommands(device);
        final id = await openPanel(tester, app);
        expect(inPanel('Duration'), findsOneWidget);

        await custom(tester, '5');
        expect((await durationOf(tester, app, id))!.amount, 5);
        expect(inPanel('5 min'), findsOneWidget);

        await custom(tester, '3h');
        expect((await durationOf(tester, app, id))!.amount, 180);
        expect(inPanel('3 h'), findsOneWidget);
      });
    });

    testWidgets('больше 24 ч — ошибка в окне, ничего не записано', (
      tester,
    ) async {
      await withApp(tester, (device) async {
        final app = AppCommands(device);
        final id = await openPanel(tester, app);
        await custom(tester, '25h');
        expect(
          find.text('Duration must be between 1 minute and 24 hours'),
          findsOneWidget,
        );
        expect(await durationOf(tester, app, id), isNull);
        await tester.tap(find.text('Cancel'));
        await settle(tester);
      });
    });

    testWidgets('крестик рядом со значением убирает длительность', (
      tester,
    ) async {
      await withApp(tester, (device) async {
        final app = AppCommands(device);
        final id = await openPanel(tester, app);
        await tester.runAsync(
          () => app.tasks.setDuration(id, _minutes.copyWith(amount: 90)),
        );
        await settle(tester);
        expect(inPanel('1 h 30 min'), findsOneWidget);

        await tester.tap(
          find.descendant(
            of: find.byType(TaskDialog),
            matching: find.byTooltip('Remove duration'),
          ),
        );
        await settle(tester);
        expect(await durationOf(tester, app, id), isNull);
        expect(inPanel('No duration'), findsOneWidget);
      });
    });

    testWidgets('планировщик → «Время» → длительность «1h 30m» → «Save»: '
        'длительность записана, срок прежний', (tester) async {
      await withApp(tester, (device) async {
        final app = AppCommands(device);
        const due = Due(date: '2026-10-26', time: '09:00');
        final id = await openPanel(tester, app, due: due);
        await tester.tap(inPanel('Date'));
        await settle(tester);
        await tester.tap(find.text('09:00'));
        await tester.pumpAndSettle();
        expect(find.text('Time'), findsWidgets);

        await tester.enterText(
          find.widgetWithText(TextField, 'Duration'),
          '1h 30m',
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Save'));
        await settle(tester);

        final task = (await tester.runAsync(app.read))!.task(id)!;
        expect(task.duration, _minutes.copyWith(amount: 90));
        expect(task.due, due);
      });
    });
  });
}
