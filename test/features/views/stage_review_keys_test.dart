import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:planner/domain/view_options.dart';
import 'package:planner/features/projects/ui/project_screen.dart';
import 'package:planner/features/shell/ui/app_shell.dart';
import 'package:planner/features/tasks/ui/add_task_editor.dart';
import 'package:planner/features/views/state/upcoming_day.dart';

import '../../app/support/pump_app.dart';
import '../support/app_commands.dart';

// Клавиши help «Use keyboard shortcuts», добавленные в M4.13 (решения 1А и 2А
// «Ход M4.13»), и клавиши, проходившие сквозь меню «Отображение» (находка
// ревью). Локаль — en; сегодня — пятница 23.10.2026.
void main() {
  String location(WidgetTester tester) =>
      GoRouter.of(tester.element(find.byType(AppShell)))
          .routerDelegate
          .currentConfiguration
          .uri
          .toString();

  Future<void> press(
    WidgetTester tester,
    LogicalKeyboardKey key, {
    bool ctrl = false,
    bool shift = false,
  }) async {
    if (ctrl) await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(key);
    if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    if (ctrl) await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
  }

  String selectedDay(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(AppShell)))
          .read(upcomingDayProvider);

  group('«Предстоящее»', () {
    Future<void> openUpcoming(WidgetTester tester) =>
        press(tester, LogicalKeyboardKey.digit3, ctrl: true);

    testWidgets('`Shift+→` и `Shift+←` — неделя вперёд и назад, в прошлое не '
        'уходят; `Home` — к сегодня', (tester) async {
      await withApp(tester, (device) async {
        await openUpcoming(tester);
        expect(selectedDay(tester), '2026-10-23');

        await press(tester, LogicalKeyboardKey.arrowRight, shift: true);
        expect(selectedDay(tester), '2026-10-26');
        await press(tester, LogicalKeyboardKey.arrowRight, shift: true);
        expect(selectedDay(tester), '2026-11-02');

        await press(tester, LogicalKeyboardKey.home);
        expect(selectedDay(tester), '2026-10-23');

        await press(tester, LogicalKeyboardKey.arrowRight, shift: true);
        await press(tester, LogicalKeyboardKey.arrowLeft, shift: true);
        expect(selectedDay(tester), '2026-10-23');
        await press(tester, LogicalKeyboardKey.arrowLeft, shift: true);
        expect(selectedDay(tester), '2026-10-23');
      });
    });

    testWidgets('в поле ввода `Home` и `Shift+→` день не меняют', (
      tester,
    ) async {
      await withApp(tester, (device) async {
        await openUpcoming(tester);
        await press(tester, LogicalKeyboardKey.arrowRight, shift: true);
        expect(selectedDay(tester), '2026-10-26');
        await tester.tap(find.text('Add task').first);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).first, 'Milk');
        await press(tester, LogicalKeyboardKey.home);
        await press(tester, LogicalKeyboardKey.arrowRight, shift: true);
        expect(selectedDay(tester), '2026-10-26');
      });
    });
  });

  group('переходы', () {
    testWidgets('`Ctrl+4` — «Проекты», `Ctrl+5` — «Фильтры и метки»', (
      tester,
    ) async {
      await withApp(tester, (device) async {
        await press(tester, LogicalKeyboardKey.digit4, ctrl: true);
        expect(location(tester), '/projects');
        await press(tester, LogicalKeyboardKey.digit5, ctrl: true);
        expect(location(tester), '/filters-labels');
      });
    });

    testWidgets('в поле ввода `Ctrl+4` и `Ctrl+5` экран не меняют', (
      tester,
    ) async {
      await withApp(tester, (device) async {
        await press(tester, LogicalKeyboardKey.digit2, ctrl: true);
        await tester.tap(find.text('Add task').last);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).first, 'Milk');
        await press(tester, LogicalKeyboardKey.digit4, ctrl: true);
        await press(tester, LogicalKeyboardKey.digit5, ctrl: true);
        expect(location(tester), '/today');
      });
    });
  });

  group('проект', () {
    ScrollableState list(WidgetTester tester) => tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byType(ProjectScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );

    testWidgets('`Ctrl+End` — в конец списка, `Ctrl+Home` — в начало', (
      tester,
    ) async {
      await withApp(tester, size: const Size(1100, 300), (device) async {
        final app = AppCommands(device);
        for (var i = 1; i <= 20; i++) {
          await tester.runAsync(() => app.tasks.add(content: 'Task $i'));
          await settle(tester);
        }
        expect(list(tester).position.pixels, 0);

        await press(tester, LogicalKeyboardKey.end, ctrl: true);
        final end = list(tester).position;
        expect(end.maxScrollExtent, greaterThan(0));
        expect(end.pixels, end.maxScrollExtent);

        await press(tester, LogicalKeyboardKey.home, ctrl: true);
        expect(list(tester).position.pixels, 0);
      });
    });

    testWidgets('в поле ввода `Ctrl+End` список не прокручивает', (
      tester,
    ) async {
      await withApp(tester, size: const Size(1100, 300), (device) async {
        final app = AppCommands(device);
        for (var i = 1; i <= 20; i++) {
          await tester.runAsync(() => app.tasks.add(content: 'Task $i'));
          await settle(tester);
        }
        await press(tester, LogicalKeyboardKey.keyA, shift: true);
        expect(find.byType(AddTaskEditor), findsOneWidget);
        await tester.enterText(find.byType(TextField).first, 'Milk');
        await press(tester, LogicalKeyboardKey.end, ctrl: true);
        expect(list(tester).position.pixels, 0);
      });
    });

    testWidgets('Android: `Ctrl+Shift+N` — редактор задачи сверху, как '
        '`Shift+A`', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await withApp(tester, (device) async {
          await press(tester, LogicalKeyboardKey.keyN, ctrl: true, shift: true);
          expect(find.byType(AddTaskEditor), findsOneWidget);
          expect(find.byType(Dialog), findsNothing);
        });
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('Windows: `Ctrl+Shift+N` ничего не делает (там это «новое '
        'окно», M9)', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        await withApp(tester, (device) async {
          await press(tester, LogicalKeyboardKey.keyN, ctrl: true, shift: true);
          expect(find.byType(AddTaskEditor), findsNothing);
          expect(find.byType(Dialog), findsNothing);
        });
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('Android: в поле ввода `Ctrl+Shift+N` второй редактор не '
        'открывает', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await withApp(tester, (device) async {
          await press(tester, LogicalKeyboardKey.keyA);
          await tester.enterText(find.byType(TextField).first, 'Milk');
          await press(tester, LogicalKeyboardKey.keyN, ctrl: true, shift: true);
          expect(find.byType(AddTaskEditor), findsOneWidget);
        });
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });

  group('меню «Отображение»', () {
    Future<void> openMenu(WidgetTester tester) async {
      await tester.tap(find.textContaining('Display'));
      await tester.pumpAndSettle();
    }

    testWidgets('буквы проходят не сквозь меню: `q` не открывает быстрое '
        'добавление, `d` не меняет сортировку', (tester) async {
      await withApp(tester, (device) async {
        final app = AppCommands(device);
        await openMenu(tester);
        expect(find.text('Grouping'), findsOneWidget);

        await press(tester, LogicalKeyboardKey.keyQ);
        await press(tester, LogicalKeyboardKey.keyD);
        await press(tester, LogicalKeyboardKey.keyJ);
        expect(find.byType(Dialog), findsNothing);
        final inbox = (await tester.runAsync(app.read))!.inbox!.id;
        final options = (await tester.runAsync(
          () => app.viewsRepo.load(ViewType.project, objectId: inbox),
        ))!;
        expect(options.sorting, Sorting.byDefault);
        // Меню по-прежнему открыто, Esc его закрывает.
        expect(find.text('Grouping'), findsOneWidget);
        await press(tester, LogicalKeyboardKey.escape);
        expect(find.text('Grouping'), findsNothing);
      });
    });

    testWidgets('«Предстоящее», меню открыто: `Home` и `Shift+→` день не '
        'меняют', (tester) async {
      await withApp(tester, (device) async {
        await press(tester, LogicalKeyboardKey.digit3, ctrl: true);
        await openMenu(tester);
        await press(tester, LogicalKeyboardKey.arrowRight, shift: true);
        await press(tester, LogicalKeyboardKey.home);
        expect(selectedDay(tester), '2026-10-23');
        // Меню по-прежнему открыто (Sorting виден), Esc закрывает.
        expect(find.text('Sorting'), findsOneWidget);
        await press(tester, LogicalKeyboardKey.escape);
        expect(find.text('Sorting'), findsNothing);
        await press(tester, LogicalKeyboardKey.arrowRight, shift: true);
        expect(selectedDay(tester), '2026-10-26');
      });
    });

    testWidgets('проект, меню открыто: `Ctrl+End` список не прокручивает', (
      tester,
    ) async {
      await withApp(tester, size: const Size(1100, 300), (device) async {
        final app = AppCommands(device);
        for (var i = 1; i <= 20; i++) {
          await tester.runAsync(() => app.tasks.add(content: 'Task $i'));
          await settle(tester);
        }
        final scroll = tester.state<ScrollableState>(
          find
              .descendant(
                of: find.byType(ProjectScreen),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await openMenu(tester);
        await press(tester, LogicalKeyboardKey.end, ctrl: true);
        expect(scroll.position.pixels, 0);
      });
    });

    testWidgets('стрелки в меню работают: `↓` ставит фокус на пункт, `Esc` '
        'закрывает', (tester) async {
      await withApp(tester, (device) async {
        await openMenu(tester);
        await press(tester, LogicalKeyboardKey.arrowDown);
        expect(find.text('Grouping'), findsOneWidget);
        expect(
          FocusManager.instance.primaryFocus?.context
              ?.findAncestorWidgetOfExactType<MenuItemButton>(),
          isNotNull,
        );
        await press(tester, LogicalKeyboardKey.escape);
        expect(find.text('Grouping'), findsNothing);
      });
    });

    testWidgets('после закрытия меню `d` снова меняет сортировку', (
      tester,
    ) async {
      await withApp(tester, (device) async {
        final app = AppCommands(device);
        await openMenu(tester);
        await press(tester, LogicalKeyboardKey.escape);
        await press(tester, LogicalKeyboardKey.keyD);
        await settle(tester);
        final inbox = (await tester.runAsync(app.read))!.inbox!.id;
        final options = (await tester.runAsync(
          () => app.viewsRepo.load(ViewType.project, objectId: inbox),
        ))!;
        expect(options.sorting, Sorting.dueDate);
      });
    });
  });
}
