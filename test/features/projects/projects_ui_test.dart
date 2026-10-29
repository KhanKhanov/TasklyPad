import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../app/support/pump_app.dart';
import '../support/app_commands.dart';

// Экраны проектов и разделов: сценарии пользователя. Локаль тестов — en.
void main() {
  Future<void> openMenuItem(WidgetTester tester, String item) async {
    await tester.tap(find.text(item).last);
    await settle(tester);
  }

  testWidgets('добавить проект из сайдбара → он в сайдбаре и открывается', (
    tester,
  ) async {
    await withApp(tester, (_) async {
      await tester.tap(find.byTooltip('Add project'));
      await tester.pumpAndSettle();
      expect(find.text('Add project'), findsWidgets);

      await tester.enterText(find.byType(TextField), 'Work');
      await tester.pump(); // кнопка «Add» становится активной в новом кадре
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await settle(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Work'), findsOneWidget);
      await tester.tap(find.text('Work'));
      await settle(tester);
      expect(find.text('Work'), findsNWidgets(2)); // сайдбар и заголовок
    });
  });

  testWidgets('переименовать проект через «Редактировать»', (tester) async {
    await withApp(tester, (device) async {
      final id = (await tester.runAsync(
        () => AppCommands(device).projects.add(name: 'Work'),
      ))!;
      await settle(tester);
      await tester.tap(find.text('Work'));
      await settle(tester);
      expect(id, isNotEmpty);

      await tester.tap(screenMenu());
      await tester.pumpAndSettle();
      await openMenuItem(tester, 'Edit');
      await tester.enterText(find.byType(TextField), 'Home');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await settle(tester);

      expect(find.text('Home'), findsNWidgets(2));
      expect(find.text('Work'), findsNothing);
    });
  });

  testWidgets('архивировать проект с подтверждением → уходит из сайдбара, '
      'в «Мои проекты → Только архивные проекты» возвращается', (tester) async {
    await withApp(tester, (device) async {
      await tester.runAsync(
        () => AppCommands(device).projects.add(name: 'Work'),
      );
      await settle(tester);
      await tester.tap(find.text('Work'));
      await settle(tester);

      await tester.tap(screenMenu());
      await tester.pumpAndSettle();
      await openMenuItem(tester, 'Archive');
      expect(find.text('Archive project?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Archive'));
      await settle(tester);
      expect(find.text('Work'), findsNothing);
      expect(find.text('Inbox'), findsNWidgets(2)); // ушли на «Входящие»

      await tester.tap(find.text('My Projects'));
      await settle(tester);
      await tester.tap(find.text('Archived projects only'));
      await tester.pumpAndSettle();
      expect(find.text('Work'), findsOneWidget);
      await tester.tap(screenMenu());
      await tester.pumpAndSettle();
      await openMenuItem(tester, 'Unarchive');
      expect(find.text('No archived projects'), findsOneWidget);
      expect(find.text('Work'), findsOneWidget); // снова в сайдбаре
    });
  });

  testWidgets('удалить проект — только после подтверждения', (tester) async {
    await withApp(tester, (device) async {
      await tester.runAsync(
        () => AppCommands(device).projects.add(name: 'Work'),
      );
      await settle(tester);
      await tester.tap(find.text('Work'));
      await settle(tester);

      await tester.tap(screenMenu());
      await tester.pumpAndSettle();
      await openMenuItem(tester, 'Delete');
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(find.text('Work'), findsNWidgets(2));

      await tester.tap(screenMenu());
      await tester.pumpAndSettle();
      await openMenuItem(tester, 'Delete');
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await settle(tester);
      expect(find.text('Work'), findsNothing);
    });
  });

  testWidgets('раздел: добавить, переименовать, удалить с подтверждением', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      await tester.runAsync(
        () => AppCommands(device).projects.add(name: 'Work'),
      );
      await settle(tester);
      await tester.tap(find.text('Work'));
      await settle(tester);

      await tester.tap(find.text('Add section'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Week');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);
      expect(find.text('Week'), findsOneWidget);

      await tester.tap(find.text('Week'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Sprint');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await settle(tester);
      expect(find.text('Sprint'), findsOneWidget);

      await tester.tap(find.byTooltip('More actions').last);
      await tester.pumpAndSettle();
      await openMenuItem(tester, 'Delete');
      expect(find.text('Delete section?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await settle(tester);
      expect(find.text('Sprint'), findsNothing);
    });
  });

  testWidgets('архивный раздел виден только при «Completed tasks», серым; '
      '«Unarchive» возвращает его', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final work = (await tester.runAsync(
        () => app.projects.add(name: 'Work'),
      ))!;
      await settle(tester);
      final week = (await tester.runAsync(
        () => app.sections.add(work, name: 'Week'),
      ))!;
      await settle(tester);
      await tester.runAsync(() => app.sections.archive(week));
      await settle(tester);
      await tester.tap(find.text('Work'));
      await settle(tester);
      expect(find.text('Week'), findsNothing);

      await tester.tap(find.byTooltip('Display'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(CheckedPopupMenuItem<void>, 'Completed tasks'),
      );
      await settle(tester);
      expect(find.text('Week'), findsOneWidget);
      // У архивного раздела нет «Добавить задачу»: кнопка одна — у задач
      // без раздела.
      expect(find.text('Add task'), findsOneWidget);

      await tester.tap(find.byTooltip('More actions').last);
      await tester.pumpAndSettle();
      expect(find.text('Archive'), findsNothing);
      expect(find.text('Edit'), findsNothing);
      expect(find.text('Delete'), findsOneWidget);
      await openMenuItem(tester, 'Unarchive');
      expect(
        (await tester.runAsync(app.read))!.section(week)!.isArchived,
        isFalse,
      );
    });
  });

  testWidgets('избранный проект — в группе «Избранное»; стрелка сворачивает '
      'подпроекты', (tester) async {
    await withApp(tester, (device) async {
      // Каждая запись — отдельным runAsync с кадром между ними: снимок
      // перестраивается в «ненастоящем» времени теста, и вторая запись
      // ждала бы его транзакцию внутри того же runAsync.
      final app = AppCommands(device);
      final work = (await tester.runAsync(
        () => app.projects.add(name: 'Work', isFavorite: true),
      ))!;
      await settle(tester);
      await tester.runAsync(
        () => app.projects.add(name: 'Reports', parentId: work),
      );
      await settle(tester);

      expect(find.text('Favorites'), findsOneWidget);
      expect(find.text('Work'), findsNWidgets(2)); // избранное и дерево
      expect(find.text('Reports'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.expand_more).first);
      await settle(tester);
      expect(find.text('Reports'), findsNothing);
      await tester.tap(find.byIcon(Icons.chevron_right).first);
      await settle(tester);
      expect(find.text('Reports'), findsOneWidget);
    });
  });
}
