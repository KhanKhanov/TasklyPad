import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/domain/view_options.dart';
import 'package:planner/features/common/state/drag_session.dart';
import 'package:planner/features/common/ui/drag_layer.dart';
import 'package:planner/features/tasks/ui/task_dialog.dart';
import 'package:planner/features/tasks/ui/task_row.dart';

import '../../app/support/fake_link_opener.dart';
import '../../app/support/pump_app.dart';
import '../support/app_commands.dart';
import '../support/drag_gestures.dart';

// Находки ревью конца этапа M4 (шаг M4.13) в строке задачи, тостах и клавишах
// строки. Локаль — en; сегодня — пятница 23.10.2026.
void main() {
  Future<String> addTask(
    WidgetTester tester,
    AppCommands app,
    String content, {
    String? parentId,
  }) async {
    final id = (await tester.runAsync(
      () => app.tasks.add(content: content, parentId: parentId),
    ))!;
    await settle(tester);
    return id;
  }

  Finder row(String content) =>
      find.ancestor(of: find.text(content), matching: find.byType(TaskRow));

  FocusNode rowFocus(WidgetTester tester, Finder of) => tester
      .widget<Focus>(
        find.descendant(of: of, matching: find.byType(Focus)).first,
      )
      .focusNode!;

  Future<void> focusRow(WidgetTester tester, Finder of) async {
    rowFocus(tester, of).requestFocus();
    await tester.pumpAndSettle();
  }

  Finder inDialog(Finder f) =>
      find.descendant(of: find.byType(TaskDialog), matching: f);

  Future<void> press(
    WidgetTester tester,
    LogicalKeyboardKey key, {
    bool ctrl = false,
    bool shift = false,
    bool alt = false,
  }) async {
    if (ctrl) await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    if (alt) await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(key);
    if (alt) await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    if (ctrl) await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle(tester);
  }

  Future<bool> isDone(WidgetTester tester, AppCommands app, String id) async =>
      (await tester.runAsync(app.read))!.task(id)!.isCompleted;

  Future<void> showCompleted(WidgetTester tester, AppCommands app) async {
    await tester.runAsync(() async {
      final ws = await app.read();
      final v = await app.viewsRepo.load(
        ViewType.project,
        objectId: ws.inbox!.id,
      );
      await app.views.save(v, v.copyWith(showCompletedTasks: true));
    });
    await settle(tester);
  }

  testWidgets('`Ctrl+Z` при тостах в списке и в окне задачи — отменяет только '
      'последнее показанное действие', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final a = await addTask(tester, app, 'A');
      final parent = await addTask(tester, app, 'Parent');
      final child = await addTask(tester, app, 'Child', parentId: parent);
      // Тост оболочки: A выполнена в списке.
      await tester.tap(
        find.descendant(of: row('A'), matching: find.byTooltip('Complete')),
      );
      await settle(tester);
      // Тост окна: подзадача выполнена кружком в окне задачи.
      await tester.tap(find.text('Parent'));
      await settle(tester);
      await tester.tap(inDialog(find.byTooltip('Complete')).last);
      await settle(tester);
      expect(await isDone(tester, app, child), isTrue);
      // Фокус не в поле названия: там `Ctrl+Z` — отмена набора текста.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      await press(tester, LogicalKeyboardKey.keyZ, ctrl: true);
      expect(await isDone(tester, app, child), isFalse);
      expect(await isDone(tester, app, a), isTrue);

      // Второе нажатие — тост оболочки, ещё видимый, а не пустота.
      await press(tester, LogicalKeyboardKey.keyZ, ctrl: true);
      expect(await isDone(tester, app, a), isFalse);
    });
  });

  // Ручная проверка M4.13: «Ctrl+Z работает только один раз». После отмены
  // следующее действие снова отменяется клавишей — в списке и в окне задачи,
  // фокус не снимается (как у пользователя).
  testWidgets('`Ctrl+Z` после отмены — следующее действие снова отменяется, '
      'в списке и в окне задачи', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final a = await addTask(tester, app, 'A');
      final b = await addTask(tester, app, 'B');
      final parent = await addTask(tester, app, 'Parent');
      final c1 = await addTask(tester, app, 'C1', parentId: parent);
      final c2 = await addTask(tester, app, 'C2', parentId: parent);
      Future<void> complete(Finder of) async {
        await tester.tap(
          find.descendant(of: of, matching: find.byTooltip('Complete')),
        );
        await settle(tester);
      }

      await complete(row('A'));
      await press(tester, LogicalKeyboardKey.keyZ, ctrl: true);
      expect(await isDone(tester, app, a), isFalse);
      await complete(row('B'));
      await press(tester, LogicalKeyboardKey.keyZ, ctrl: true);
      expect(await isDone(tester, app, b), isFalse);

      await tester.tap(find.text('Parent'));
      await settle(tester);
      Finder dialogRow(String content) => find.ancestor(
        of: inDialog(find.text(content)),
        matching: find.byType(TaskRow),
      );
      await complete(dialogRow('C1'));
      await press(tester, LogicalKeyboardKey.keyZ, ctrl: true);
      expect(await isDone(tester, app, c1), isFalse);
      await complete(dialogRow('C2'));
      await press(tester, LogicalKeyboardKey.keyZ, ctrl: true);
      expect(await isDone(tester, app, c2), isFalse);
    });
  });

  testWidgets('меню подзадачи в окне задачи: «Tomorrow» — тост в окне задачи '
      'и «Undo» работает', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final parent = await addTask(tester, app, 'Parent');
      final child = await addTask(tester, app, 'Child', parentId: parent);
      await tester.tap(find.text('Parent'));
      await settle(tester);
      final childRow = find.ancestor(
        of: inDialog(find.text('Child')),
        matching: find.byType(TaskRow),
      );
      await focusRow(tester, childRow);
      await press(tester, LogicalKeyboardKey.period);
      await tester.tap(find.byTooltip('Tomorrow'));
      await settle(tester);

      expect(inDialog(find.text('Due date changed')), findsOneWidget);
      // Меню ещё открыто и закрывает тост от нажатий: закрыть его.
      await press(tester, LogicalKeyboardKey.escape);
      var task = (await tester.runAsync(app.read))!.task(child)!;
      expect(task.due?.date, '2026-10-24');
      await tester.tap(inDialog(find.text('Undo')));
      await settle(tester);
      task = (await tester.runAsync(app.read))!.task(child)!;
      expect(task.due, isNull);
    });
  });

  testWidgets('«Выполненные задачи» вкл.: `e` на задаче — фокус остаётся на '
      'её строке', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      for (final n in ['T1', 'T2', 'T3', 'T4', 'T5']) {
        await addTask(tester, app, n);
      }
      await showCompleted(tester, app);
      final t5 = row('T5');
      await focusRow(tester, t5);
      final node = rowFocus(tester, t5);
      expect(node.hasFocus, isTrue);

      await press(tester, LogicalKeyboardKey.keyE);
      expect(node.hasFocus, isTrue);
      expect(rowFocus(tester, row('T5')), same(node));
    });
  });

  testWidgets('`d` (сортировка по сроку) — строки не пересоздаются, фокус '
      'остаётся', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      for (final n in ['T1', 'T2', 'T3']) {
        await addTask(tester, app, n);
      }
      await focusRow(tester, row('T2'));
      final node = rowFocus(tester, row('T2'));
      final stateBefore = tester.state(row('T2'));

      await press(tester, LogicalKeyboardKey.keyD);
      expect(node.hasFocus, isTrue);
      expect(tester.state(row('T2')), same(stateBefore));
    });
  });

  testWidgets('ссылка в строке при `Ctrl+клик` — выделение, адрес не '
      'открывается', (tester) async {
    final links = FakeLinkOpener();
    await withApp(tester, links: links, (device) async {
      final app = AppCommands(device);
      await addTask(tester, app, 'Run [site](https://example.com/t)');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.tapOnText(find.textRange.ofSubstring('site'));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await settle(tester);
      expect(links.opened, isEmpty);
      expect(find.text('1 selected'), findsOneWidget);
    });
  });

  testWidgets('подзадача в окне задачи (не выделяется): `Ctrl+клик` по ссылке '
      'открывает адрес, а не окно', (tester) async {
    final links = FakeLinkOpener();
    await withApp(tester, links: links, (device) async {
      final app = AppCommands(device);
      final parent = await addTask(tester, app, 'Parent');
      await addTask(
        tester,
        app,
        'Run [site](https://example.com/t)',
        parentId: parent,
      );
      // Подзадача свёрнута в списке: ссылка видна только в окне.
      await tester.runAsync(() => app.tasks.setCollapsed(parent, true));
      await settle(tester);
      await tester.tap(find.text('Parent'));
      await settle(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.tapOnText(find.textRange.ofSubstring('site'));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await settle(tester);
      expect(links.opened, [Uri.parse('https://example.com/t')]);
      expect(find.text('1 selected'), findsNothing);
    });
  });

  testWidgets('телефон, режим «Select tasks»: ссылка в строке выделяет '
      'строку, адрес не открывается', (tester) async {
    final links = FakeLinkOpener();
    await withApp(tester, links: links, size: const Size(400, 800), (
      device,
    ) async {
      final app = AppCommands(device);
      await addTask(tester, app, 'Run [site](https://example.com/t)');
      await tester.tap(find.byTooltip('More actions').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select tasks'));
      await tester.pumpAndSettle();

      await tester.tapOnText(find.textRange.ofSubstring('site'));
      await settle(tester);
      expect(links.opened, isEmpty);
      expect(find.text('1 selected'), findsOneWidget);
    });
  });

  testWidgets('телефон: бросок под тостом находит место — тост не '
      'перехватывает попадание', (tester) async {
    await withApp(tester, size: const Size(400, 420), (device) async {
      final app = AppCommands(device);
      for (final n in ['T1', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'T8']) {
        await addTask(tester, app, n);
      }
      await tester.tap(
        find.descendant(of: row('T1'), matching: find.byTooltip('Complete')),
      );
      await settle(tester);
      // Точка на кнопке тоста; под ней должна лежать строка задачи.
      final at = tester.getCenter(find.text('Undo'));
      final under = [
        for (final n in ['T3', 'T4', 'T5', 'T6', 'T7', 'T8'])
          if (find.text(n).evaluate().isNotEmpty &&
              tester.getRect(dragRow(n)).contains(at))
            n,
      ];
      expect(under, isNotEmpty);

      final touch = await startLongPressDrag(tester, 'T2', at);
      final session = ProviderScope.containerOf(
        tester.element(find.byType(DragLayer).first),
      ).read(dragSessionProvider);
      expect(session?.indicator, isNotNull);
      await touch.up();
      await tester.pumpAndSettle();
    });
  });

  testWidgets('`Shift+Delete` у подзадачи в окне, открытом из меню при '
      'выделении в списке: выделение снято, подтверждение удаления', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final parent = await addTask(tester, app, 'Parent');
      await addTask(tester, app, 'Child', parentId: parent);
      await addTask(tester, app, 'Other');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.tap(find.text('Other'));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await settle(tester);
      expect(find.text('1 selected'), findsOneWidget);

      await focusRow(tester, row('Parent'));
      await press(tester, LogicalKeyboardKey.period);
      await tester.tap(find.text('Edit'));
      await settle(tester);
      expect(find.byType(TaskDialog), findsOneWidget);
      expect(find.text('1 selected'), findsNothing);

      await focusRow(
        tester,
        find.ancestor(
          of: inDialog(find.text('Child')),
          matching: find.byType(TaskRow),
        ),
      );
      await press(tester, LogicalKeyboardKey.delete, shift: true);
      expect(find.text('Delete task?'), findsOneWidget);
    });
  });

  testWidgets('`Ctrl+E` и `Alt+E` у задачи в фокусе открывают окно задачи', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await addTask(tester, app, 'Milk');
      await focusRow(tester, row('Milk'));
      await press(tester, LogicalKeyboardKey.keyE, ctrl: true);
      expect(find.byType(TaskDialog), findsOneWidget);
      await press(tester, LogicalKeyboardKey.escape);
      expect(find.byType(TaskDialog), findsNothing);

      await focusRow(tester, row('Milk'));
      await press(tester, LogicalKeyboardKey.keyE, alt: true);
      expect(find.byType(TaskDialog), findsOneWidget);
    });
  });

  testWidgets('`Ctrl+Shift+E` и простая `e` не путаются с `Ctrl+E`: `e` '
      'выполняет, `Ctrl+Shift+E` ничего', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final id = await addTask(tester, app, 'Milk');
      await focusRow(tester, row('Milk'));
      await press(tester, LogicalKeyboardKey.keyE, ctrl: true, shift: true);
      expect(find.byType(TaskDialog), findsNothing);
      expect(await isDone(tester, app, id), isFalse);
      await press(tester, LogicalKeyboardKey.keyE);
      expect(await isDone(tester, app, id), isTrue);
    });
  });
}
