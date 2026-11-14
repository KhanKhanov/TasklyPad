import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:planner/app/nav_history.dart';
import 'package:planner/features/shell/ui/app_shell.dart';
import 'package:planner/features/tasks/ui/task_dialog.dart';

import '../../app/support/pump_app.dart';
import '../support/app_commands.dart';

// «Назад» и «Вперёд» по экранам: `Alt+←` / `Alt+→` и боковые кнопки мыши
// (help «Use keyboard shortcuts»; решение 13А «M4.10a» plans/m4); `Esc` —
// «назад», когда закрывать нечего (решение 1Б plans/m5 «Решения проверки
// M5.3»).
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

  group('Esc', () {
    Future<void> esc(WidgetTester tester) async {
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
    }

    /// «Сегодня», затем «Входящие»: шаг назад ведёт в «Сегодня».
    Future<void> todayThenInbox(WidgetTester tester) async {
      final ctrl = LogicalKeyboardKey.controlLeft;
      await chord(tester, ctrl, LogicalKeyboardKey.digit2);
      await chord(tester, ctrl, LogicalKeyboardKey.digit1);
      expect(location(tester), '/');
    }

    Future<void> addTask(WidgetTester tester, AppCommands app, String name) =>
        tester.runAsync(() => app.tasks.add(content: name)).then((_) {});

    testWidgets('закрывать нечего → назад, как Alt+←', (tester) async {
      await withApp(tester, (device) async {
        await todayThenInbox(tester);
        await esc(tester);
        expect(location(tester), '/today');
      });
    });

    testWidgets('история пуста → экран не меняется', (tester) async {
      await withApp(tester, (device) async {
        final start = location(tester);
        await esc(tester);
        expect(location(tester), start);
      });
    });

    testWidgets('открыто меню «Display» → первый Esc закрывает его, второй — '
        'назад', (tester) async {
      await withApp(tester, (device) async {
        await todayThenInbox(tester);
        await tester.tap(find.textContaining('Display'));
        await tester.pumpAndSettle();
        expect(find.text('Grouping'), findsOneWidget);

        await esc(tester);
        expect(find.text('Grouping'), findsNothing);
        expect(location(tester), '/');
        await esc(tester);
        expect(location(tester), '/today');
      });
    });

    testWidgets('меню строки открыто клавишей «.» (фокус — на строке) → Esc '
        'закрывает меню, второй — назад', (tester) async {
      await withApp(tester, (device) async {
        final app = AppCommands(device);
        await todayThenInbox(tester);
        await addTask(tester, app, 'Milk');
        await settle(tester);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.period);
        await tester.pumpAndSettle();
        expect(find.text('Move to…'), findsOneWidget);

        await esc(tester);
        expect(find.text('Move to…'), findsNothing);
        expect(location(tester), '/');
        await esc(tester);
        expect(location(tester), '/today');
      });
    });

    testWidgets('узкое окно, сайдбар выдвинут клавишей «m» → Esc закрывает '
        'его, экран тот же', (tester) async {
      await withApp(tester, size: const Size(400, 800), (device) async {
        await todayThenInbox(tester);
        ScaffoldState scaffold() =>
            tester.state<ScaffoldState>(find.byType(Scaffold).first);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
        await tester.pumpAndSettle();
        expect(scaffold().isDrawerOpen, isTrue);

        await esc(tester);
        expect(scaffold().isDrawerOpen, isFalse);
        expect(location(tester), '/');
      });
    });

    testWidgets('открыта панель задачи → Esc закрывает её, экран тот же', (
      tester,
    ) async {
      await withApp(tester, (device) async {
        final app = AppCommands(device);
        await todayThenInbox(tester);
        await addTask(tester, app, 'Milk');
        await settle(tester);
        await tester.tap(find.text('Milk'));
        await tester.pumpAndSettle();
        expect(find.byType(TaskDialog), findsOneWidget);

        await esc(tester);
        expect(find.byType(TaskDialog), findsNothing);
        expect(location(tester), '/');
      });
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

    testWidgets('выделены задачи → первый Esc снимает выделение, второй — '
        'назад', (tester) async {
      await withApp(tester, (device) async {
        final app = AppCommands(device);
        await todayThenInbox(tester);
        await addTask(tester, app, 'Milk');
        await settle(tester);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.keyX);
        await tester.pumpAndSettle();
        expect(find.text('1 selected'), findsOneWidget);

        await esc(tester);
        expect(find.text('1 selected'), findsNothing);
        expect(location(tester), '/');
        await esc(tester);
        expect(location(tester), '/today');
      });
    });

    testWidgets('в редакторе «Add task» → Esc закрывает редактор, экран тот '
        'же', (tester) async {
      await withApp(tester, (device) async {
        await todayThenInbox(tester);
        await tester.tap(find.text('Add task').last);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).first, 'Milk');
        await esc(tester);
        expect(location(tester), '/');
      });
    });

    testWidgets('после «g» Esc отменяет сочетание и назад не ведёт', (
      tester,
    ) async {
      await withApp(tester, (device) async {
        await todayThenInbox(tester);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
        await esc(tester);
        expect(location(tester), '/');
      });
    });
  });
}
