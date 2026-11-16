import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:planner/features/search/ui/search_tiles.dart';
import 'package:planner/features/search/ui/search_window.dart';
import 'package:planner/features/shell/ui/app_shell.dart';

import '../../app/support/pump_app.dart';
import '../support/app_commands.dart';

// Результаты окна «Поиск» (help «Introduction to search»; решения 5А, 6А
// plans/m5): вкладки, проект и метка — переход, запрос фильтра — без «Search
// completed tasks», выполненные — под активными, «Save as filter» — окно
// фильтра с запросом; телефон — весь экран без подсказок клавиш. Локаль — en.
void main() {
  String location(WidgetTester tester) =>
      GoRouter.of(tester.element(find.byType(AppShell)))
          .routerDelegate
          .currentConfiguration
          .uri
          .toString();

  Future<void> search(WidgetTester tester, String text) async {
    await tester.sendKeyEvent(LogicalKeyboardKey.slash);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, text);
    await tester.pumpAndSettle();
  }

  Finder inWindow(Finder f) =>
      find.descendant(of: find.byType(SearchWindow), matching: f);

  testWidgets('проект и метка находятся; выбор — переход на их экран', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final project = (await tester.runAsync(
        () => app.projects.add(name: 'Garden'),
      ))!;
      await settle(tester);
      final label = (await tester.runAsync(
        () => app.labels.add(name: 'gardening'),
      ))!;
      await settle(tester);

      await search(tester, 'garden');
      expect(inWindow(find.text('Top')), findsOneWidget);
      expect(inWindow(find.text('Projects')), findsOneWidget);
      await tester.tap(inWindow(find.text('Garden')));
      await settle(tester);
      expect(location(tester), '/project/$project');

      // Строка результата, а не тот же текст в поле ввода.
      await search(tester, 'gardening');
      await tester.tap(find.widgetWithText(SearchTile, 'gardening'));
      await settle(tester);
      expect(location(tester), '/label/$label');
    });
  });

  testWidgets('совпадение только в описании — во вкладке «Task '
      'descriptions»', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await tester.runAsync(
        () => app.tasks.add(content: 'Call', description: 'about budget'),
      );
      await settle(tester);
      await search(tester, 'budget');
      expect(inWindow(find.text('Task descriptions')), findsOneWidget);
      expect(inWindow(find.text('Call')), findsOneWidget);
    });
  });

  testWidgets('`p1` — запрос фильтра: задачи P1, без «Search completed '
      'tasks»', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final id = (await tester.runAsync(
        () => app.tasks.add(content: 'Urgent'),
      ))!;
      await settle(tester);
      await tester.runAsync(() => app.tasks.setPriority(id, 1));
      await settle(tester);
      await tester.runAsync(() => app.tasks.add(content: 'Calm'));
      await settle(tester);

      await search(tester, 'p1');
      expect(inWindow(find.text('Urgent')), findsOneWidget);
      expect(inWindow(find.text('Calm')), findsNothing);
      expect(inWindow(find.text('Search completed tasks')), findsNothing);
      expect(inWindow(find.text('Save as filter')), findsOneWidget);
    });
  });

  testWidgets('«Search completed tasks» — выполненные под активными', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final done = (await tester.runAsync(
        () => app.tasks.add(content: 'Report old'),
      ))!;
      await settle(tester);
      await tester.runAsync(() => app.tasks.complete(done));
      await settle(tester);
      await tester.runAsync(() => app.tasks.add(content: 'Report new'));
      await settle(tester);

      await search(tester, 'report');
      expect(inWindow(find.text('Report old')), findsNothing);
      await tester.tap(inWindow(find.text('Search completed tasks')));
      await tester.pumpAndSettle();
      expect(inWindow(find.text('Completed tasks')), findsOneWidget);
      final active = tester.getTopLeft(inWindow(find.text('Report new'))).dy;
      final completed = tester.getTopLeft(inWindow(find.text('Report old'))).dy;
      expect(completed, greaterThan(active));
    });
  });

  testWidgets('«Save as filter» — окно фильтра с запросом `search: …`', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      await search(tester, 'milk, bread');
      await tester.tap(inWindow(find.text('Save as filter')));
      await settle(tester);
      expect(find.byType(SearchWindow), findsNothing);
      expect(find.text(r'search: milk\, bread'), findsOneWidget);
    });
  });

  testWidgets('телефон — окно во весь экран, команды без подсказок клавиш', (
    tester,
  ) async {
    await withApp(tester, size: const Size(400, 800), (device) async {
      await tester.tap(find.byTooltip('Open or close sidebar').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Search').first);
      await tester.pumpAndSettle();
      expect(find.byType(SearchWindow), findsOneWidget);
      expect(
        find.ancestor(
          of: find.byType(SearchWindow),
          matching: find.byWidgetPredicate(
            (w) => w is Dialog && w.insetPadding == EdgeInsets.zero,
          ),
        ),
        findsOneWidget,
      );
      expect(find.text('Commands'), findsOneWidget);
      expect(find.text('G, then T'), findsNothing);
    });
  });
}
