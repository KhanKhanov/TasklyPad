import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/domain/models.dart';
import 'package:planner/features/common/ui/ui_kit.dart';
import 'package:planner/features/projects/ui/project_screen.dart';
import 'package:planner/features/sections/ui/section_block.dart';
import 'package:planner/features/tasks/logic/due_dates.dart';
import 'package:planner/features/tasks/ui/task_actions.dart';
import 'package:planner/features/tasks/ui/task_dialog.dart';
import 'package:planner/features/tasks/ui/task_row.dart';
import 'package:planner/l10n/app_localizations.dart';

import '../../app/support/pump_app.dart';
import '../../sync/support/devices.dart';
import '../support/app_commands.dart';

// Сценарии, найденные ревью коммита 2 M2.2: на каждый — тест. Локаль — en.
void main() {
  Future<String> addTask(
    WidgetTester tester,
    AppCommands app,
    String content, {
    String? projectId,
    String? parentId,
    Due? due,
  }) async {
    final id = (await tester.runAsync(
      () => app.tasks.add(
        content: content,
        projectId: projectId,
        parentId: parentId,
        due: due,
      ),
    ))!;
    await settle(tester);
    return id;
  }

  Finder row(String content) =>
      find.ancestor(of: find.text(content), matching: find.byType(TaskRow));

  FocusNode rowFocus(WidgetTester tester, String content) => tester
      .widget<Focus>(
        find.descendant(of: row(content), matching: find.byType(Focus)).first,
      )
      .focusNode!;

  Future<void> focusRow(WidgetTester tester, String content) async {
    rowFocus(tester, content).requestFocus();
    await tester.pumpAndSettle();
  }

  Finder panelField() => find
      .descendant(of: find.byType(TaskDialog), matching: find.byType(TextField))
      .first;

  testWidgets('панель: курсор в названии, задачу переименовали на другом '
      'устройстве → уход из поля не затирает чужую правку', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final id = await addTask(tester, app, 'Buy milk');
      await tester.tap(find.text('Buy milk'));
      await settle(tester);

      await tester.tap(panelField());
      await tester.pump();
      await tester.runAsync(() => app.tasks.rename(id, 'Buy bread'));
      await settle(tester);
      expect(
        tester.widget<TextField>(panelField()).controller!.text,
        'Buy milk', // набираемое не перебивается
      );
      // Курсор ушёл из названия без правки — в поле приходит чужая правка,
      // и следующая правка строится уже на ней.
      await tester.tap(
        find.descendant(
          of: find.byType(TaskDialog),
          matching: find.widgetWithText(TextField, 'Description'),
        ),
      );
      await settle(tester);
      expect(
        tester.widget<TextField>(panelField()).controller!.text,
        'Buy bread',
      );

      await tester.tap(find.byTooltip('Close'));
      await settle(tester);
      expect((await tester.runAsync(app.read))!.task(id)!.content, 'Buy bread');
    });
  });

  testWidgets('панель: Enter в названии сохраняет, перевода строки нет', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final id = await addTask(tester, app, 'Buy milk');
      await tester.tap(find.text('Buy milk'));
      await settle(tester);

      await tester.enterText(panelField(), 'Buy\noat milk');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);
      expect(
        (await tester.runAsync(app.read))!.task(id)!.content,
        'Buy oat milk',
      );
    });
  });

  testWidgets('панель: тост «Undo» — внутри окна и отменяет выполнение '
      'подзадачи', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final parent = await addTask(tester, app, 'Parent');
      final child = await addTask(tester, app, 'Child', parentId: parent);
      await tester.tap(find.text('Parent'));
      await settle(tester);

      await tester.tap(
        find
            .descendant(
              of: find.byType(TaskDialog),
              matching: find.byTooltip('Complete'),
            )
            .last,
      );
      await settle(tester);
      final undo = find.descendant(
        of: find.byType(TaskDialog),
        matching: find.text('Undo'),
      );
      expect(undo, findsOneWidget);
      await tester.tap(undo);
      await settle(tester);
      expect(find.byType(TaskDialog), findsOneWidget); // окно не закрылось
      expect(
        (await tester.runAsync(app.read))!.task(child)!.isCompleted,
        isFalse,
      );
    });
  });

  testWidgets('ошибка записи (не отказ правилами) показывается, а не '
      'теряется', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (c) {
              context = c;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    await runCommand(context, () async => throw Exception('disk full'));
    await tester.pump();
    expect(find.textContaining("Couldn't complete the action"), findsOneWidget);
    expect(find.textContaining('disk full'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Ошибка программы — ещё и в обработчик ошибок Flutter: тесты её видят.
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    await runCommand(context, () async => throw StateError('bug'));
    await tester.pump();
    expect(tester.takeException(), isA<StateError>());
    expect(find.textContaining('bug'), findsOneWidget);
  });

  testWidgets('`j` / `k` переходят к соседней задаче, минуя кнопки строки', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final parent = await addTask(tester, app, 'First');
      await addTask(tester, app, 'Inner', parentId: parent);
      await addTask(tester, app, 'Second');

      await focusRow(tester, 'First');
      await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
      await tester.pumpAndSettle();
      expect(rowFocus(tester, 'Inner').hasPrimaryFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
      await tester.pumpAndSettle();
      expect(rowFocus(tester, 'Second').hasPrimaryFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.pumpAndSettle();
      expect(rowFocus(tester, 'Inner').hasPrimaryFocus, isTrue);
    });
  });

  testWidgets('проект в архиве: задачи только для просмотра — кружок, `e` и '
      'поля панели не меняют данные', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final work = (await tester.runAsync(
        () => app.projects.add(name: 'Work'),
      ))!;
      await settle(tester); // запись за записью — с кадром между ними
      await tester.runAsync(() => app.sections.add(work, name: 'Week'));
      await settle(tester);
      final id = await addTask(tester, app, 'Report', projectId: work);
      await tester.runAsync(() => app.projects.archive(work));
      await settle(tester);
      await tester.tap(find.text('My Projects'));
      await settle(tester);
      await tester.tap(find.text('Archived'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Work'));
      await settle(tester);

      expect(find.text('Add task'), findsNothing);
      // Раздел: без меню и без переименования по нажатию.
      expect(
        find.descendant(
          of: find.byType(SectionBlock),
          matching: find.byTooltip('More actions'),
        ),
        findsNothing,
      );
      await tester.tap(find.text('Week'));
      await tester.pump();
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.byTooltip('Complete'));
      await focusRow(tester, 'Report');
      await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      await settle(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settle(tester);
      expect(find.byType(TaskDialog), findsOneWidget); // открыть можно
      expect(find.text('Add sub-task'), findsNothing);
      await tester.tap(find.text('Labels'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);

      final task = (await tester.runAsync(app.read))!.task(id)!;
      expect(task.isCompleted, isFalse);
      expect(task.priority, 4);
    });
  });

  testWidgets('Alt+E и Alt+1 на строке — не хоткеи', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final id = await addTask(tester, app, 'Buy milk');
      await focusRow(tester, 'Buy milk');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await settle(tester);
      final task = (await tester.runAsync(app.read))!.task(id)!;
      expect(task.isCompleted, isFalse);
      expect(task.priority, 4);
    });
  });

  testWidgets('повторное выполнение, которое ничего не изменило (второй клик '
      'двойного щелчка), не заменяет тост: «Undo» отменяет первое', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final id = await addTask(tester, app, 'Buy milk');
      await tester.tap(find.byTooltip('Complete'));
      await settle(tester);
      final context = tester.element(find.byType(ProjectScreen));
      // Второй клик успел до перестройки: экран ещё показывает задачу
      // невыполненной, а в базе она уже выполнена — отменять нечего.
      await tester.runAsync(
        () => runWithUndo(context, 'Second', () => app.tasks.complete(id)),
      );
      await settle(tester);
      expect(find.text('Second'), findsNothing);

      await tester.tap(find.text('Undo'));
      await settle(tester);
      expect((await tester.runAsync(app.read))!.task(id)!.isCompleted, isFalse);
    });
  });

  testWidgets('в панели подзадачи не сворачиваются: счётчик подзадачи не '
      'пишет «свёрнуто»', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final parent = await addTask(tester, app, 'Parent');
      final child = await addTask(tester, app, 'Child', parentId: parent);
      await addTask(tester, app, 'Grandchild', parentId: child);
      await tester.tap(find.text('Parent'));
      await settle(tester);

      // Счётчик в строке подзадачи «Child» (у заголовка «Подзадачи» — свой).
      await tester.tap(
        find.descendant(
          of: find.byType(TaskDialog),
          matching: find.descendant(
            of: find.byType(TaskRow),
            matching: find.text('0/1'),
          ),
        ),
      );
      await settle(tester);
      expect(
        (await tester.runAsync(app.read))!.task(child)!.isCollapsed,
        isFalse,
      );
    });
  });

  testWidgets('панель выполненной задачи показывает удалённую метку', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final label = (await tester.runAsync(
        () => app.labels.add(name: 'home'),
      ))!;
      await settle(tester);
      final id = (await tester.runAsync(
        () => app.tasks.add(content: 'Done', labelIds: {label}),
      ))!;
      await settle(tester);
      await tester.tap(find.text('Done'));
      await settle(tester);

      await tester.runAsync(() => app.tasks.complete(id));
      await settle(tester);
      await tester.runAsync(() => app.labels.delete(label));
      await settle(tester);
      expect(
        find.descendant(
          of: find.byType(TaskDialog),
          matching: find.text('home'),
        ),
        findsOneWidget,
      );
    });
  });

  testWidgets('в полночь «Today» сам становится «Yesterday»', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final today = isoDate(testStart.toLocal());
      await addTask(tester, app, 'Buy milk', due: Due(date: today));
      expect(find.text('Today'), findsOneWidget);

      device.advance(const Duration(days: 1));
      await tester.pump(const Duration(days: 1));
      await tester.pump();
      expect(find.text('Yesterday'), findsOneWidget);
    });
  });

  testWidgets('время срока — в формате локали: en — 12 часов', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final today = isoDate(testStart.toLocal());
      await addTask(
        tester,
        app,
        'Call',
        due: Due(date: today, time: '14:30'),
      );
      expect(find.text('Today 2:30 PM'), findsOneWidget);
    });
  });

  testWidgets('смена даты срока сохраняет время и часовой пояс', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final today = isoDate(testStart.toLocal());
      final id = await addTask(
        tester,
        app,
        'Call',
        due: Due(date: today, time: '14:30', tz: 'Europe/Berlin'),
      );
      await tester.tap(find.text('Call'));
      await settle(tester);
      await tester.tap(find.text('Date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tomorrow').last);
      await settle(tester);

      final due = (await tester.runAsync(app.read))!.task(id)!.due!;
      expect(due.date, isNot(today));
      expect(due.time, '14:30');
      expect(due.tz, 'Europe/Berlin');
    });
  });

  testWidgets('панель: пустое название не сохраняется — возвращается прежнее', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final id = await addTask(tester, app, 'Buy milk');
      await tester.tap(find.text('Buy milk'));
      await settle(tester);

      await tester.enterText(panelField(), '   ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);
      expect(
        tester.widget<TextField>(panelField()).controller!.text,
        'Buy milk',
      );
      expect(find.byType(SnackBar), findsNothing); // молча, без отказа
      expect((await tester.runAsync(app.read))!.task(id)!.content, 'Buy milk');
    });
  });
}
