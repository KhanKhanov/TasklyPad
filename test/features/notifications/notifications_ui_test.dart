import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/data/repositories/notification_log_repository.dart';
import 'package:planner/domain/notification_log.dart';
import 'package:planner/features/common/ui/app_toast.dart';
import 'package:planner/features/notifications/ui/notifications_panel.dart';
import 'package:planner/features/notifications/ui/notifications_tab.dart';

import '../../app/support/pump_app.dart';

// Вкладка и журнал «Уведомления» (решения 1А–4А и вопросы 1А, 2А plans/m5
// «Решения M5.3a»). Окно 1100×800 — компьютер, 400×800 — телефон. Локаль —
// en.
void main() {
  Finder onTab(Finder f) =>
      find.descendant(of: find.byType(NotificationsTab), matching: f);

  Finder inPanel(Finder f) =>
      find.descendant(of: find.byType(NotificationsPanel), matching: f);

  /// Показать тост и дождаться, пока он уйдёт и запишется в журнал.
  Future<void> toast(WidgetTester tester, String text) async {
    showAppToast(
      ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first)),
      text: text,
      duration: const Duration(seconds: 1),
    );
    await settle(tester);
    await tester.pump(const Duration(seconds: 2));
    await settle(tester);
  }

  testWidgets('тост → счётчик на вкладке; журнал: запись без «Undo», '
      'счётчик обнуляется', (tester) async {
    await withApp(tester, (device) async {
      expect(find.byType(NotificationsTab), findsOneWidget);
      expect(onTab(find.text('1')), findsNothing);
      await toast(tester, 'Task completed');
      expect(onTab(find.text('1')), findsOneWidget);

      await tester.tap(find.byType(NotificationsTab));
      await settle(tester);
      expect(inPanel(find.text('Task completed')), findsOneWidget);
      expect(inPanel(find.text('Undo')), findsNothing);
      expect(onTab(find.text('1')), findsNothing);
      final saved = (await tester.runAsync(
        NotificationLogRepository(device.db).load,
      ))!;
      expect(saved.unread, 0);
    });
  });

  testWidgets('«×» удаляет запись, «Clear all» — все', (tester) async {
    await withApp(tester, (device) async {
      await toast(tester, 'One');
      await toast(tester, 'Two');
      await tester.tap(find.byType(NotificationsTab));
      await settle(tester);
      await tester.tap(
        find.descendant(
          of: find.ancestor(
            of: find.text('One'),
            matching: find.byType(NotificationTile),
          ),
          matching: find.byTooltip('Delete'),
        ),
      );
      await settle(tester);
      expect(inPanel(find.text('One')), findsNothing);
      expect(inPanel(find.text('Two')), findsOneWidget);

      await tester.tap(inPanel(find.text('Clear all')));
      await settle(tester);
      expect(inPanel(find.text('No notifications')), findsOneWidget);
      final saved = (await tester.runAsync(
        NotificationLogRepository(device.db).load,
      ))!;
      expect(saved.items, isEmpty);
    });
  });

  testWidgets('журнал из прошлого запуска — на месте, счётчик верный', (
    tester,
  ) async {
    await withApp(
      tester,
      before: (device) =>
          NotificationLogRepository(device.db)
              .save(const NotificationLog().add('Old', 0).add('Older', 0)),
      (device) async {
        expect(onTab(find.text('2')), findsOneWidget);
        await tester.tap(find.byType(NotificationsTab));
        await settle(tester);
        expect(inPanel(find.text('Old')), findsOneWidget);
        expect(inPanel(find.text('Older')), findsOneWidget);
      },
    );
  });

  testWidgets('телефон: вкладки нет; пункт в сайдбаре со счётчиком открывает '
      'журнал во весь экран', (tester) async {
    await withApp(tester, size: const Size(400, 800), (device) async {
      expect(find.byType(NotificationsTab), findsNothing);
      await toast(tester, 'Saved');
      final scaffold = tester.state<ScaffoldState>(find.byType(Scaffold).first);
      scaffold.openDrawer();
      await tester.pumpAndSettle();
      final item = find.ancestor(
        of: find.text('Notifications'),
        matching: find.byType(InkWell),
      );
      expect(
        find.descendant(of: item.first, matching: find.text('1')),
        findsOneWidget,
      );
      await tester.tap(find.text('Notifications'));
      await settle(tester);
      expect(find.byType(Dialog), findsOneWidget);
      expect(inPanel(find.text('Saved')), findsOneWidget);
    });
  });

  testWidgets('диктор: у вкладки есть действие «нажать», оно открывает '
      'журнал', (tester) async {
    final handle = tester.ensureSemantics();
    await withApp(tester, (device) async {
      final node = tester.getSemantics(find.bySemanticsLabel('Notifications'));
      expect(
        node,
        matchesSemantics(
          label: 'Notifications',
          isButton: true,
          hasTapAction: true,
        ),
      );
      node.owner!.performAction(node.id, SemanticsAction.tap);
      await settle(tester);
      expect(find.byType(NotificationsPanel), findsOneWidget);
    });
    handle.dispose();
  });

  testWidgets('Esc при открытом журнале закрывает его и назад не уводит', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      final ctrl = LogicalKeyboardKey.controlLeft;
      for (final digit in [
        LogicalKeyboardKey.digit2,
        LogicalKeyboardKey.digit1,
      ]) {
        await tester.sendKeyDownEvent(ctrl);
        await tester.sendKeyEvent(digit);
        await tester.sendKeyUpEvent(ctrl);
        await tester.pumpAndSettle();
      }
      String location() =>
          GoRouter.of(tester.element(find.byType(NotificationsTab)))
              .routerDelegate
              .currentConfiguration
              .uri
              .toString();
      expect(location(), '/');
      await tester.tap(find.byType(NotificationsTab));
      await settle(tester);
      expect(find.byType(NotificationsPanel), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(NotificationsPanel), findsNothing);
      expect(location(), '/');
    });
  });

  testWidgets('новый тост при открытом журнале — сразу прочитан, счётчик не '
      'растёт', (tester) async {
    await withApp(tester, (device) async {
      await tester.tap(find.byType(NotificationsTab));
      await settle(tester);
      await toast(tester, 'While open');
      expect(inPanel(find.text('While open')), findsOneWidget);
      final saved = (await tester.runAsync(
        NotificationLogRepository(device.db).load,
      ))!;
      expect(saved.unread, 0);
    });
  });
}
