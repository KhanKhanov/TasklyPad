import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:planner/domain/view_options.dart';
import 'package:planner/features/filters/ui/filter_screen.dart';
import 'package:planner/features/labels/ui/label_screen.dart';
import 'package:planner/features/projects/ui/project_screen.dart';

import '../features/support/app_commands.dart';
import 'support/pump_app.dart';

// Переход на другой проект, метку или фильтр по тому же маршруту: go_router
// ключует страницу шаблоном пути, и без ключа экрана по id открытый редактор
// «Добавить задачу» с черновиком переходил бы в новую сущность и брал её
// значения. Локаль — en.
void main() {
  void go(WidgetTester tester, String location) =>
      GoRouter.of(tester.element(find.byType(Scaffold).first)).go(location);

  Finder draft(String text) => find.widgetWithText(TextField, text);

  Future<void> groupByPriority(
    WidgetTester tester,
    AppCommands app,
    String filterId,
  ) async {
    final view = ViewOptions(viewType: ViewType.filter, objectId: filterId);
    await tester.runAsync(
      () => app.views.save(view, view.copyWith(grouping: Grouping.priority)),
    );
    await settle(tester);
  }

  /// Открывает «Add task» первой группы экрана фильтра и набирает черновик.
  Future<void> typeDraftInGroup(WidgetTester tester) async {
    await tester.tap(
      find
          .descendant(
            of: find.byType(FilterScreen),
            matching: find.text('Add task'),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Task name'), 'Half');
    await tester.pump();
    expect(draft('Half'), findsOneWidget);
  }

  testWidgets('другой фильтр с группировкой — редактор группы не переходит в '
      'него', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await tester.runAsync(
        () => app.tasks.add(content: 'Urgent', priority: 1),
      );
      await settle(tester);
      final a = (await tester.runAsync(
        () => app.filters.add(name: 'A', query: 'p1'),
      ))!;
      await settle(tester);
      final b = (await tester.runAsync(
        () => app.filters.add(name: 'B', query: 'p1 | p2'),
      ))!;
      await settle(tester);
      await groupByPriority(tester, app, a);
      await groupByPriority(tester, app, b);
      go(tester, '/filter/$a');
      await settle(tester);
      await typeDraftInGroup(tester);

      go(tester, '/filter/$b');
      await settle(tester);
      expect(find.text('Urgent'), findsOneWidget);
      expect(draft('Half'), findsNothing);
      expect(find.widgetWithText(TextField, 'Task name'), findsNothing);
    });
  });

  testWidgets('запрос открытого фильтра сменился (другое устройство) — '
      'редактор группы закрывается', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await tester.runAsync(
        () => app.tasks.add(content: 'Urgent', priority: 1),
      );
      await settle(tester);
      final a = (await tester.runAsync(
        () => app.filters.add(name: 'A', query: 'p1'),
      ))!;
      await settle(tester);
      await groupByPriority(tester, app, a);
      go(tester, '/filter/$a');
      await settle(tester);
      await typeDraftInGroup(tester);

      await tester.runAsync(() => app.filters.edit(a, query: 'p1 | p2'));
      await settle(tester);
      expect(find.text('Urgent'), findsOneWidget);
      expect(draft('Half'), findsNothing);
    });
  });

  testWidgets('другая метка — редактор «Add task» с черновиком не переходит в '
      'неё', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final home = (await tester.runAsync(() => app.labels.add(name: 'home')))!;
      await settle(tester);
      final work = (await tester.runAsync(() => app.labels.add(name: 'work')))!;
      await settle(tester);
      go(tester, '/label/$home');
      await settle(tester);
      await tester.tap(
        find
            .descendant(
              of: find.byType(LabelScreen),
              matching: find.text('Add task'),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Task name'),
        'Half',
      );
      await tester.pump();
      expect(draft('Half'), findsOneWidget);

      go(tester, '/label/$work');
      await settle(tester);
      expect(draft('Half'), findsNothing);
      expect(find.widgetWithText(TextField, 'Task name'), findsNothing);
    });
  });

  testWidgets('другой проект — редактор «Add task» с черновиком не переходит в '
      'него', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final work = (await tester.runAsync(
        () => app.projects.add(name: 'Work'),
      ))!;
      await settle(tester);
      final home = (await tester.runAsync(
        () => app.projects.add(name: 'Home'),
      ))!;
      await settle(tester);
      go(tester, '/project/$work');
      await settle(tester);
      await tester.tap(
        find
            .descendant(
              of: find.byType(ProjectScreen),
              matching: find.text('Add task'),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Task name'),
        'Half',
      );
      await tester.pump();
      expect(draft('Half'), findsOneWidget);

      go(tester, '/project/$home');
      await settle(tester);
      expect(draft('Half'), findsNothing);
      expect(find.widgetWithText(TextField, 'Task name'), findsNothing);
    });
  });
}
