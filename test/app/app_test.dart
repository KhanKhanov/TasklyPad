import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pump_app.dart';

// Локаль тестов — en: тексты на английском.
void main() {
  testWidgets('приложение стартует → сайдбар и открытые «Входящие»', (
    tester,
  ) async {
    await withApp(tester, (_) async {
      expect(find.text('Inbox'), findsNWidgets(2)); // сайдбар и заголовок
      expect(find.text('My Projects'), findsOneWidget);
      expect(find.text('No tasks yet'), findsOneWidget);
    });
  });

  testWidgets('узкое окно → сайдбар скрыт и открывается кнопкой', (
    tester,
  ) async {
    await withApp(tester, size: const Size(420, 800), (_) async {
      expect(find.text('My Projects'), findsNothing);
      await tester.tap(find.byTooltip('Open or close sidebar'));
      await tester.pumpAndSettle();
      expect(find.text('My Projects'), findsOneWidget);
    });
  });

  testWidgets('широкое окно → кнопка в сайдбаре прячет его и возвращает', (
    tester,
  ) async {
    await withApp(tester, (_) async {
      await tester.tap(find.byTooltip('Open or close sidebar'));
      await tester.pumpAndSettle();
      expect(find.text('My Projects'), findsNothing);

      await tester.tap(find.byTooltip('Open or close sidebar'));
      await tester.pumpAndSettle();
      expect(find.text('My Projects'), findsOneWidget);
      expect(find.byType(Drawer), findsNothing);
    });
  });
}
