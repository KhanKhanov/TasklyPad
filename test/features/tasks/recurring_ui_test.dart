import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/data/projection/entity_fields.dart';
import 'package:planner/domain/models.dart';
import 'package:planner/features/tasks/ui/task_dialog.dart';
import 'package:planner/features/tasks/ui/task_dialog_top_bar.dart';
import 'package:planner/features/tasks/ui/task_row.dart';

import '../../app/support/pump_app.dart';
import '../../sync/support/devices.dart';
import '../support/app_commands.dart';

// Повторяющиеся задачи в интерфейсе (шаг M3.7). Часы устройства — пт
// 23.10.2026 09:00, локаль — en.
void main() {
  RecurrenceRule rule(String line) =>
      RecurrenceRule(rrule: [line], fromCompletion: false);

  const daily = Due(
    date: '2026-10-23',
    string: 'every day',
    lang: 'en',
    rule: RecurrenceRule(rrule: ['FREQ=DAILY'], fromCompletion: false),
  );

  Future<String> addTask(
    WidgetTester tester,
    AppCommands app,
    String content, {
    Due? due,
    String? parentId,
    String? deadline,
  }) async {
    final id = (await tester.runAsync(
      () => app.tasks.add(
        content: content,
        due: due,
        parentId: parentId,
        deadline: deadline,
      ),
    ))!;
    await settle(tester);
    return id;
  }

  Future<Task> task(WidgetTester tester, AppCommands app, String id) async =>
      (await tester.runAsync(app.read))!.task(id)!;

  Finder row(String content) =>
      find.ancestor(of: find.text(content), matching: find.byType(TaskRow));

  /// `t` на строке — планировщик срока.
  Future<void> openScheduler(WidgetTester tester, String content) async {
    tester
        .widget<Focus>(
          find.descendant(of: row(content), matching: find.byType(Focus)).first,
        )
        .focusNode!
        .requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
    await settle(tester);
  }

  Future<void> openRepeat(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('планировщик: текст в поле «Type a due date» задаёт правило — '
      'срок с первого вхождения, значок у срока в строке', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final id = await addTask(tester, app, 'Gym');
      await openScheduler(tester, 'Gym');
      await tester.enterText(
        find.widgetWithText(TextField, 'Type a due date'),
        'every mon',
      );
      await tester.pump();
      expect(find.text('every mon'), findsWidgets); // предпросмотр правила
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);

      final due = (await task(tester, app, id)).due!;
      expect(
        (due.date, due.rule),
        ('2026-10-26', rule('FREQ=WEEKLY;BYDAY=MO')),
      );
      expect(
        find.descendant(of: row('Gym'), matching: find.byIcon(Icons.repeat)),
        findsOneWidget,
      );
    });
  });

  testWidgets('«Repeat → Daily» без срока — с сегодня, текст правила в '
      'панели', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final id = await addTask(tester, app, 'Water plants');
      await openScheduler(tester, 'Water plants');
      await openRepeat(tester, 'Repeat');
      await tester.tap(find.text('Daily'));
      await settle(tester);

      final due = (await task(tester, app, id)).due!;
      expect(
        (due.date, due.string, due.rule),
        ('2026-10-23', 'every day', rule('FREQ=DAILY')),
      );
      await tester.tap(find.text('Water plants'));
      await settle(tester);
      expect(
        find.descendant(
          of: find.byType(TaskDialog),
          matching: find.text('every day'),
        ),
        findsOneWidget,
      );
    });
  });

  testWidgets('быстрый вариант даты переносит вхождение и сохраняет правило; '
      'значок «Remove recurrence» снимает правило, дата остаётся', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final id = await addTask(tester, app, 'Gym', due: daily);
      await openScheduler(tester, 'Gym');
      await tester.tap(find.text('Tomorrow'));
      await settle(tester);
      var due = (await task(tester, app, id)).due!;
      expect((due.date, due.rule), ('2026-10-24', daily.rule));

      await openScheduler(tester, 'Gym');
      await tester.tap(find.byTooltip('Remove recurrence'));
      await settle(tester);
      due = (await task(tester, app, id)).due!;
      expect((due.date, due.rule, due.string), ('2026-10-24', null, null));
    });
  });

  testWidgets('правило без текста (пришло с другого устройства) — подпись '
      '«Repeat», но снять его можно', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final id = await addTask(
        tester,
        app,
        'Board',
        due: Due(
          date: '2026-10-26',
          rule: rule('FREQ=MONTHLY;INTERVAL=2;BYDAY=4MO'),
        ),
      );
      await openScheduler(tester, 'Board');
      expect(find.text('Repeat'), findsOneWidget);
      await tester.tap(find.byTooltip('Remove recurrence'));
      await settle(tester);
      final due = (await task(tester, app, id)).due!;
      expect((due.date, due.rule), ('2026-10-26', null));
    });
  });

  testWidgets('«Postpone» — на следующее вхождение без записи о выполнении, с '
      '«Undo»; у закончившейся серии пункта нет', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final id = await addTask(tester, app, 'Gym', due: daily);
      await addTask(
        tester,
        app,
        'Ended',
        due: daily.copyWith(
          rule: rule('FREQ=DAILY;UNTIL=20261023'),
          string: 'every day until oct 23 2026',
        ),
      );
      await openScheduler(tester, 'Ended');
      expect(find.text('Postpone'), findsNothing);
      await tester.tapAt(Offset.zero); // закрыть окно
      await settle(tester);

      await openScheduler(tester, 'Gym');
      // У пункта — день, на который перенесёт команда (сб 24.10).
      expect(
        find.descendant(
          of: find.widgetWithText(ListTile, 'Postpone'),
          matching: find.text('Sat'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Postpone'));
      await settle(tester);
      expect((await task(tester, app, id)).due!.date, '2026-10-24');
      final rows = (await tester.runAsync(
        () => device.db.select(device.db.completions).get(),
      ))!;
      expect(rows, isEmpty);
      await tester.tap(find.text('Undo'));
      await settle(tester);
      expect((await task(tester, app, id)).due!.date, '2026-10-23');
    });
  });

  testWidgets('календарь: выбор года — переход, окно открыто и срок прежний; '
      'срок вне диапазона календаря окно не ломает', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final id = await addTask(tester, app, 'Gym', due: daily);
      await addTask(tester, app, 'Old', due: const Due(date: '2015-05-01'));
      await openScheduler(tester, 'Gym');
      await tester.tap(find.text('October 2026'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2027'));
      await settle(tester);
      expect(find.widgetWithText(TextField, 'Type a due date'), findsOneWidget);
      expect((await task(tester, app, id)).due, daily);
      // День в показанном месяце — уже новый срок.
      await tester.tap(find.text('15'));
      await settle(tester);
      expect((await task(tester, app, id)).due!.date, '2027-10-15');

      await openScheduler(tester, 'Old');
      expect(find.text('May 2015'), findsOneWidget);
    });
  });

  testWidgets('«Custom…»: окончание раньше начала — так и сказано; пустое '
      '«Every» — сохранять нечего', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await addTask(
        tester,
        app,
        'Report',
        due: Due(
          date: '2026-10-30',
          string: 'every fri until oct 23 2026',
          lang: 'en',
          rule: rule('FREQ=WEEKLY;BYDAY=FR;UNTIL=20261023'),
        ),
      );
      await openScheduler(tester, 'Report');
      await openRepeat(tester, 'every fri until oct 23 2026');
      await tester.tap(find.text('Custom…'));
      await tester.pumpAndSettle();
      expect(find.text('Ends before it starts'), findsOneWidget);
      await tester.tap(find.text('Never'));
      await tester.pump();
      expect(find.text('every fri'), findsWidgets);
      await tester.enterText(find.byType(TextField).last, '');
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
            .onPressed,
        isNull,
      );
      expect(find.text("This recurrence isn't supported"), findsNothing);
    });
  });

  testWidgets('«Custom…»: дни недели — правило с ними, срок — ближайший из '
      'дней; правило без текста не сохраняется', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final id = await addTask(tester, app, 'Report');
      await openScheduler(tester, 'Report');
      await openRepeat(tester, 'Repeat');
      await tester.tap(find.text('Custom…'));
      await tester.pumpAndSettle();
      // По умолчанию отмечен день сегодняшней даты (пт).
      await tester.tap(find.widgetWithText(FilterChip, 'Mon'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilterChip, 'Fri'));
      await tester.pump();
      expect(find.text('every mon'), findsOneWidget);
      await tester.tap(find.text('Save'));
      await settle(tester);
      final due = (await task(tester, app, id)).due!;
      expect(
        (due.date, due.rule),
        ('2026-10-26', rule('FREQ=WEEKLY;BYDAY=MO')),
      );

      await openScheduler(tester, 'Report');
      await openRepeat(tester, 'every mon');
      await tester.tap(find.text('Custom…'));
      await tester.pumpAndSettle();
      // Окно открылось правилом задачи: неделя, пн. Каждые 2 месяца в 4-й пн
      // (26.10 — четвёртый понедельник) текстом не записать.
      await tester.enterText(find.byType(TextField).last, '2');
      await tester.pump();
      await tester.tap(find.text('weeks'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('months').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('every 4th mon'));
      await tester.pump();
      expect(find.text("This recurrence isn't supported"), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
            .onPressed,
        isNull,
      );
    });
  });

  testWidgets('меню «⋯» окна задачи: у повторяющейся с подзадачами — «Complete '
      'forever» и «Complete & reset sub-tasks»; у обычной их нет', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final id = await addTask(tester, app, 'Weekly review', due: daily);
      final sub = await addTask(tester, app, 'Inbox zero', parentId: id);
      await tester.runAsync(() => app.tasks.complete(sub));
      // Между записями в базу через runAsync — кадр: иначе вторая ждёт
      // блокировку drift, которую держит поток первой (ловушка M3.6).
      await settle(tester);
      await addTask(tester, app, 'Plain');
      await addTask(tester, app, 'Gym', due: daily);

      Future<void> openMenu(String content) async {
        await tester.tap(find.text(content));
        await settle(tester);
        await tester.tap(
          find.descendant(
            of: find.byType(TaskDialogTopBar),
            matching: find.byTooltip('More actions'),
          ),
        );
        await tester.pumpAndSettle();
      }

      Future<void> closeMenu() async {
        await tester.tapAt(Offset.zero);
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Close'));
        await settle(tester);
      }

      await openMenu('Plain');
      expect(find.text('Complete forever'), findsNothing);
      await closeMenu();
      // Повторяющаяся без подзадач — сбрасывать нечего.
      await openMenu('Gym');
      expect(find.text('Complete'), findsOneWidget);
      expect(find.text('Complete forever'), findsOneWidget);
      expect(find.text('Complete & reset sub-tasks'), findsNothing);
      await closeMenu();

      await tester.tap(find.text('Weekly review'));
      await settle(tester);
      Future<void> menu() async {
        await tester.tap(
          find.descendant(
            of: find.byType(TaskDialogTopBar),
            matching: find.byTooltip('More actions'),
          ),
        );
        await tester.pumpAndSettle();
      }

      await menu();
      await tester.tap(find.text('Complete & reset sub-tasks'));
      await settle(tester);
      expect((await task(tester, app, id)).due!.date, '2026-10-24');
      expect((await task(tester, app, sub)).isCompleted, isFalse);

      // «Complete» — вхождение, как кружок: срок дальше, задача в работе.
      await menu();
      await tester.tap(find.text('Complete'));
      await settle(tester);
      final next = await task(tester, app, id);
      expect((next.isCompleted, next.due!.date), (false, '2026-10-25'));

      await menu();
      await tester.tap(find.text('Complete forever'));
      await settle(tester);
      final done = await task(tester, app, id);
      expect((done.isCompleted, done.due!.rule), (true, daily.rule));
      expect((await task(tester, app, sub)).isCompleted, isTrue);
    });
  });

  testWidgets('дедлайн повторяющейся задачи после его даты не виден ни в '
      'строке, ни в окне задачи; у обычной — виден', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await addTask(tester, app, 'Gym', due: daily, deadline: '2026-10-20');
      await addTask(tester, app, 'Plain', deadline: '2026-10-20');
      Finder flag(String content) => find.descendant(
        of: row(content),
        matching: find.byIcon(Icons.outlined_flag),
      );
      expect(flag('Gym'), findsNothing);
      expect(flag('Plain'), findsOneWidget);
      Finder noDeadline() => find.descendant(
        of: find.byType(TaskDialog),
        matching: find.text('No deadline'),
      );
      await tester.tap(find.text('Gym'));
      await settle(tester);
      expect(noDeadline(), findsOneWidget);
      await tester.tap(find.byTooltip('Close'));
      await settle(tester);
      await tester.tap(find.text('Plain'));
      await settle(tester);
      expect(noDeadline(), findsNothing);
    });
  });

  Future<bool> savedReset(WidgetTester tester, TestDevice device) async =>
      (await tester.runAsync(
        AppCommands(device).settings.resetRecurringSubtasks,
      ))!;

  Future<Finder> openAdvanced(WidgetTester tester) async {
    await tester.sendKeyEvent(LogicalKeyboardKey.keyO);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await settle(tester);
    expect(find.text('Advanced'), findsOneWidget);
    return find.widgetWithText(SwitchListTile, 'Reset sub-tasks');
  }

  testWidgets('компьютер: «General → Advanced → Reset sub-tasks» сохраняет '
      '«Update», одной op только этого поля', (tester) async {
    await withApp(tester, (device) async {
      final reset = await openAdvanced(tester);
      expect(tester.widget<SwitchListTile>(reset).value, isFalse);
      await tester.tap(reset);
      await tester.pump();
      expect(await savedReset(tester, device), isFalse);
      await tester.tap(find.text('Update').first);
      await settle(tester);
      expect(await savedReset(tester, device), isTrue);
      final ops = (await tester.runAsync(device.ownOps))!;
      expect(
        ops.where((op) => op.field == SettingsFields.resetRecurringSubtasks),
        hasLength(1),
      );
      expect(
        ops.where((op) => op.field == SettingsFields.smartDateRecognition),
        isEmpty,
      );
    });
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('Android: «Reset sub-tasks» сохраняет сразу', (tester) async {
    await withApp(tester, (device) async {
      final reset = await openAdvanced(tester);
      await tester.tap(reset);
      await settle(tester);
      expect(await savedReset(tester, device), isTrue);
    });
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
