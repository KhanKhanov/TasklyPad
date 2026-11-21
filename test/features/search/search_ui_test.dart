import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:planner/features/search/ui/search_list.dart';
import 'package:planner/features/search/ui/search_tiles.dart';
import 'package:planner/features/search/ui/search_window.dart';
import 'package:planner/features/shell/ui/app_shell.dart';
import 'package:planner/features/tasks/ui/task_dialog.dart';

import '../../app/support/pump_app.dart';
import '../support/app_commands.dart';

// Окно «Поиск» (help «Introduction to search»; решения 1А–3А plans/m5
// «Решения M5.4»): открытие клавишами и пунктом сайдбара, до ввода —
// недавние запросы, недавно просмотренное, команды с клавишами; ↑/↓, Enter,
// Esc; команды при вводе. Локаль — en.
void main() {
  String location(WidgetTester tester) =>
      GoRouter.of(tester.element(find.byType(AppShell)))
          .routerDelegate
          .currentConfiguration
          .uri
          .toString();

  Future<void> key(
    WidgetTester tester,
    LogicalKeyboardKey key, {
    LogicalKeyboardKey? modifier,
  }) async {
    if (modifier != null) await tester.sendKeyDownEvent(modifier);
    await tester.sendKeyEvent(key);
    if (modifier != null) await tester.sendKeyUpEvent(modifier);
    await tester.pumpAndSettle();
  }

  /// Поле окна — пустое и в фокусе.
  void expectOpenEmpty(WidgetTester tester) {
    expect(find.byType(SearchWindow), findsOneWidget);
    final field = tester.widget<TextField>(
      find.descendant(
        of: find.byType(SearchWindow),
        matching: find.byType(TextField),
      ),
    );
    expect(field.controller!.text, isEmpty);
    expect(field.focusNode?.hasFocus ?? true, isTrue);
  }

  testWidgets('`/`, `f`, `Ctrl+F`, `Ctrl+K` открывают пустое окно; Esc '
      'закрывает', (tester) async {
    await withApp(tester, (device) async {
      const ctrl = LogicalKeyboardKey.controlLeft;
      for (final (k, mod) in [
        (LogicalKeyboardKey.slash, null),
        (LogicalKeyboardKey.keyF, null),
        (LogicalKeyboardKey.keyF, ctrl),
        (LogicalKeyboardKey.keyK, ctrl),
      ]) {
        await key(tester, k, modifier: mod);
        expectOpenEmpty(tester);
        await key(tester, LogicalKeyboardKey.escape);
        expect(find.byType(SearchWindow), findsNothing, reason: '$k');
      }
    });
  });

  testWidgets('русская раскладка: `/` — Shift и клавиша `\\` — открывает '
      'окно; Shift+F — нет', (tester) async {
    await withApp(tester, (device) async {
      const shift = LogicalKeyboardKey.shiftLeft;
      await tester.sendKeyDownEvent(shift);
      await tester.sendKeyEvent(LogicalKeyboardKey.backslash, character: '/');
      await tester.sendKeyUpEvent(shift);
      await tester.pumpAndSettle();
      expectOpenEmpty(tester);
      await key(tester, LogicalKeyboardKey.escape);

      await key(tester, LogicalKeyboardKey.keyF, modifier: shift);
      expect(find.byType(SearchWindow), findsNothing);
    });
  });

  testWidgets('русская раскладка: клавиша `/`, которая печатает `.`, '
      'открывает окно — и при задаче в фокусе вместо «ещё действий»', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      Future<void> slashKey() async {
        await tester.sendKeyEvent(
          LogicalKeyboardKey.period,
          physicalKey: PhysicalKeyboardKey.slash,
          character: '.',
        );
        await tester.pumpAndSettle();
      }

      await slashKey();
      expectOpenEmpty(tester);
      await key(tester, LogicalKeyboardKey.escape);

      final app = AppCommands(device);
      await tester.runAsync(() => app.tasks.add(content: 'Buy milk'));
      await settle(tester);
      await key(tester, LogicalKeyboardKey.keyJ);
      await slashKey();
      expectOpenEmpty(tester);
      expect(find.text('Move to…'), findsNothing);
      await key(tester, LogicalKeyboardKey.escape);

      // Настоящая `.` — по-прежнему «ещё действия».
      await key(tester, LogicalKeyboardKey.period);
      expect(find.text('Move to…'), findsOneWidget);
      expect(find.byType(SearchWindow), findsNothing);
    });
  });

  testWidgets('пункт «Search» сайдбара открывает окно', (tester) async {
    await withApp(tester, (device) async {
      await tester.tap(find.text('Search').first);
      await tester.pumpAndSettle();
      expectOpenEmpty(tester);
    });
  });

  testWidgets('в поле быстрого добавления `f` печатается, окно не '
      'открывается', (tester) async {
    await withApp(tester, (device) async {
      await key(tester, LogicalKeyboardKey.keyQ);
      await tester.enterText(find.byType(TextField).first, 'f');
      await key(tester, LogicalKeyboardKey.keyF);
      expect(find.byType(SearchWindow), findsNothing);
    });
  });

  testWidgets('до ввода — команды с клавишами: «Ctrl+Shift+F» у нового '
      'фильтра, «Alt+P» у нового проекта, «Ctrl+Shift+L» у новой метки', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      await key(
        tester,
        LogicalKeyboardKey.keyK,
        modifier: LogicalKeyboardKey.controlLeft,
      );
      expect(find.text('Commands'), findsOneWidget);
      expect(find.text('G, then T'), findsOneWidget);
      expect(find.text('Ctrl+Shift+F'), findsOneWidget);
      expect(find.text('Add project'), findsOneWidget);
      expect(find.text('Alt+P'), findsOneWidget);
      expect(find.text('Ctrl+Shift+L'), findsOneWidget);
    });
  });

  testWidgets('ввод «upc» — команда «Upcoming» группой; Enter — переход', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      await key(tester, LogicalKeyboardKey.slash);
      await tester.enterText(find.byType(TextField).last, 'upc');
      await tester.pumpAndSettle();
      expect(find.text('Commands'), findsOneWidget);
      await key(tester, LogicalKeyboardKey.enter);
      expect(find.byType(SearchWindow), findsNothing);
      expect(location(tester), '/upcoming');
    });
  });

  testWidgets('↓ и Enter — задача открывается окном задачи; запрос и задача '
      '— в недавних при новом открытии', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await tester.runAsync(() => app.tasks.add(content: 'Buy milk'));
      await settle(tester);

      await key(tester, LogicalKeyboardKey.slash);
      await tester.enterText(find.byType(TextField).last, 'milk');
      await tester.pumpAndSettle();
      // Первая строка — «Лучшие совпадения»: команд под «milk» нет.
      await key(tester, LogicalKeyboardKey.enter);
      await settle(tester);
      expect(find.byType(TaskDialog), findsOneWidget);
      await key(tester, LogicalKeyboardKey.escape);
      await settle(tester);

      await key(tester, LogicalKeyboardKey.slash);
      await settle(tester);
      // Задача видна и в списке «Входящих» за окном — ищем только в окне.
      Finder inWindow(Finder f) =>
          find.descendant(of: find.byType(SearchWindow), matching: f);
      expect(inWindow(find.text('Recent searches')), findsOneWidget);
      expect(inWindow(find.text('milk')), findsOneWidget);
      expect(inWindow(find.text('Recently viewed')), findsOneWidget);
      expect(inWindow(find.text('Buy milk')), findsOneWidget);

      // ↓ — к недавнему запросу, Enter подставляет его в строку.
      await key(tester, LogicalKeyboardKey.arrowDown);
      await key(tester, LogicalKeyboardKey.enter);
      final field = tester.widget<TextField>(find.byType(TextField).last);
      expect(field.controller!.text, 'milk');
    });
  });

  testWidgets('экраны — в «Recently viewed», новый сверху; выбор — переход', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await tester.runAsync(() => app.projects.add(name: 'Garden'));
      await settle(tester);
      await tester.tap(find.text('Garden').first);
      await settle(tester);
      await key(tester, LogicalKeyboardKey.keyG);
      await key(tester, LogicalKeyboardKey.keyT);
      await settle(tester);
      expect(location(tester), '/today');

      await key(tester, LogicalKeyboardKey.slash);
      await settle(tester);
      final viewed = [
        for (final t in ['Today', 'Garden', 'Inbox'])
          tester.getTopLeft(find.widgetWithText(SearchTile, t).first).dy,
      ];
      expect(viewed, orderedEquals([...viewed]..sort()));

      await tester.tap(find.widgetWithText(SearchTile, 'Garden').first);
      await settle(tester);
      expect(find.byType(SearchWindow), findsNothing);
      expect(location(tester), startsWith('/project/'));
    });
  });

  testWidgets('↓ по длинному списку — выбранная строка видна в окне', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      for (var i = 0; i < 40; i++) {
        await tester.runAsync(() => app.tasks.add(content: 'Item $i'));
        await settle(tester);
      }
      await key(tester, LogicalKeyboardKey.slash);
      await tester.enterText(find.byType(TextField).last, 'item');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();
      for (var i = 0; i < 35; i++) {
        await key(tester, LogicalKeyboardKey.arrowDown);
      }
      final selected = find.byWidgetPredicate(
        (w) => w is SearchTile && w.selected,
      );
      expect(selected, findsOneWidget);
      final list = tester.getRect(find.byType(SearchList));
      final row = tester.getRect(selected);
      expect(row.top, greaterThanOrEqualTo(list.top));
      expect(row.bottom, lessThanOrEqualTo(list.bottom));
    });
  });

  testWidgets('крестик убирает запрос, «Clear» — все', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await tester.runAsync(() => app.recentSearches.add('one'));
      await settle(tester);
      await tester.runAsync(() => app.recentSearches.add('two'));
      await settle(tester);
      await key(tester, LogicalKeyboardKey.slash);
      await settle(tester);
      expect(find.text('two'), findsOneWidget);

      await tester.tap(find.byTooltip('Remove search').first);
      await settle(tester);
      expect(find.text('two'), findsNothing);
      expect(find.text('one'), findsOneWidget);

      await tester.tap(find.text('Clear'));
      await settle(tester);
      expect(find.text('Recent searches'), findsNothing);
      expect(await tester.runAsync(app.settings.recentSearches), isEmpty);
    });
  });
}
