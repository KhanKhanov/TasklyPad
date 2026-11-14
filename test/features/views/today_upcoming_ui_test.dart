import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:planner/domain/models.dart';
import 'package:planner/domain/view_options.dart';
import 'package:planner/features/shell/ui/sidebar.dart';
import 'package:planner/features/shell/ui/sidebar_items.dart';
import 'package:planner/features/tasks/ui/add_task_editor.dart';
import 'package:planner/features/tasks/ui/task_row.dart';
import 'package:planner/features/views/ui/today_screen.dart';
import 'package:planner/features/views/ui/upcoming_screen.dart';
import 'package:planner/features/views/ui/week_strip.dart';

import '../../app/support/pump_app.dart';
import '../support/app_commands.dart';
import '../support/view_options_finders.dart';

// «Сегодня» и «Предстоящее» (план M4.6). Часы теста — пятница 23.10.2026,
// неделя полосы — 19–25 октября. Локаль — en.
void main() {
  Finder row(String content) =>
      find.ancestor(of: find.text(content), matching: find.byType(TaskRow));

  Finder inSidebar(String text) =>
      find.descendant(of: find.byType(Sidebar), matching: find.text(text));

  Future<void> add(
    WidgetTester tester,
    AppCommands app,
    String content, {
    String? date,
  }) async {
    await tester.runAsync(
      () => app.tasks.add(
        content: content,
        due: date == null ? null : Due(date: date),
      ),
    );
    await settle(tester);
  }

  Future<void> typeTask(WidgetTester tester, String content) async {
    await tester.enterText(
      find.widgetWithText(TextField, 'Task name'),
      content,
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
  }

  Future<Task> taskNamed(
    WidgetTester tester,
    AppCommands app,
    String name,
  ) async =>
      (await tester.runAsync(app.read))!
          .children(null)
          .firstWhere((t) => t.content == name);

  testWidgets('«Today»: счётчик в сайдбаре — сегодня и просрочено; '
      '«Overdue» сверху, задачи других дней не видны; «Add task» ставит '
      'срок сегодня', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await add(tester, app, 'Late', date: '2026-10-20');
      await add(tester, app, 'Now', date: '2026-10-23');
      await add(tester, app, 'Soon', date: '2026-10-24');
      await add(tester, app, 'Someday');

      expect(
        find.descendant(
          of: find.ancestor(
            of: inSidebar('Today'),
            matching: find.byType(SidebarNavItem),
          ),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
      await tester.tap(inSidebar('Today'));
      await settle(tester);
      expect(find.byType(TodayScreen), findsOneWidget);
      expect(find.text('Overdue'), findsOneWidget);
      expect(find.text('Reschedule'), findsOneWidget);
      expect(row('Late'), findsOneWidget);
      expect(row('Now'), findsOneWidget);
      expect(row('Soon'), findsNothing);
      expect(row('Someday'), findsNothing);
      expect(
        tester.getTopLeft(row('Late')).dy,
        lessThan(tester.getTopLeft(row('Now')).dy),
      );

      await tester.tap(
        find.descendant(
          of: find.byType(AddTaskButton),
          matching: find.text('Add task'),
        ),
      );
      await tester.pumpAndSettle();
      await typeTask(tester, 'Call');
      expect(
        (await taskNamed(tester, app, 'Call')).due,
        const Due(date: '2026-10-23'),
      );
      expect(row('Call'), findsOneWidget);

      // Быстрое добавление из «Сегодня» — тоже со сроком сегодня.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyQ);
      await tester.pumpAndSettle();
      await typeTask(tester, 'Quick');
      expect(
        (await taskNamed(tester, app, 'Quick')).due,
        const Due(date: '2026-10-23'),
      );
    });
  });

  testWidgets('«Reschedule» переносит все просроченные на выбранный день, '
      '«Undo» возвращает', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await add(tester, app, 'One', date: '2026-10-20');
      await add(tester, app, 'Two', date: '2026-10-21');
      await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
      await settle(tester);
      expect(find.byType(TodayScreen), findsOneWidget);

      await tester.tap(find.text('Reschedule'));
      await tester.pumpAndSettle();
      // Только дата: «Repeat» нет — у каждой задачи своё правило и время.
      expect(find.byTooltip('Repeat'), findsNothing);
      await tester.tap(find.text('Tomorrow').last);
      await settle(tester);
      for (final name in ['One', 'Two']) {
        expect(
          (await taskNamed(tester, app, name)).due,
          const Due(date: '2026-10-24'),
        );
      }
      expect(find.text('Overdue'), findsNothing);
      expect(find.text('Due date changed'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await settle(tester);
      expect(
        (await taskNamed(tester, app, 'One')).due,
        const Due(date: '2026-10-20'),
      );
      expect(find.text('Overdue'), findsOneWidget);
    });
  });

  testWidgets('«Display» «Today»: умолчание «Smart», «Manual» — отдельный '
      'выбор и «Display: 1»; у «Upcoming» группировки нет', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await settle(tester);
      expect(find.byType(TodayScreen), findsOneWidget);

      await tester.tap(find.text('Display'));
      await tester.pumpAndSettle();
      expect(find.text('Grouping'), findsOneWidget);
      expect(find.text('Smart'), findsOneWidget);
      await tester.tap(find.text('Sorting'));
      await tester.pumpAndSettle();
      expect(find.text('Smart'), findsNWidgets(2));
      await tester.tap(find.text('Manual'));
      await settle(tester);
      expect(badge('1'), findsOneWidget);
      final view = (await tester.runAsync(
        () => app.viewsRepo.load(ViewType.today),
      ))!;
      expect(view.sorting, Sorting.manual);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await settle(tester);
      expect(find.byType(UpcomingScreen), findsOneWidget);
      await tester.tap(find.text('Display'));
      await tester.pumpAndSettle();
      expect(find.text('Grouping'), findsNothing);
      expect(find.text('Sorting'), findsOneWidget);
    });
  });

  testWidgets('«Upcoming»: дни подряд, пустые тоже; «Add task» под днём '
      'ставит его дату; стрелка — следующая неделя, быстрое добавление — '
      'выбранный день, «Today» — обратно', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await add(tester, app, 'Trip', date: '2026-10-25');
      await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyU);
      await settle(tester);
      expect(find.byType(UpcomingScreen), findsOneWidget);
      expect(find.text('Oct 23 · Today · Friday'), findsOneWidget);
      expect(find.text('Oct 24 · Tomorrow · Saturday'), findsOneWidget);
      expect(find.text('Oct 25 · Sunday'), findsOneWidget);
      expect(row('Trip'), findsOneWidget);

      // Кнопки дней: сегодня, завтра — вторая.
      await tester.tap(
        find.descendant(
          of: find.byType(AddTaskButton).at(1),
          matching: find.text('Add task'),
        ),
      );
      await tester.pumpAndSettle();
      await typeTask(tester, 'Pack');
      expect(
        (await taskNamed(tester, app, 'Pack')).due,
        const Due(date: '2026-10-24'),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Next week'));
      await settle(tester);
      // Выбранный понедельник — первым под полосой недели.
      final stripBottom = tester.getBottomLeft(find.byType(WeekStrip)).dy;
      final monday = tester.getTopLeft(find.text('Oct 26 · Monday')).dy;
      expect(monday, inInclusiveRange(stripBottom, stripBottom + 30));
      await tester.sendKeyEvent(LogicalKeyboardKey.keyQ);
      await tester.pumpAndSettle();
      await typeTask(tester, 'Plan');
      expect(
        (await taskNamed(tester, app, 'Plan')).due,
        const Due(date: '2026-10-26'),
      );

      await tester.tap(find.text('Today').last);
      await settle(tester);
      expect(find.text('Oct 23 · Today · Friday'), findsOneWidget);
    });
  });

  testWidgets('«Today» с группировкой: «Add task» группы P1 — P1 и срок '
      'сегодня; по сроку «Reschedule» — в заголовке «Overdue», по приоритету '
      'её нет', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await add(tester, app, 'Late', date: '2026-10-20');
      await tester.runAsync(
        () => app.tasks.add(
          content: 'Urgent',
          priority: 1,
          due: const Due(date: '2026-10-23'),
        ),
      );
      await settle(tester);
      await tester.tap(inSidebar('Today'));
      await settle(tester);

      Future<void> group(String by) async {
        await tester.tap(find.textContaining('Display'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Grouping'));
        await tester.pumpAndSettle();
        // Пункт группировки, а не подменю фильтра с тем же текстом.
        await tester.tap(
          find
              .descendant(
                of: find.byType(MenuItemButton),
                matching: find.text(by),
              )
              .last,
        );
        await settle(tester);
      }

      await group('Priority');
      expect(find.text('Priority 1'), findsOneWidget);
      expect(find.text('Reschedule'), findsNothing);
      await tester.tap(
        find.descendant(
          of: find.byType(AddTaskButton).first,
          matching: find.text('Add task'),
        ),
      );
      await tester.pumpAndSettle();
      await typeTask(tester, 'Bank');
      final bank = await taskNamed(tester, app, 'Bank');
      expect((bank.priority, bank.due), (1, const Due(date: '2026-10-23')));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      await group('Date');
      expect(find.text('Overdue'), findsOneWidget);
      await tester.tap(find.text('Reschedule'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tomorrow').last);
      await settle(tester);
      expect(
        (await taskNamed(tester, app, 'Late')).due,
        const Due(date: '2026-10-24'),
      );
    });
  });

  testWidgets('«Upcoming»: прокрутка списка выбирает верхний день — он в '
      'полосе и у быстрого добавления', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyU);
      await settle(tester);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1200));
      await settle(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyQ);
      await tester.pumpAndSettle();
      await typeTask(tester, 'Scrolled');
      // Выбранный день — тот, чей блок под верхним краем списка: его
      // заголовок у края или уже над ним, заголовок следующего дня — ниже.
      final due = (await taskNamed(tester, app, 'Scrolled')).due!.date;
      expect(due.compareTo('2026-10-24') > 0, isTrue, reason: due);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      Finder header(DateTime day) =>
          find.textContaining('${DateFormat.MMMd('en').format(day)} · ');
      final day = DateTime.parse(due);
      final listTop = tester.getBottomLeft(find.byType(WeekStrip)).dy;
      expect(tester.getTopLeft(header(day)).dy, lessThanOrEqualTo(listTop + 1));
      expect(
        tester
            .getTopLeft(header(DateTime(day.year, day.month, day.day + 1)))
            .dy,
        greaterThan(listTop),
      );
    });
  });

  testWidgets('«Upcoming»: длинное название в редакторе дня не сбивает '
      'выбранный день; в полночь список встаёт на новый сегодняшний день', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyU);
      await settle(tester);
      // «Add task» дня 25.10 — третья кнопка.
      await tester.tap(
        find.descendant(
          of: find.byType(AddTaskButton).at(2),
          matching: find.text('Add task'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Task name'),
        'Long ' * 60,
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Long ' * 60), '');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyQ);
      await tester.pumpAndSettle();
      await typeTask(tester, 'Picked');
      expect(
        (await taskNamed(tester, app, 'Picked')).due,
        const Due(date: '2026-10-25'),
      );

      await tester.tap(find.byTooltip('Next week'));
      await settle(tester);
      device.advance(const Duration(days: 1));
      await tester.pump(const Duration(days: 1));
      await settle(tester);
      final listTop = tester.getBottomLeft(find.byType(WeekStrip)).dy;
      expect(
        tester.getTopLeft(find.text('Oct 24 · Today · Saturday')).dy,
        inInclusiveRange(listTop, listTop + 30),
      );
    });
  });

  testWidgets('«Completed tasks»: в «Today» — выполненное сегодня внизу, в '
      '«Upcoming» — внизу дня своего срока', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await add(tester, app, 'Open', date: '2026-10-23');
      await add(tester, app, 'Early', date: '2026-10-26');
      await add(tester, app, 'Later', date: '2026-10-26');
      final early = await taskNamed(tester, app, 'Early');
      await tester.runAsync(() => app.tasks.complete(early.id));
      await settle(tester);

      Future<void> showCompleted() async {
        await tester.tap(find.text('Display'));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(CheckboxMenuButton));
        await settle(tester);
      }

      await tester.tap(inSidebar('Today'));
      await settle(tester);
      expect(row('Early'), findsNothing);
      await showCompleted();
      expect(
        tester.getTopLeft(row('Early')).dy,
        greaterThan(tester.getTopLeft(row('Open')).dy),
      );

      // Группы по сроку: у дня 26.10 (там только выполненная) «Add task» нет
      // — задача с его сроком ушла бы из «Today».
      await tester.tap(find.text('Display'));
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
      expect(find.text('Oct 26 · Monday'), findsOneWidget);
      expect(find.byType(AddTaskButton), findsOneWidget);

      await tester.tap(inSidebar('Upcoming'));
      await settle(tester);
      expect(row('Early'), findsNothing);
      await showCompleted();
      final header = tester.getTopLeft(find.text('Oct 26 · Monday')).dy;
      expect(tester.getTopLeft(row('Early')).dy, greaterThan(header));
      expect(
        tester.getTopLeft(row('Early')).dy,
        greaterThan(tester.getTopLeft(row('Later')).dy),
      );
    });
  });
}
