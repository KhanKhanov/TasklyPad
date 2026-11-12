import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/features/tasks/ui/task_dialog.dart';

import '../../app/support/pump_app.dart';
import '../support/app_commands.dart';

// «Показать выполненные» подзадач в панели задачи запоминается для задачи и
// синхронизируется (решение 1Б «M4.10a» plans/m4). Локаль — en.
void main() {
  Finder inPanel(String text) =>
      find.descendant(of: find.byType(TaskDialog), matching: find.text(text));

  testWidgets('«Show completed» подзадач — панель закрыли и открыли снова → '
      'выполненные видны (решение 1Б «M4.10a»)', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final parent = (await tester.runAsync(
        () => app.tasks.add(content: 'Buy milk'),
      ))!;
      // Между записями — кадр: поток базы должен ответить экрану.
      await settle(tester);
      final child = (await tester.runAsync(
        () => app.tasks.add(content: 'Oat', parentId: parent),
      ))!;
      await settle(tester);
      await tester.runAsync(() => app.tasks.complete(child));
      await settle(tester);

      Future<void> open() async {
        await tester.tap(find.text('Buy milk'));
        await settle(tester);
      }

      await open();
      expect(inPanel('Oat'), findsNothing);
      await tester.tap(inPanel('Show completed'));
      await settle(tester);
      expect(inPanel('Oat'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(find.byType(TaskDialog), findsNothing);
      await open();
      expect(inPanel('Oat'), findsOneWidget);
      expect(inPanel('Hide completed'), findsOneWidget);
    });
  });
}
