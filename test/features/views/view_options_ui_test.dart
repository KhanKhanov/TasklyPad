import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/domain/models.dart';
import 'package:planner/domain/view_options.dart';
import 'package:planner/features/labels/ui/label_screen.dart';
import 'package:planner/features/shell/ui/sidebar.dart';
import 'package:planner/features/tasks/ui/add_task_editor.dart';
import 'package:planner/features/tasks/ui/task_row.dart';

import '../../app/support/pump_app.dart';
import '../support/app_commands.dart';

// «Отображение» на экранах проекта и метки (план M4.5): меню, группы,
// «Добавить задачу» в группе, «Сбросить всё», клавиши сортировки. Локаль — en,
// приложение открывается на «Входящих».
void main() {
  Finder row(String content) =>
      find.ancestor(of: find.text(content), matching: find.byType(TaskRow));

  /// Строки задач сверху вниз.
  List<String> rowsInOrder(WidgetTester tester, List<String> contents) =>
      [...contents]..sort(
        (a, b) => tester
            .getTopLeft(row(a))
            .dy
            .compareTo(tester.getTopLeft(row(b)).dy),
      );

  Future<void> pick(WidgetTester tester, String submenu, String item) async {
    await tester.tap(find.textContaining('Display'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(submenu));
    await tester.pumpAndSettle();
    await tester.tap(find.text(item).last);
    await settle(tester);
  }

  /// «Add task» группы [index] по порядку — нажатие по тексту: строка
  /// кнопки шире самой кнопки.
  Finder addInGroup(int index) => find.descendant(
    of: find.byType(AddTaskButton).at(index),
    matching: find.text('Add task'),
  );

  Future<ViewOptions> inboxView(WidgetTester tester, AppCommands app) async {
    final inbox = (await tester.runAsync(app.read))!.inbox!.id;
    return (await tester.runAsync(
      () => app.viewsRepo.load(ViewType.project, objectId: inbox),
    ))!;
  }

  testWidgets('группировка по приоритету — группы, «Display: 1»; «Add task» '
      'группы P1 добавляет задачу с P1', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await tester.runAsync(
        () => app.tasks.add(content: 'Urgent', priority: 1),
      );
      await settle(tester);
      await tester.runAsync(() => app.tasks.add(content: 'Someday'));
      await settle(tester);

      await pick(tester, 'Grouping', 'Priority');
      expect(find.text('Display: 1'), findsOneWidget);
      expect(find.text('Priority 1'), findsOneWidget);
      expect(find.text('Priority 4'), findsOneWidget);
      expect(rowsInOrder(tester, ['Someday', 'Urgent']), ['Urgent', 'Someday']);
      expect((await inboxView(tester, app)).grouping, Grouping.priority);

      // Кнопки — у каждой группы, первая — у «Priority 1».
      expect(find.byType(AddTaskButton), findsNWidgets(2));
      await tester.tap(addInGroup(0));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Task name'),
        'Call bank',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);

      final ws = (await tester.runAsync(app.read))!;
      final added = ws
          .children(null)
          .firstWhere((t) => t.content == 'Call bank');
      expect(added.priority, 1);
    });
  });

  testWidgets('группировка по дате — «Add task» только у дня: у «Overdue» и '
      '«No date» кнопки нет; задача дня получает его дату', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      // Часы теста — 23.10.2026.
      await tester.runAsync(
        () => app.tasks.add(
          content: 'Late',
          due: const Due(date: '2026-10-20'),
        ),
      );
      await settle(tester);
      await tester.runAsync(() => app.tasks.add(content: 'Free'));
      await settle(tester);
      await tester.runAsync(
        () => app.tasks.add(
          content: 'Soon',
          due: const Due(date: '2026-10-24'),
        ),
      );
      await settle(tester);

      await pick(tester, 'Grouping', 'Date');
      expect(find.text('Overdue'), findsOneWidget);
      expect(find.text('No date'), findsOneWidget);
      expect(rowsInOrder(tester, ['Free', 'Soon', 'Late']), [
        'Late',
        'Soon',
        'Free',
      ]);
      expect(find.byType(AddTaskButton), findsOneWidget);

      await tester.tap(addInGroup(0));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Task name'),
        'Pack',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);
      final ws = (await tester.runAsync(app.read))!;
      final added = ws.children(null).firstWhere((t) => t.content == 'Pack');
      expect(added.due, const Due(date: '2026-10-24'));
    });
  });

  testWidgets('«Add task» в группе метки ставит метку, в группе дедлайна — '
      'дедлайн; у группы удалённой метки кнопки нет', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final home = (await tester.runAsync(() => app.labels.add(name: 'home')))!;
      await settle(tester);
      final old = (await tester.runAsync(() => app.labels.add(name: 'old')))!;
      await settle(tester);
      await tester.runAsync(
        () => app.tasks.add(content: 'Tidy', labelIds: {home}),
      );
      await settle(tester);
      final done = (await tester.runAsync(
        () => app.tasks.add(content: 'Archive', labelIds: {old}),
      ))!;
      await settle(tester);
      await tester.runAsync(() => app.tasks.complete(done));
      await settle(tester);
      await tester.runAsync(() => app.labels.delete(old));
      await settle(tester);
      // Живая метка только на выполненной задаче, переименована после
      // выполнения: заголовок группы — текущее имя.
      final misc = (await tester.runAsync(() => app.labels.add(name: 'misc')))!;
      await settle(tester);
      final note = (await tester.runAsync(
        () => app.tasks.add(content: 'Note', labelIds: {misc}),
      ))!;
      await settle(tester);
      await tester.runAsync(() => app.tasks.complete(note));
      await settle(tester);
      await tester.runAsync(() => app.labels.rename(misc, 'notes'));
      await settle(tester);

      await pick(tester, 'Grouping', 'Label');
      await tester.tap(find.text('Display: 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CheckboxMenuButton));
      await settle(tester);
      // Группы: «home» и «notes» с кнопкой, «old» (выполненная до удаления)
      // — без.
      expect(find.text('old'), findsWidgets);
      // Строка выполненной задачи — «misc» (имя на момент выполнения, M4.2).
      expect(find.text('notes'), findsOneWidget);
      expect(find.byType(AddTaskButton), findsNWidgets(2));
      await tester.tap(addInGroup(0));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Task name'),
        'Vacuum',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);
      var ws = (await tester.runAsync(app.read))!;
      expect(
        ws.children(null).firstWhere((t) => t.content == 'Vacuum').labelIds,
        [home],
      );

      // Редактор остаётся открытым для следующей задачи — закрыть: у него
      // своя кнопка «Deadline».
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Display: 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Grouping'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Deadline').last);
      await settle(tester);
      await tester.runAsync(
        () => app.tasks.add(content: 'File taxes', deadline: '2026-10-30'),
      );
      await settle(tester);
      await tester.tap(addInGroup(0));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Task name'),
        'Receipts',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);
      ws = (await tester.runAsync(app.read))!;
      expect(
        ws.children(null).firstWhere((t) => t.content == 'Receipts').deadline,
        '2026-10-30',
      );
    });
  });

  testWidgets('«Reset all» убирает группировку и сортировку, «Completed tasks» '
      'остаётся', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await tester.runAsync(() => app.tasks.add(content: 'One', priority: 2));
      await settle(tester);
      await pick(tester, 'Grouping', 'Priority');
      await pick(tester, 'Sorting', 'Name');
      expect(find.text('Display: 2'), findsOneWidget);
      await tester.tap(find.text('Display: 2'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CheckboxMenuButton));
      await settle(tester);

      await tester.tap(find.text('Display: 2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset all'));
      await settle(tester);

      expect(find.text('Display'), findsOneWidget);
      expect(find.text('Priority 2'), findsNothing);
      final view = await inboxView(tester, app);
      expect(view.applied, 0);
      expect(view.showCompletedTasks, isTrue);
    });
  });

  testWidgets('`N` сортирует по имени, `P` — по приоритету; «Ordering» '
      'разворачивает', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await tester.runAsync(() => app.tasks.add(content: 'beta', priority: 1));
      await settle(tester);
      await tester.runAsync(() => app.tasks.add(content: 'Alpha', priority: 3));
      await settle(tester);
      expect(rowsInOrder(tester, ['Alpha', 'beta']), ['beta', 'Alpha']);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
      await settle(tester);
      expect(rowsInOrder(tester, ['beta', 'Alpha']), ['Alpha', 'beta']);
      expect((await inboxView(tester, app)).sorting, Sorting.alphabetically);

      await pick(tester, 'Ordering', 'Descending');
      expect(rowsInOrder(tester, ['Alpha', 'beta']), ['beta', 'Alpha']);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
      await settle(tester);
      expect((await inboxView(tester, app)).sorting, Sorting.priority);
    });
  });

  testWidgets('экран метки: «Display» без «Manual», «Completed tasks» '
      'показывает выполненную задачу с меткой', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      // По одному действию на `runAsync` с `settle` после каждого: тест с
      // двумя записями в одном вызове зависал.
      final label = (await tester.runAsync(
        () => app.labels.add(name: 'home'),
      ))!;
      await settle(tester);
      final done = (await tester.runAsync(
        () => app.tasks.add(content: 'Done', labelIds: {label}),
      ))!;
      await settle(tester);
      await tester.runAsync(
        () => app.tasks.add(content: 'Open', labelIds: {label}),
      );
      await settle(tester);
      await tester.runAsync(() => app.tasks.complete(done));
      await settle(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(Sidebar),
          matching: find.text('Filters & Labels'),
        ),
      );
      await settle(tester);
      await tester.tap(find.text('home'));
      await settle(tester);
      expect(find.byType(LabelScreen), findsOneWidget);
      expect(row('Done'), findsNothing);

      await tester.tap(find.text('Display'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sorting'));
      await tester.pumpAndSettle();
      expect(find.text('Default'), findsWidgets);
      expect(find.text('Manual'), findsNothing);
      await tester.tap(find.byType(CheckboxMenuButton));
      await settle(tester);

      expect(rowsInOrder(tester, ['Done', 'Open']), ['Open', 'Done']);
    });
  });
}
