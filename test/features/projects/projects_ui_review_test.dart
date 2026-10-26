import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/features/projects/ui/project_tile.dart';

import '../../app/support/pump_app.dart';
import '../support/app_commands.dart';

// Сценарии, найденные ревью M2.2 (коммит 1). Локаль тестов — en.
void main() {
  /// Меню «⋯» строки проекта [name] в сайдбаре.
  Finder tileMenu(String name) => find.descendant(
    of: find.ancestor(of: find.text(name), matching: find.byType(ProjectTile)),
    matching: find.byTooltip('More actions'),
  );

  testWidgets('меню «⋯» в сайдбаре по наведению мыши срабатывает: архив с '
      'подтверждением', (tester) async {
    await withApp(tester, (device) async {
      await tester.runAsync(
        () => AppCommands(device).projects.add(name: 'Work'),
      );
      await settle(tester);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.text('Work')));
      await tester.pumpAndSettle();

      await tester.tap(tileMenu('Work'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archive').last);
      await settle(tester);
      expect(find.text('Archive project?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Archive'));
      await settle(tester);
      expect(find.text('Work'), findsNothing);
    });
  });

  testWidgets('«Сохранить» в диалоге пишет только изменённое: цвет, '
      'пришедший с другого устройства при открытом диалоге, не затирается', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final id = (await tester.runAsync(() => app.projects.add(name: 'Work')))!;
      await settle(tester);
      await tester.tap(find.text('Work'));
      await settle(tester);
      await tester.tap(screenMenu());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit').last);
      await tester.pumpAndSettle();

      // Пока диалог открыт, «другое устройство» меняет цвет.
      await tester.runAsync(() => app.projects.setColor(id, 'blue'));
      await settle(tester);

      await tester.enterText(find.byType(TextField), 'Home');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await settle(tester);

      final ws = (await tester.runAsync(app.read))!;
      expect(ws.project(id)!.name, 'Home');
      expect(ws.project(id)!.color, 'blue');
    });
  });

  testWidgets('узкое окно: переход из выдвижной панели закрывает её', (
    tester,
  ) async {
    await withApp(tester, size: const Size(420, 800), (device) async {
      await tester.runAsync(
        () => AppCommands(device).projects.add(name: 'Work'),
      );
      await settle(tester);
      await tester.tap(find.byTooltip('Open or close sidebar'));
      await tester.pumpAndSettle();
      expect(find.byType(Drawer), findsOneWidget);

      await tester.tap(find.text('Work'));
      await settle(tester);
      expect(find.byType(Drawer), findsNothing);
      expect(find.text('Work'), findsOneWidget); // заголовок экрана
    });
  });

  testWidgets('удаление родителя открытого подпроекта — переход на '
      '«Входящие», а не «Не найдено»', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final work = (await tester.runAsync(
        () => app.projects.add(name: 'Work'),
      ))!;
      await settle(tester);
      await tester.runAsync(
        () => app.projects.add(name: 'Reports', parentId: work),
      );
      await settle(tester);
      await tester.tap(find.text('Reports'));
      await settle(tester);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.text('Work')));
      await tester.pumpAndSettle();
      await tester.tap(tileMenu('Work'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await settle(tester);

      expect(find.text('Inbox'), findsNWidgets(2));
      expect(find.textContaining('Not found'), findsNothing);
    });
  });
}
