import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/features/labels/ui/filters_labels_screen.dart';
import 'package:planner/features/labels/ui/label_screen.dart';
import 'package:planner/features/shell/ui/sidebar.dart';
import 'package:planner/features/tasks/ui/task_row.dart';

import '../../app/support/pump_app.dart';
import '../support/app_commands.dart';

// «Фильтры и метки» и экран метки: сценарии пользователя. Локаль — en.
void main() {
  Finder row(String content) =>
      find.ancestor(of: find.text(content), matching: find.byType(TaskRow));

  Finder inSidebar(Finder f) =>
      find.descendant(of: find.byType(Sidebar), matching: f);

  Finder labelMenu() => find
      .descendant(
        of: find.byWidgetPredicate(
          (w) => w is FiltersLabelsScreen || w is LabelScreen,
        ),
        matching: find.byTooltip('More actions'),
      )
      .first;

  /// Навести мышь на строку метки: меню «⋯» видно при наведении.
  Future<void> hover(WidgetTester tester, String text) async {
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(
      location: tester.getCenter(
        find.descendant(
          of: find.byType(FiltersLabelsScreen),
          matching: find.text(text),
        ),
      ),
    );
    addTearDown(mouse.removePointer);
    await tester.pump();
  }

  Future<void> openFiltersLabels(WidgetTester tester) async {
    await tester.tap(inSidebar(find.text('Filters & Labels')));
    await settle(tester);
  }

  testWidgets('«+» у «Labels» → новая метка с цветом в списке и в базе', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      await openFiltersLabels(tester);
      expect(find.byType(FiltersLabelsScreen), findsOneWidget);
      expect(find.text('No labels yet'), findsOneWidget);

      await tester.tap(find.byTooltip('Add label'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'home');
      await tester.tap(find.text('Charcoal'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Green').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await settle(tester);

      final label = (await tester.runAsync(AppCommands(device).read))!
          .labels
          .single;
      expect(label.name, 'home');
      expect(label.color, 'green');
      expect(find.text('home'), findsOneWidget);
    });
  });

  testWidgets('меню метки: переименовать, в избранное (сайдбар), удалить с '
      'подтверждением — метка снята с задач', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final label = (await tester.runAsync(
        () => app.labels.add(name: 'home'),
      ))!;
      await settle(tester);
      final task = (await tester.runAsync(
        () => app.tasks.add(content: 'Buy milk', labelIds: {label}),
      ))!;
      await settle(tester);
      await openFiltersLabels(tester);
      await hover(tester, 'home');

      await tester.tap(labelMenu());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit label'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'house');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await settle(tester);
      expect((await tester.runAsync(app.read))!.label(label)!.name, 'house');

      await tester.tap(labelMenu());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add to favorites'));
      await settle(tester);
      expect(inSidebar(find.text('house')), findsOneWidget);

      await tester.tap(labelMenu());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete label'));
      await tester.pumpAndSettle();
      expect(find.text('Delete label?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await settle(tester);
      final ws = (await tester.runAsync(app.read))!;
      expect(ws.labels, isEmpty);
      expect(ws.task(task)!.labelIds, isEmpty);
      expect(find.text('house'), findsNothing);
    });
  });

  testWidgets('экран метки: задачи из разных проектов с проектом; «Add task» '
      '— во «Входящие» с этой меткой', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final label = (await tester.runAsync(
        () => app.labels.add(name: 'home'),
      ))!;
      await settle(tester);
      final work = (await tester.runAsync(
        () => app.projects.add(name: 'Work', color: 'blue'),
      ))!;
      await settle(tester);
      await tester.runAsync(
        () => app.tasks.add(
          content: 'Fix sink',
          projectId: work,
          labelIds: {label},
        ),
      );
      await settle(tester);
      await tester.runAsync(
        () => app.tasks.add(content: 'Not labelled', projectId: work),
      );
      await settle(tester);
      await openFiltersLabels(tester);
      await tester.tap(find.text('home'));
      await settle(tester);

      expect(find.byType(LabelScreen), findsOneWidget);
      expect(row('Fix sink'), findsOneWidget);
      expect(row('Not labelled'), findsNothing);
      expect(
        find.descendant(of: row('Fix sink'), matching: find.text('Work')),
        findsOneWidget,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Task name'),
        'Water plants',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);

      final ws = (await tester.runAsync(app.read))!;
      final added = ws.children(null).single;
      expect(added.content, 'Water plants');
      expect(added.labelIds, [label]);
      expect(row('Water plants'), findsOneWidget);
    });
  });

  testWidgets('удалить метку с её экрана → переход на «Фильтры и метки»', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      await tester.runAsync(() => AppCommands(device).labels.add(name: 'home'));
      await settle(tester);
      await openFiltersLabels(tester);
      await tester.tap(find.text('home'));
      await settle(tester);

      await tester.tap(labelMenu());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete label'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await settle(tester);
      expect(find.byType(FiltersLabelsScreen), findsOneWidget);
    });
  });

  testWidgets('`g` `v` и `g` `l` — «Фильтры и метки», даже когда строка '
      'задачи в фокусе (`v` строки — «Перенести»)', (tester) async {
    await withApp(tester, (device) async {
      await tester.runAsync(
        () => AppCommands(device).tasks.add(content: 'Buy milk'),
      );
      await settle(tester);
      tester
          .widget<Focus>(
            find
                .descendant(of: row('Buy milk'), matching: find.byType(Focus))
                .first,
          )
          .focusNode!
          .requestFocus();
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await settle(tester);
      expect(find.byType(SimpleDialog), findsNothing);
      expect(find.byType(FiltersLabelsScreen), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
      await settle(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
      await settle(tester);
      expect(find.byType(FiltersLabelsScreen), findsOneWidget);
    });
  });

  testWidgets('экран метки: `Ctrl+]` не делает задачу подзадачей — у неё '
      'другие соседи в настоящем списке; у подзадачи — раздел её корня', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final label = (await tester.runAsync(
        () => app.labels.add(name: 'home'),
      ))!;
      await settle(tester);
      final work = (await tester.runAsync(
        () => app.projects.add(name: 'Work'),
      ))!;
      await settle(tester);
      final week = (await tester.runAsync(
        () => app.sections.add(work, name: 'Week'),
      ))!;
      await settle(tester);
      final parent = (await tester.runAsync(
        () => app.tasks.add(content: 'Plan', projectId: work, sectionId: week),
      ))!;
      await settle(tester);
      await tester.runAsync(
        () => app.tasks.add(content: 'Other', labelIds: {label}),
      );
      await settle(tester);
      final sub = (await tester.runAsync(
        () =>
            app.tasks.add(content: 'Call', parentId: parent, labelIds: {label}),
      ))!;
      await settle(tester);
      // Родителя перенесли: собственный раздел подзадачи устарел.
      final later = (await tester.runAsync(
        () => app.sections.add(work, name: 'Later'),
      ))!;
      await settle(tester);
      await tester.runAsync(
        () => app.tasks.move(parent, projectId: work, sectionId: later),
      );
      await settle(tester);
      await openFiltersLabels(tester);
      await tester.tap(find.text('home'));
      await settle(tester);

      expect(
        find.descendant(of: row('Call'), matching: find.text('Work / Later')),
        findsOneWidget,
      );
      tester
          .widget<Focus>(
            find
                .descendant(of: row('Call'), matching: find.byType(Focus))
                .first,
          )
          .focusNode!
          .requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.bracketLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.bracketRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await settle(tester);
      expect((await tester.runAsync(app.read))!.taskParent(sub), parent);
    });
  });

  testWidgets('`g`, а через 1,5 с `v` — уже не переход', (tester) async {
    await withApp(tester, (_) async {
      await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 1600)),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await settle(tester);
      expect(find.byType(FiltersLabelsScreen), findsNothing);
    });
  });
}
