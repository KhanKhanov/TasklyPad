import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/domain/models.dart';
import 'package:planner/features/tasks/ui/task_dialog.dart';
import 'package:planner/features/tasks/ui/task_row.dart';
import 'package:planner/features/tasks/ui/task_row_menu.dart';

import '../../app/support/pump_app.dart';
import '../support/app_commands.dart';

// Меню строки задачи — «⋯», `.` и правый клик (О-48, решение 12А плана M4,
// решения 1А и 2А «Ход M4.7»). Локаль — en; сегодня — пятница 23.10.2026.
void main() {
  Future<String> addTask(
    WidgetTester tester,
    AppCommands app,
    String content, {
    Due? due,
  }) async {
    final id = (await tester.runAsync(
      () => app.tasks.add(content: content, due: due),
    ))!;
    await settle(tester);
    return id;
  }

  Future<Task> load(WidgetTester tester, AppCommands app, String id) async =>
      (await tester.runAsync(app.repo.load))!.task(id)!;

  Finder row(String content) =>
      find.ancestor(of: find.text(content), matching: find.byType(TaskRow));

  /// Фокус на строку и `.` — «More task actions» (help «Use keyboard
  /// shortcuts»).
  Future<void> openByKey(WidgetTester tester, String content) async {
    tester
        .widget<Focus>(
          find.descendant(of: row(content), matching: find.byType(Focus)).first,
        )
        .focusNode!
        .requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.period);
    await tester.pumpAndSettle();
  }

  Future<void> pick(WidgetTester tester, Finder item) async {
    await tester.tap(item);
    await settle(tester);
  }

  bool menuVisible(WidgetTester tester, String content) => tester
      .widget<Visibility>(
        find.ancestor(
          of: find.descendant(
            of: row(content),
            matching: find.byType(TaskRowMenuButton),
          ),
          matching: find.byType(Visibility),
        ),
      )
      .visible;

  testWidgets('`.` на строке в фокусе → меню с пунктами О-48', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await addTask(tester, app, 'Milk');
      await openByKey(tester, 'Milk');

      for (final text in [
        'Edit',
        'Date',
        'Priority',
        'Move to…',
        'Labels',
        'Duplicate',
        'Delete',
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
      for (final tooltip in [
        'Today',
        'Tomorrow',
        'This weekend',
        'Next week',
        'No date',
        'Pick a date',
        'Priority 1',
        'Priority 4',
      ]) {
        expect(find.byTooltip(tooltip), findsOneWidget, reason: tooltip);
      }
    });
  });

  testWidgets('«Tomorrow» → срок завтра и тост; «Undo» возвращает', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final id = await addTask(tester, app, 'Milk');
      await openByKey(tester, 'Milk');
      await pick(tester, find.byTooltip('Tomorrow'));
      expect((await load(tester, app, id)).due?.date, '2026-10-24');
      expect(find.text('Due date changed'), findsOneWidget);

      await pick(tester, find.text('Undo'));
      expect((await load(tester, app, id)).due, isNull);
    });
  });

  testWidgets('«Next week» у повторяющейся со временем → только вхождение: '
      'время и правило остаются', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      const rule = RecurrenceRule(rrule: ['FREQ=DAILY'], fromCompletion: false);
      final id = await addTask(
        tester,
        app,
        'Run',
        due: const Due(
          date: '2026-10-23',
          time: '07:30',
          string: 'every day at 7:30',
          rule: rule,
        ),
      );
      await openByKey(tester, 'Run');
      await pick(tester, find.byTooltip('Next week'));
      final due = (await load(tester, app, id)).due!;
      expect(due.date, '2026-10-26');
      expect(due.time, '07:30');
      expect(due.rule, rule);
    });
  });

  testWidgets('«No date» → срок снят', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final id = await addTask(
        tester,
        app,
        'Milk',
        due: const Due(date: '2026-10-23'),
      );
      await openByKey(tester, 'Milk');
      await pick(tester, find.byTooltip('No date'));
      expect((await load(tester, app, id)).due, isNull);
    });
  });

  testWidgets('«Pick a date» → планировщик', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await addTask(tester, app, 'Milk');
      await openByKey(tester, 'Milk');
      await pick(tester, find.byTooltip('Pick a date'));
      expect(find.widgetWithText(TextField, 'Type a due date'), findsOneWidget);
    });
  });

  testWidgets('приоритет: текущий отмечен, «Priority 1» → P1', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final id = await addTask(tester, app, 'Milk');
      await openByKey(tester, 'Milk');
      bool selected(String tooltip) => tester
          .widget<IconButton>(
            find.ancestor(
              of: find.byTooltip(tooltip),
              matching: find.byType(IconButton),
            ),
          )
          .isSelected!;
      expect(selected('Priority 4'), isTrue);
      expect(selected('Priority 1'), isFalse);

      await pick(tester, find.byTooltip('Priority 1'));
      expect((await load(tester, app, id)).priority, 1);
    });
  });

  testWidgets('«Edit» → панель задачи', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await addTask(tester, app, 'Milk');
      await openByKey(tester, 'Milk');
      await pick(tester, find.text('Edit'));
      expect(find.byType(TaskDialog), findsOneWidget);
    });
  });

  testWidgets('«Move to…» и «Labels» → окна выбора', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await addTask(tester, app, 'Milk');
      await openByKey(tester, 'Milk');
      await pick(tester, find.text('Move to…'));
      expect(find.byType(Dialog), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      await openByKey(tester, 'Milk');
      await pick(tester, find.text('Labels'));
      expect(find.byType(Dialog), findsOneWidget);
    });
  });

  testWidgets('«Duplicate» → копия задачи', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await addTask(tester, app, 'Milk');
      await openByKey(tester, 'Milk');
      await pick(tester, find.text('Duplicate'));
      final ws = (await tester.runAsync(app.repo.load))!;
      expect(
        ws.projectTasks(ws.inbox!.id).where((t) => t.content == 'Milk'),
        hasLength(2),
      );
    });
  });

  testWidgets('«Delete» → подтверждение, затем задача удалена', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final id = await addTask(tester, app, 'Milk');
      await openByKey(tester, 'Milk');
      await pick(tester, find.text('Delete'));
      expect(find.byType(AlertDialog), findsOneWidget);
      await pick(
        tester,
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Delete'),
        ),
      );
      final ws = (await tester.runAsync(app.repo.load))!;
      expect(ws.task(id), isNull);
    });
  });

  testWidgets('правый клик по строке → то же меню', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await addTask(tester, app, 'Milk');
      await tester.tap(find.text('Milk'), buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();
      expect(find.text('Move to…'), findsOneWidget);
      expect(find.byType(TaskDialog), findsNothing);
    });
  });

  testWidgets('широкий экран с мышью без наведения — «⋯» скрыт; без мыши — '
      'виден', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await addTask(tester, app, 'Milk');
      expect(menuVisible(tester, 'Milk'), isTrue); // мыши нет — сенсорный

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await tester.pump();
      expect(menuVisible(tester, 'Milk'), isFalse);

      await mouse.moveTo(tester.getCenter(find.text('Milk')));
      await tester.pump();
      expect(menuVisible(tester, 'Milk'), isTrue); // наведение
    });
  });

  testWidgets('узкий экран с мышью — «⋯» виден и открывает меню касанием', (
    tester,
  ) async {
    await withApp(tester, size: const Size(400, 800), (device) async {
      final app = AppCommands(device);
      await addTask(tester, app, 'Milk');
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await tester.pump();
      expect(menuVisible(tester, 'Milk'), isTrue);

      await tester.tap(
        find.descendant(
          of: row('Milk'),
          matching: find.byTooltip('More actions'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Move to…'), findsOneWidget);
    });
  });

  testWidgets('правый клик при открытом сайдбаре → меню у курсора', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await addTask(tester, app, 'Milk');
      final click = tester.getCenter(find.text('Milk'));
      await tester.tapAt(click, buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();
      final corner = tester.getTopLeft(find.byIcon(Icons.edit_outlined));
      expect(corner.dx - click.dx, inInclusiveRange(0, 40));
      expect(corner.dy - click.dy, inInclusiveRange(0, 40));
    });
  });

  testWidgets('«Move to…» → задача в выбранном проекте', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final work = (await tester.runAsync(
        () => app.projects.add(name: 'Work'),
      ))!;
      await settle(tester);
      final id = await addTask(tester, app, 'Milk');
      await openByKey(tester, 'Milk');
      await pick(tester, find.text('Move to…'));
      await pick(
        tester,
        find.descendant(
          of: find.byType(SimpleDialog),
          matching: find.text('Work'),
        ),
      );
      final ws = (await tester.runAsync(app.repo.load))!;
      expect(ws.rootProjectOf(id), work);
    });
  });

  testWidgets('«Labels» → отмеченная метка на задаче', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final home = (await tester.runAsync(() => app.labels.add(name: 'home')))!;
      await settle(tester);
      final id = await addTask(tester, app, 'Milk');
      await openByKey(tester, 'Milk');
      await pick(tester, find.text('Labels'));
      await tester.tap(find.widgetWithText(CheckboxListTile, 'home'));
      await tester.pumpAndSettle();
      await pick(tester, find.text('Done'));
      expect((await load(tester, app, id)).labelIds, [home]);
    });
  });

  testWidgets('проект в архиве: ни `.`, ни правый клик меню не открывают, '
      '«⋯» скрыт', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final work = (await tester.runAsync(
        () => app.projects.add(name: 'Work'),
      ))!;
      await settle(tester);
      final id = (await tester.runAsync(
        () => app.tasks.add(content: 'Report', projectId: work),
      ))!;
      await settle(tester);
      await tester.runAsync(() => app.projects.archive(work));
      await settle(tester);
      await tester.tap(find.text('My Projects'));
      await settle(tester);
      await tester.tap(find.text('Archived projects only'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Work'));
      await settle(tester);

      expect(menuVisible(tester, 'Report'), isFalse);
      await openByKey(tester, 'Report');
      expect(find.text('Move to…'), findsNothing);
      await tester.tap(find.text('Report'), buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();
      expect(find.text('Move to…'), findsNothing);
      expect((await load(tester, app, id)).content, 'Report');
    });
  });
}
