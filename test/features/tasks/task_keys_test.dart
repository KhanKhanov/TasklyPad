import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/domain/models.dart';
import 'package:planner/features/tasks/ui/task_dialog.dart';
import 'package:planner/features/tasks/ui/task_row.dart';

import '../../app/support/pump_app.dart';
import '../support/app_commands.dart';

// Клавиши строки задачи по help «Use keyboard shortcuts» и `J`/`K` в панели.
// Локаль — en.
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

  Finder row(String content) =>
      find.ancestor(of: find.text(content), matching: find.byType(TaskRow));

  Future<void> focusRow(WidgetTester tester, String content) async {
    tester
        .widget<Focus>(
          find.descendant(of: row(content), matching: find.byType(Focus)).first,
        )
        .focusNode!
        .requestFocus();
    await tester.pumpAndSettle();
  }

  Finder panelTitle() => find
      .descendant(of: find.byType(TaskDialog), matching: find.byType(TextField))
      .first;

  String titleText(WidgetTester tester) =>
      tester.widget<TextField>(panelTitle()).controller!.text;

  testWidgets('`t` — выбор срока, `Shift+T` — убрать срок с «Undo»', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final id = await addTask(tester, app, 'Buy milk');
      await focusRow(tester, 'Buy milk');

      await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tomorrow'));
      await settle(tester);
      expect((await tester.runAsync(app.read))!.task(id)!.due, isNotNull);

      await focusRow(tester, 'Buy milk');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await settle(tester);
      expect((await tester.runAsync(app.read))!.task(id)!.due, isNull);
      expect(find.text('Undo'), findsOneWidget);
    });
  });

  testWidgets('`l` — метки, `v` — перенести, `y` — приоритет', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final work = (await tester.runAsync(
        () => app.projects.add(name: 'Work'),
      ))!;
      await settle(tester);
      final id = await addTask(tester, app, 'Buy milk');

      await focusRow(tester, 'Buy milk');
      await tester.sendKeyEvent(LogicalKeyboardKey.keyY);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Priority 1').last);
      await settle(tester);
      expect((await tester.runAsync(app.read))!.task(id)!.priority, 1);

      await focusRow(tester, 'Buy milk');
      await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Label'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      await focusRow(tester, 'Buy milk');
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(SimpleDialog),
          matching: find.text('Work'),
        ),
      );
      await settle(tester);
      final ws = (await tester.runAsync(app.read))!;
      expect(ws.rootProjectOf(id), work);
    });
  });

  testWidgets('`Ctrl+↓` не переставляет задачу: в Todoist это переход при '
      'редактировании', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await addTask(tester, app, 'First');
      await addTask(tester, app, 'Second');
      await focusRow(tester, 'First');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await settle(tester);
      final ws = (await tester.runAsync(app.read))!;
      expect(ws.children(null).map((t) => t.content), ['First', 'Second']);
    });
  });

  testWidgets('панель: `J` / `K` и стрелки — соседняя задача списка; правка '
      'названия сохраняется при переходе', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final first = await addTask(tester, app, 'First');
      await addTask(tester, app, 'Second');
      await addTask(tester, app, 'Third');

      await tester.tap(find.text('First'));
      await settle(tester);
      expect(titleText(tester), 'First');

      await tester.enterText(panelTitle(), 'First edited');
      await tester.tap(find.byTooltip('Next task'));
      await settle(tester);
      expect(titleText(tester), 'Second');
      expect(
        (await tester.runAsync(app.read))!.task(first)!.content,
        'First edited',
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
      await settle(tester);
      expect(titleText(tester), 'Third');
      final next = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.keyboard_arrow_down),
      );
      expect(next.onPressed, isNull); // последняя в списке

      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await settle(tester);
      expect(titleText(tester), 'Second');
    });
  });

  testWidgets('панель: у «Подзадач» — прогресс, выполнено из всех', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final parent = await addTask(tester, app, 'Parent');
      final done = (await tester.runAsync(
        () => app.tasks.add(content: 'A', parentId: parent),
      ))!;
      await settle(tester);
      await tester.runAsync(
        () => app.tasks.add(content: 'B', parentId: parent),
      );
      await settle(tester);
      await tester.runAsync(() => app.tasks.complete(done));
      await settle(tester);
      await tester.tap(find.text('Parent'));
      await settle(tester);

      final progress = tester.widget<CircularProgressIndicator>(
        find.descendant(
          of: find.byType(TaskDialog),
          matching: find.byType(CircularProgressIndicator),
        ),
      );
      expect(progress.value, 0.5);
      expect(
        find.descendant(
          of: find.byType(TaskDialog),
          matching: find.text('1/2'),
        ),
        findsOneWidget,
      );
    });
  });
}
