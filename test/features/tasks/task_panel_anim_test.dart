import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/features/tasks/ui/task_dialog.dart';

import '../../app/support/pump_app.dart';
import '../support/app_commands.dart';

// Панель задачи появляется из 50 % размера с проявлением и уходит обратно
// (решение 7А «M4.10a» plans/m4). Локаль — en.
void main() {
  double scale(WidgetTester tester) => tester
      .widget<ScaleTransition>(
        find
            .ancestor(
              of: find.byType(TaskDialog),
              matching: find.byType(ScaleTransition),
            )
            .first,
      )
      .scale
      .value;

  Future<void> addTask(WidgetTester tester, AppCommands app) async {
    await tester.runAsync(() => app.tasks.add(content: 'Buy milk'));
    await settle(tester);
  }

  testWidgets('открытие: в середине — между половиной и полным размером, в '
      'конце — полный; Esc — уходит так же', (tester) async {
    await withApp(tester, (device) async {
      await addTask(tester, AppCommands(device));
      await tester.tap(find.text('Buy milk'));
      await tester.pump();
      // Начало открытия медленное: за первую четверть времени окно почти не
      // выросло (кривая `easeInOutCubic`).
      await tester.pump(const Duration(milliseconds: 125));
      expect(scale(tester), lessThan(0.6));
      await tester.pump(const Duration(milliseconds: 125));
      final opening = scale(tester);
      expect(opening, greaterThan(0.5));
      expect(opening, lessThan(1));

      await tester.pumpAndSettle();
      expect(scale(tester), 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byType(TaskDialog), findsOneWidget);
      expect(scale(tester), lessThan(1));
      await tester.pumpAndSettle();
      expect(find.byType(TaskDialog), findsNothing);
    });
  });

  testWidgets('системное «уменьшить движение» → панель сразу полная', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await withApp(tester, (device) async {
      await addTask(tester, AppCommands(device));
      await tester.tap(find.text('Buy milk'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(
        find.ancestor(
          of: find.byType(TaskDialog),
          matching: find.byType(ScaleTransition),
        ),
        findsNothing,
      );
      await tester.pumpAndSettle();
    });
  });
}
