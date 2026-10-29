import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/features/projects/ui/projects_screen.dart';
import 'package:planner/features/shell/ui/sidebar.dart';
import 'package:planner/features/tasks/ui/task_dialog.dart';
import 'package:planner/features/tasks/ui/task_row.dart';

import '../../app/support/pump_app.dart';
import '../support/app_commands.dart';

// Список задач, панель задачи и хоткеи: сценарии пользователя. Локаль — en.
void main() {
  Future<String> addTask(
    WidgetTester tester,
    AppCommands app,
    String content, {
    String? parentId,
  }) async {
    final id = (await tester.runAsync(
      () => app.tasks.add(content: content, parentId: parentId),
    ))!;
    await settle(tester);
    return id;
  }

  Finder row(String content) =>
      find.ancestor(of: find.text(content), matching: find.byType(TaskRow));

  /// Поставить фокус на строку, как стрелками: видно меню «⋯» и работают
  /// клавиши строки.
  Future<void> focusRow(WidgetTester tester, String content) async {
    tester
        .widget<Focus>(
          find.descendant(of: row(content), matching: find.byType(Focus)).first,
        )
        .focusNode!
        .requestFocus();
    await tester.pumpAndSettle(); // смена фокуса применяется в микрозадаче
  }

  /// Курсор стоит в поле [field].
  bool cursorIn(WidgetTester tester, Finder field) {
    final focused = FocusManager.instance.primaryFocus?.context;
    return focused != null &&
        find
            .descendant(of: field, matching: find.byType(EditableText))
            .evaluate()
            .any(
              (e) =>
                  focused.findAncestorWidgetOfExactType<EditableText>() ==
                      e.widget ||
                  focused.widget == e.widget,
            );
  }

  testWidgets('«Add task» → задача в списке, редактор остаётся для '
      'следующей, Esc закрывает', (tester) async {
    await withApp(tester, (device) async {
      await tester.tap(find.text('Add task'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Buy milk');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);

      expect(row('Buy milk'), findsOneWidget);
      expect(find.text('Task name'), findsOneWidget); // редактор открыт
      final ws = (await tester.runAsync(AppCommands(device).read))!;
      expect(ws.children(null).single.content, 'Buy milk');

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Task name'), findsNothing);
    });
  });

  testWidgets('кружок → задача выполнена и скрыта, тост «Undo» возвращает', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final id = await addTask(tester, app, 'Buy milk');

      await tester.tap(find.byTooltip('Complete'));
      await settle(tester);
      expect(row('Buy milk'), findsNothing);
      expect(find.text('Task completed'), findsOneWidget);
      expect((await tester.runAsync(app.read))!.task(id)!.isCompleted, isTrue);

      await tester.tap(find.text('Undo'));
      await settle(tester);
      expect(row('Buy milk'), findsOneWidget);
      expect((await tester.runAsync(app.read))!.task(id)!.isCompleted, isFalse);
    });
  });

  testWidgets('«View → Completed tasks» показывает выполненную задачу', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final id = await addTask(tester, app, 'Done task');
      await tester.runAsync(() => app.tasks.complete(id));
      await settle(tester);
      expect(row('Done task'), findsNothing);

      await tester.tap(find.byTooltip('Display'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CheckedPopupMenuItem<void>));
      await settle(tester);
      expect(row('Done task'), findsOneWidget);
    });
  });

  testWidgets('удалить из меню строки — только после подтверждения', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final id = await addTask(tester, app, 'Buy milk');

      Future<void> openDelete() async {
        await focusRow(tester, 'Buy milk');
        await tester.tap(
          find.descendant(
            of: row('Buy milk'),
            matching: find.byTooltip('More actions'),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete').last);
        await tester.pumpAndSettle();
      }

      await openDelete();
      expect(find.text('Delete task?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(row('Buy milk'), findsOneWidget);

      await openDelete();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await settle(tester);
      expect(row('Buy milk'), findsNothing);
      expect((await tester.runAsync(app.read))!.task(id), isNull);
    });
  });

  testWidgets('хоткеи: `a` — редактор внизу, `Shift+A` — новая задача '
      'наверху; пока курсор в поле, хоткеи молчат', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await addTask(tester, app, 'First');

      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.pumpAndSettle();
      final editor = find.widgetWithText(TextField, 'Task name');
      double editorY() => tester.getTopLeft(editor).dy;
      expect(cursorIn(tester, editor), isTrue);
      expect(editorY(), greaterThan(tester.getTopLeft(row('First')).dy));
      // Курсор в поле: `Shift+A` — текст, редактор не прыгает наверх.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      expect(editorY(), greaterThan(tester.getTopLeft(row('First')).dy));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Top');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);

      final ws = (await tester.runAsync(app.read))!;
      expect(ws.children(null).map((t) => t.content), ['Top', 'First']);
      expect(
        tester.getTopLeft(row('Top')).dy,
        lessThan(tester.getTopLeft(row('First')).dy),
      );
    });
  });

  testWidgets('строка в фокусе: `Ctrl+]` делает подзадачей, `4`→`1` меняет '
      'приоритет', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final parent = await addTask(tester, app, 'Parent');
      final child = await addTask(tester, app, 'Child');

      await focusRow(tester, 'Child');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.bracketRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await settle(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      await settle(tester);

      final ws = (await tester.runAsync(app.read))!;
      expect(ws.taskParent(child), parent);
      expect(ws.task(child)!.priority, 1);
      expect(find.text('0/1'), findsOneWidget); // счётчик подзадач у родителя
    });
  });

  testWidgets('панель задачи: название, приоритет и подзадача сохраняются', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final id = await addTask(tester, app, 'Buy milk');

      await tester.tap(find.text('Buy milk'));
      await settle(tester);
      expect(find.byType(TaskDialog), findsOneWidget);

      // Название сохраняется при уходе из поля.
      await tester.enterText(
        find
            .descendant(
              of: find.byType(TaskDialog),
              matching: find.byType(TextField),
            )
            .first,
        'Buy oat milk',
      );
      await tester.tap(find.text('Priority 4'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Priority 2').last);
      await settle(tester);

      await tester.tap(find.text('Add sub-task'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(TaskDialog),
          matching: find.widgetWithText(TextField, 'Task name'),
        ),
        'Oat',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);

      final ws = (await tester.runAsync(app.read))!;
      final task = ws.task(id)!;
      expect(task.content, 'Buy oat milk');
      expect(task.priority, 2);
      expect(ws.subtasksOf(id).single.value.content, 'Oat');

      await tester.tap(find.byTooltip('Close'));
      await settle(tester);
      expect(find.byType(TaskDialog), findsNothing);
      expect(find.text('0/1'), findsOneWidget);
    });
  });

  testWidgets('панель задачи закрывается, если задачу удалили (в том числе '
      'на другом устройстве)', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final id = await addTask(tester, app, 'Buy milk');
      await tester.tap(find.text('Buy milk'));
      await settle(tester);
      expect(find.byType(TaskDialog), findsOneWidget);

      await tester.runAsync(() => app.tasks.delete(id));
      await settle(tester);
      expect(find.byType(TaskDialog), findsNothing);
    });
  });

  testWidgets('хоткеи оболочки: `g` `p` — «Мои проекты», `g` `i` — '
      '«Входящие», `m` — сайдбар', (tester) async {
    await withApp(tester, (_) async {
      await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
      await settle(tester);
      expect(find.byType(ProjectsScreen), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
      await settle(tester);
      expect(find.byType(ProjectsScreen), findsNothing);
      expect(find.text('Add task'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
      await settle(tester);
      expect(find.byType(Sidebar), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
      await settle(tester);
      expect(find.byType(Sidebar), findsOneWidget);
    });
  });

  testWidgets('`S` — редактор раздела с курсором; задача добавляется в '
      'раздел', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.pumpAndSettle();
      final name = find.widgetWithText(TextField, 'Name this section');
      expect(cursorIn(tester, name), isTrue);
      await tester.enterText(name, 'Shop');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);

      // У раздела своя «Add task»: вторая на экране.
      await tester.tap(find.text('Add task').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Task name'),
        'Bread',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);

      final ws = (await tester.runAsync(app.read))!;
      final section = ws.sectionsOf(ws.inbox!.id).single;
      expect(section.name, 'Shop');
      expect(ws.children(null, sectionId: section.id).single.content, 'Bread');
      expect(
        tester.getTopLeft(row('Bread')).dy,
        greaterThan(tester.getTopLeft(find.text('Shop')).dy),
      );
    });
  });

  testWidgets('панель задачи: новая метка создаётся из поиска и ставится '
      'задаче', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final id = await addTask(tester, app, 'Buy milk');
      await tester.tap(find.text('Buy milk'));
      await settle(tester);

      await tester.tap(find.text('Labels'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Label'), 'home');
      await tester.pump();
      await tester.tap(find.text('Create label "home"'));
      await settle(tester);
      await tester.tap(find.text('Done'));
      await settle(tester);

      final ws = (await tester.runAsync(app.read))!;
      final label = ws.labels.single;
      expect(label.name, 'home');
      expect(ws.task(id)!.labelIds, [label.id]);

      await tester.tap(find.byTooltip('Close'));
      await settle(tester);
      expect(
        find.descendant(of: row('Buy milk'), matching: find.text('home')),
        findsOneWidget,
      );
    });
  });

  testWidgets('клик по счётчику подзадач сворачивает и раскрывает их', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final parent = await addTask(tester, app, 'Parent');
      await addTask(tester, app, 'Child', parentId: parent);
      expect(row('Child'), findsOneWidget);

      await tester.tap(find.text('0/1'));
      await settle(tester);
      expect(row('Child'), findsNothing);
      expect(
        (await tester.runAsync(app.read))!.task(parent)!.isCollapsed,
        isTrue,
      );

      await tester.tap(find.text('0/1'));
      await settle(tester);
      expect(row('Child'), findsOneWidget);
    });
  });

  testWidgets('узкий экран: панель задачи на весь экран, поля под '
      'подзадачами', (tester) async {
    await withApp(tester, size: const Size(400, 800), (device) async {
      final app = AppCommands(device);
      await addTask(tester, app, 'Buy milk');
      await tester.tap(find.text('Buy milk'));
      await settle(tester);

      expect(find.byType(Dialog), findsOneWidget);
      expect(tester.getSize(find.byType(Dialog)).width, 400);
      expect(
        tester.getTopLeft(find.text('Priority')).dy,
        greaterThan(tester.getTopLeft(find.text('Add sub-task')).dy),
      );
    });
  });
}
