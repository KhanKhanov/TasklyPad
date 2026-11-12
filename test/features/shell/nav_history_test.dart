import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:planner/app/nav_history.dart';
import 'package:planner/features/shell/ui/app_shell.dart';

import '../../app/support/pump_app.dart';

// «Назад» и «Вперёд» по экранам: `Alt+←` / `Alt+→` и боковые кнопки мыши
// (help «Use keyboard shortcuts»; решение 13А «M4.10a» plans/m4).
void main() {
  group('NavHistory', () {
    test('три перехода, назад дважды → первый; вперёд → второй', () {
      final h = NavHistory()
        ..visit('/')
        ..visit('/today')
        ..visit('/upcoming');
      expect(h.back(), '/today');
      expect(h.back(), '/');
      expect(h.back(), isNull);
      expect(h.forward(), '/today');
    });

    test('назад, затем новый переход → «вперёд» пусто', () {
      final h = NavHistory()
        ..visit('/')
        ..visit('/today');
      expect(h.back(), '/');
      h.visit('/upcoming');
      expect(h.canForward, isFalse);
      expect(h.back(), '/');
    });

    test('переход на адрес из back() → не новый шаг, «вперёд» цел', () {
      final h = NavHistory()
        ..visit('/')
        ..visit('/today');
      final to = h.back()!;
      h.visit(to); // роутер сообщает о переходе, который сделали мы
      expect(h.forward(), '/today');
    });

    test('история длиннее предела → старые шаги забываются', () {
      final h = NavHistory(limit: 2);
      for (final p in ['/a', '/b', '/c', '/d']) {
        h.visit(p);
      }
      expect(h.back(), '/c');
      expect(h.back(), '/b');
      expect(h.back(), isNull);
    });
  });

  String location(WidgetTester tester) =>
      GoRouter.of(tester.element(find.byType(AppShell)))
          .routerDelegate
          .currentConfiguration
          .uri
          .toString();

  Future<void> chord(
    WidgetTester tester,
    LogicalKeyboardKey modifier,
    LogicalKeyboardKey key,
  ) async {
    await tester.sendKeyDownEvent(modifier);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(modifier);
    await tester.pumpAndSettle();
  }

  testWidgets('Alt+← и Alt+→ — назад и вперёд по экранам', (tester) async {
    await withApp(tester, (device) async {
      final ctrl = LogicalKeyboardKey.controlLeft;
      final alt = LogicalKeyboardKey.altLeft;
      await chord(tester, ctrl, LogicalKeyboardKey.digit2);
      await chord(tester, ctrl, LogicalKeyboardKey.digit3);
      expect(location(tester), '/upcoming');

      await chord(tester, alt, LogicalKeyboardKey.arrowLeft);
      expect(location(tester), '/today');
      await chord(tester, alt, LogicalKeyboardKey.arrowLeft);
      expect(location(tester), '/');
      await chord(tester, alt, LogicalKeyboardKey.arrowRight);
      expect(location(tester), '/today');
    });
  });

  testWidgets('история пуста → Alt+← ничего не меняет', (tester) async {
    await withApp(tester, (device) async {
      final start = location(tester);
      await chord(
        tester,
        LogicalKeyboardKey.altLeft,
        LogicalKeyboardKey.arrowLeft,
      );
      expect(location(tester), start);
    });
  });

  testWidgets('Alt+← в текстовом поле → экран не меняется', (tester) async {
    await withApp(tester, (device) async {
      await chord(
        tester,
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.digit2,
      );
      await tester.tap(find.text('Add task').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Milk');
      await chord(
        tester,
        LogicalKeyboardKey.altLeft,
        LogicalKeyboardKey.arrowLeft,
      );
      expect(location(tester), '/today');
    });
  });

  testWidgets('боковые кнопки мыши → назад и вперёд', (tester) async {
    await withApp(tester, (device) async {
      await chord(
        tester,
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.digit2,
      );
      final at = tester.getCenter(find.byType(AppShell));

      Future<void> click(int button) async {
        final g = await tester.startGesture(
          at,
          kind: PointerDeviceKind.mouse,
          buttons: button,
        );
        await g.up();
        await tester.pumpAndSettle();
      }

      await click(kBackMouseButton);
      expect(location(tester), '/');
      await click(kForwardMouseButton);
      expect(location(tester), '/today');
    });
  });
}
