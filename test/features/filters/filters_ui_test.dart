import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:planner/features/filters/ui/filter_screen.dart';
import 'package:planner/features/labels/ui/filters_labels_screen.dart';
import 'package:planner/features/shell/ui/sidebar.dart';
import 'package:planner/features/tasks/ui/task_row.dart';

import '../../app/support/pump_app.dart';
import '../support/app_commands.dart';

// «Мои фильтры», окно фильтра и экран фильтра: сценарии пользователя (план
// M5 «M5.3»). Локаль — en.
void main() {
  Finder inSidebar(Finder f) =>
      find.descendant(of: find.byType(Sidebar), matching: f);

  Finder onScreen(Finder f) => find.descendant(
    of: find.byWidgetPredicate(
      (w) => w is FiltersLabelsScreen || w is FilterScreen,
    ),
    matching: f,
  );

  Finder row(String content) =>
      find.ancestor(of: find.text(content), matching: find.byType(TaskRow));

  Future<void> openFiltersLabels(WidgetTester tester) async {
    await tester.tap(inSidebar(find.text('Filters & Labels')));
    await settle(tester);
  }

  /// Поля окна: название — первое, запрос — второе.
  Finder field(int i) => find.byType(TextField).at(i);

  Future<String> addFilter(
    WidgetTester tester,
    AppCommands app, {
    required String name,
    required String query,
    bool favorite = false,
  }) async {
    final id = (await tester.runAsync(
      () => app.filters.add(name: name, query: query, isFavorite: favorite),
    ))!;
    await settle(tester);
    return id;
  }

  testWidgets('«+» у «My Filters»: ошибка запроса подсвечена и не даёт '
      'сохранить, предпросмотр по спискам, фильтр — в базе и в избранном', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await tester.runAsync(
        () => app.tasks.add(content: 'Urgent thing', priority: 1),
      );
      await settle(tester);
      await openFiltersLabels(tester);
      expect(find.text('My Filters'), findsOneWidget);
      expect(find.text('No filters yet'), findsOneWidget);

      await tester.tap(find.byTooltip('Add filter'));
      await tester.pumpAndSettle();
      // Ввод ограничен лимитами help «Usage limits» (О-80).
      expect(tester.widget<TextField>(field(0)).maxLength, 60);
      expect(tester.widget<TextField>(field(1)).maxLength, 1024);
      await tester.enterText(field(0), 'Important');
      await tester.enterText(field(1), 'p1 &');
      await tester.pump();
      expect(find.text('Unexpected “&”'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Add'))
            .onPressed,
        isNull,
      );

      await tester.enterText(field(1), 'p1, p2');
      await tester.pump();
      expect(find.text('Unexpected “&”'), findsNothing);
      expect(find.text('p1 — 1 task'), findsOneWidget);
      expect(find.text('p2 — No tasks'), findsOneWidget);
      await tester.tap(find.text('Add to favorites'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await settle(tester);

      final filter = (await tester.runAsync(app.read))!.filters.single;
      expect(filter.name, 'Important');
      expect(filter.query, 'p1, p2');
      expect(filter.isFavorite, isTrue);
      expect(onScreen(find.text('Important')), findsOneWidget);
      expect(inSidebar(find.text('Important')), findsOneWidget);
    });
  });

  testWidgets('экран фильтра: список на каждую часть через «,» с заголовком, '
      'только подходящие задачи; описание под именем', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      // По одной записи на `runAsync`: вторая запись в том же `runAsync`
      // ждала бы проснувшиеся потоки экранов вечно (conflict_fixtures.dart).
      for (final (content, priority) in [
        ('Red task', 1),
        ('Orange task', 2),
        ('Plain task', 4),
      ]) {
        await tester.runAsync(
          () => app.tasks.add(content: content, priority: priority),
        );
        await settle(tester);
      }
      await addFilter(tester, app, name: 'Top', query: 'p1, p2');
      await openFiltersLabels(tester);
      await tester.tap(onScreen(find.text('Top')));
      await settle(tester);

      expect(find.byType(FilterScreen), findsOneWidget);
      final p1 = tester.getTopLeft(find.byKey(const ValueKey('filterList-0')));
      final p2 = tester.getTopLeft(find.byKey(const ValueKey('filterList-1')));
      final red = tester.getTopLeft(row('Red task'));
      final orange = tester.getTopLeft(row('Orange task'));
      expect(p1.dy < red.dy && red.dy < p2.dy && p2.dy < orange.dy, isTrue);
      expect(row('Plain task'), findsNothing);

      await tester.tap(find.text('Add a description'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Самое важное');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await settle(tester);
      final ws = (await tester.runAsync(app.read))!;
      expect(ws.filters.single.description, 'Самое важное');
      expect(find.text('Самое важное'), findsOneWidget);
    });
  });

  testWidgets('«Add task» во втором списке — задача со значениями его части: '
      'проект, метка, приоритет (решение 1А)', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final work = (await tester.runAsync(
        () => app.projects.add(name: 'Work'),
      ))!;
      await settle(tester);
      final home = (await tester.runAsync(() => app.labels.add(name: 'home')))!;
      await settle(tester);
      await addFilter(
        tester,
        app,
        name: 'Mixed',
        query: 'p1, #Work & %home & p2',
      );
      await openFiltersLabels(tester);
      await tester.tap(onScreen(find.text('Mixed')));
      await settle(tester);

      await tester.tap(onScreen(find.text('Add task')).last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Task name'),
        'Paint fence',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);

      final ws = (await tester.runAsync(app.read))!;
      final added = ws.children(null, projectId: work).single;
      expect(added.content, 'Paint fence');
      expect(added.labelIds, [home]);
      expect(added.priority, 2);
      expect(row('Paint fence'), findsOneWidget);
    });
  });

  testWidgets('стрелка у задачи с подзадачами раскрывает их только на экране: '
      'в данных задача не свёрнута и не развёрнута (решение 2А)', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final parent = (await tester.runAsync(
        () => app.tasks.add(content: 'Parent', priority: 1),
      ))!;
      await settle(tester);
      await tester.runAsync(
        () => app.tasks.add(content: 'Child', parentId: parent),
      );
      await settle(tester);
      await addFilter(tester, app, name: 'Top', query: 'p1');
      final before = (await tester.runAsync(device.ownOps))!.length;
      await openFiltersLabels(tester);
      await tester.tap(onScreen(find.text('Top')));
      await settle(tester);

      expect(row('Child'), findsNothing);
      await tester.tap(onScreen(find.byIcon(Icons.chevron_right)));
      await settle(tester);
      expect(row('Child'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Child')).dx,
        greaterThan(tester.getTopLeft(find.text('Parent')).dx),
      );
      await tester.tap(onScreen(find.byIcon(Icons.expand_more)));
      await settle(tester);
      expect(row('Child'), findsNothing);
      expect((await tester.runAsync(device.ownOps))!.length, before);
    });
    // Раскрытие — только на компьютере (help); тесты по умолчанию — Android.
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('подзадача тоже в списке: под раскрытым родителем — одна строка, '
      'своей строкой не повторяется', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final parent = (await tester.runAsync(
        () => app.tasks.add(content: 'Parent', priority: 1),
      ))!;
      await settle(tester);
      await tester.runAsync(
        () => app.tasks.add(content: 'Child', parentId: parent, priority: 1),
      );
      await settle(tester);
      await addFilter(tester, app, name: 'Top', query: 'p1');
      await openFiltersLabels(tester);
      await tester.tap(onScreen(find.text('Top')));
      await settle(tester);
      expect(row('Child'), findsOneWidget);

      await tester.tap(onScreen(find.byIcon(Icons.chevron_right)));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(row('Child'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Child')).dx,
        greaterThan(tester.getTopLeft(find.text('Parent')).dx),
      );
    });
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('на телефоне задачу в фильтре не раскрыть — стрелки нет', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final parent = (await tester.runAsync(
        () => app.tasks.add(content: 'Parent', priority: 1),
      ))!;
      await settle(tester);
      await tester.runAsync(
        () => app.tasks.add(content: 'Child', parentId: parent),
      );
      await settle(tester);
      await addFilter(tester, app, name: 'Top', query: 'p1');
      GoRouter.of(
        tester.element(find.byType(Scaffold).first),
      ).go('/filter/${(await tester.runAsync(app.read))!.filters.single.id}');
      await settle(tester);
      expect(row('Parent'), findsOneWidget);
      expect(onScreen(find.byIcon(Icons.chevron_right)), findsNothing);
      expect(onScreen(find.byIcon(Icons.expand_more)), findsNothing);
      // Счётчик подзадач не сворачивает: в данные ничего не пишется.
      final before = (await tester.runAsync(device.ownOps))!.length;
      await tester.tap(onScreen(find.text('0/1')));
      await settle(tester);
      expect((await tester.runAsync(device.ownOps))!.length, before);
    });
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('меню фильтра: изменить, дублировать, удалить с подтверждением '
      '— с экрана удалённого фильтра уходим на «Filters & Labels»', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final id = await addFilter(tester, app, name: 'Mine', query: 'p1');
      await openFiltersLabels(tester);
      await tester.tap(onScreen(find.text('Mine')));
      await settle(tester);
      Finder menu() => onScreen(find.byTooltip('More actions')).first;

      await tester.tap(menu());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit filter'));
      await tester.pumpAndSettle();
      await tester.enterText(field(0), 'Ours');
      await tester.enterText(field(1), 'p1 | p2');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await settle(tester);
      var ws = (await tester.runAsync(app.read))!;
      expect(ws.filter(id)!.name, 'Ours');
      expect(ws.filter(id)!.query, 'p1 | p2');

      await tester.tap(menu());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Duplicate'));
      await settle(tester);
      ws = (await tester.runAsync(app.read))!;
      expect([for (final f in ws.filters) f.name], ['Ours', 'Copy of Ours']);

      await tester.tap(menu());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete filter'));
      await tester.pumpAndSettle();
      expect(find.text('Delete filter?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await settle(tester);
      ws = (await tester.runAsync(app.read))!;
      expect([for (final f in ws.filters) f.name], ['Copy of Ours']);
      expect(find.byType(FiltersLabelsScreen), findsOneWidget);
    });
  });

  testWidgets('«Edit filter» пишет только изменённые поля: запрос, сменённый '
      'с другого устройства, пока окно открыто, не затирается', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final id = await addFilter(tester, app, name: 'Mine', query: 'p1');
      await openFiltersLabels(tester);
      await tester.tap(onScreen(find.text('Mine')));
      await settle(tester);
      await tester.tap(onScreen(find.byTooltip('More actions')).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit filter'));
      await tester.pumpAndSettle();

      await tester.runAsync(() => app.filters.edit(id, query: 'p2'));
      await settle(tester);
      await tester.enterText(field(0), 'Ours');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await settle(tester);
      final filter = (await tester.runAsync(app.read))!.filter(id)!;
      expect(filter.name, 'Ours');
      expect(filter.query, 'p2');
    });
  });

  testWidgets('запрос с ошибкой (с другого устройства) — текст ошибки и '
      '«Edit filter» открывает окно', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await addFilter(tester, app, name: 'Broken', query: '(p1');
      await openFiltersLabels(tester);
      await tester.tap(onScreen(find.text('Broken')));
      await settle(tester);

      expect(find.text('The filter query has an error'), findsOneWidget);
      expect(find.text('Unclosed parenthesis'), findsOneWidget);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Edit filter'));
      await tester.pumpAndSettle();
      expect(find.text('Edit filter'), findsWidgets);
      expect(find.widgetWithText(TextField, '(p1'), findsOneWidget);
    });
  });

  testWidgets('«Отображение» фильтра — без «Completed tasks»: фильтр '
      'показывает только активные задачи', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await addFilter(tester, app, name: 'All', query: 'view all');
      await openFiltersLabels(tester);
      await tester.tap(onScreen(find.text('All')));
      await settle(tester);
      await tester.tap(find.textContaining('Display'));
      await tester.pumpAndSettle();
      expect(find.text('Sorting'), findsOneWidget);
      expect(find.text('Completed tasks'), findsNothing);
    });
  });

  testWidgets('Ctrl+Shift+F — окно «Add filter»', (tester) async {
    await withApp(tester, (device) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AlertDialog, 'Add filter'), findsOneWidget);
    });
  });

  testWidgets('перетаскивание в «My Filters» меняет порядок', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await addFilter(tester, app, name: 'First', query: 'p1');
      await addFilter(tester, app, name: 'Second', query: 'p2');
      await openFiltersLabels(tester);
      final from = tester.getCenter(onScreen(find.text('Second')));
      final to = tester.getTopLeft(onScreen(find.text('First')));
      final mouse = await tester.startGesture(
        from,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      await mouse.moveTo(from + const Offset(0, -8));
      await tester.pump();
      await mouse.moveTo(Offset(from.dx, to.dy + 2));
      await tester.pump();
      await mouse.up();
      await settle(tester);
      final ws = (await tester.runAsync(app.read))!;
      expect([for (final f in ws.filters) f.name], ['Second', 'First']);
    });
  });
}
