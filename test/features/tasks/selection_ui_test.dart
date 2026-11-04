import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/domain/models.dart';
import 'package:planner/domain/view_options.dart';
import 'package:planner/features/tasks/state/selection.dart';
import 'package:planner/features/tasks/ui/select_tasks_button.dart';
import 'package:planner/features/tasks/ui/selection_toolbar.dart';
import 'package:planner/features/tasks/ui/task_dialog.dart';
import 'package:planner/features/tasks/ui/task_row.dart';
import 'package:planner/features/tasks/ui/task_row_parts.dart';

import '../../app/support/pump_app.dart';
import '../support/app_commands.dart';

// Выделение и панель выделения (help «Add or manage multiple tasks», «Use
// keyboard shortcuts»; решение 9 плана M4, решения 1А и 2А «Ход M4.8»).
// Локаль — en; сегодня — пятница 23.10.2026.
void main() {
  Future<List<String>> addTasks(
    WidgetTester tester,
    AppCommands app,
    List<String> names,
  ) async {
    final ids = <String>[];
    for (final name in names) {
      ids.add((await tester.runAsync(() => app.tasks.add(content: name)))!);
      await settle(tester);
    }
    return ids;
  }

  Future<Task> load(WidgetTester tester, AppCommands app, String id) async =>
      (await tester.runAsync(app.repo.load))!.task(id)!;

  Finder row(String content) =>
      find.ancestor(of: find.text(content), matching: find.byType(TaskRow));

  Finder inToolbar(Finder finder) =>
      find.descendant(of: find.byType(SelectionToolbar), matching: finder);

  Future<void> clickWith(
    WidgetTester tester,
    String content,
    List<LogicalKeyboardKey> held,
  ) async {
    for (final key in held) {
      await tester.sendKeyDownEvent(key);
    }
    // После «Дублировать» название встречается дважды — оригинал первым.
    await tester.tap(find.text(content).first);
    for (final key in held.reversed) {
      await tester.sendKeyUpEvent(key);
    }
    await tester.pumpAndSettle();
  }

  Future<void> focusRow(WidgetTester tester, String content) async {
    tester
        .widget<Focus>(
          find.descendant(of: row(content), matching: find.byType(Focus)).first,
        )
        .focusNode!
        .requestFocus();
    await tester.pumpAndSettle();
  }

  Future<void> key(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pumpAndSettle();
  }

  const ctrl = LogicalKeyboardKey.controlLeft;
  const shift = LogicalKeyboardKey.shiftLeft;

  testWidgets('`Ctrl+клик` и `Shift+клик` выделяют, панель с числом; '
      'повторный — снимает; окно задачи не открывается', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await addTasks(tester, app, ['Alpha', 'Beta']);
      expect(find.byType(SelectionToolbar), findsOneWidget);
      expect(inToolbar(find.text('0 selected')), findsNothing);

      await clickWith(tester, 'Alpha', [ctrl]);
      expect(inToolbar(find.text('1 selected')), findsOneWidget);
      await clickWith(tester, 'Beta', [shift]);
      expect(inToolbar(find.text('2 selected')), findsOneWidget);
      expect(find.byType(TaskDialog), findsNothing);

      await clickWith(tester, 'Alpha', [ctrl]);
      expect(inToolbar(find.text('1 selected')), findsOneWidget);
    });
  });

  testWidgets('`Ctrl+Shift+клик` — диапазон от прошлой выделенной в порядке '
      'списка', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await addTasks(tester, app, ['One', 'Two', 'Three', 'Four']);
      await clickWith(tester, 'Two', [ctrl]);
      await clickWith(tester, 'Four', [ctrl, shift]);
      expect(inToolbar(find.text('3 selected')), findsOneWidget);
    });
  });

  testWidgets('`x` выделяет задачу в фокусе и снимает; `Esc` снимает всё', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await addTasks(tester, app, ['Alpha', 'Beta']);
      await focusRow(tester, 'Alpha');
      await key(tester, LogicalKeyboardKey.keyX);
      expect(inToolbar(find.text('1 selected')), findsOneWidget);
      await key(tester, LogicalKeyboardKey.keyX);
      expect(inToolbar(find.textContaining('selected')), findsNothing);

      await key(tester, LogicalKeyboardKey.keyX);
      await focusRow(tester, 'Beta');
      await key(tester, LogicalKeyboardKey.keyX);
      expect(inToolbar(find.text('2 selected')), findsOneWidget);
      await key(tester, LogicalKeyboardKey.escape);
      expect(inToolbar(find.textContaining('selected')), findsNothing);
    });
  });

  testWidgets('обычный клик при выделении — окно задачи, выделение снято', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await addTasks(tester, app, ['Alpha', 'Beta']);
      await clickWith(tester, 'Alpha', [ctrl]);
      await clickWith(tester, 'Beta', []);
      expect(find.byType(TaskDialog), findsOneWidget);
      expect(inToolbar(find.textContaining('selected')), findsNothing);
    });
  });

  testWidgets('`,` — фокус на панель выделения', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await addTasks(tester, app, ['Alpha']);
      await focusRow(tester, 'Alpha');
      await key(tester, LogicalKeyboardKey.keyX);
      await key(tester, LogicalKeyboardKey.comma);
      final focus = FocusManager.instance.primaryFocus!.context!;
      expect(
        find.ancestor(
          of: find.byWidget(focus.widget),
          matching: find.byType(SelectionToolbar),
        ),
        findsOneWidget,
      );
    });
  });

  testWidgets('`Shift+Delete` при выделении — подтверждение и удаление всех '
      'выделенных, не только задачи в фокусе', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final ids = await addTasks(tester, app, ['Alpha', 'Beta', 'Gamma']);
      await clickWith(tester, 'Alpha', [ctrl]);
      await clickWith(tester, 'Beta', [ctrl]);
      await focusRow(tester, 'Beta');
      await tester.sendKeyDownEvent(shift);
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.sendKeyUpEvent(shift);
      await tester.pumpAndSettle();
      expect(find.text('Delete tasks?'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Delete'),
        ),
      );
      await settle(tester);
      final ws = (await tester.runAsync(app.repo.load))!;
      expect(ws.task(ids[0]), isNull);
      expect(ws.task(ids[1]), isNull);
      expect(ws.task(ids[2]), isNotNull);
      expect(inToolbar(find.textContaining('selected')), findsNothing);
    });
  });

  testWidgets('«Date» → «Tomorrow»: срок у всех, тост, выделение снято; '
      '«Undo» возвращает', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final ids = await addTasks(tester, app, ['Alpha', 'Beta']);
      await clickWith(tester, 'Alpha', [ctrl]);
      await clickWith(tester, 'Beta', [ctrl]);
      await tester.tap(inToolbar(find.text('Date')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tomorrow').last);
      await settle(tester);
      for (final id in ids) {
        expect((await load(tester, app, id)).due?.date, '2026-10-24');
      }
      expect(find.text('Date changed for 2 tasks'), findsOneWidget);
      expect(inToolbar(find.textContaining('selected')), findsNothing);

      await tester.tap(find.text('Undo'));
      await settle(tester);
      for (final id in ids) {
        expect((await load(tester, app, id)).due, isNull);
      }
    });
  });

  testWidgets('«Move to…» и «Labels» — у всех выделенных', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final work = (await tester.runAsync(
        () => app.projects.add(name: 'Work'),
      ))!;
      await settle(tester);
      final home = (await tester.runAsync(() => app.labels.add(name: 'home')))!;
      await settle(tester);
      final ids = await addTasks(tester, app, ['Alpha', 'Beta']);

      await clickWith(tester, 'Alpha', [ctrl]);
      await clickWith(tester, 'Beta', [ctrl]);
      await tester.tap(inToolbar(find.text('Labels')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, 'home'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await settle(tester);
      for (final id in ids) {
        expect((await load(tester, app, id)).labelIds, [home]);
      }

      await clickWith(tester, 'Alpha', [ctrl]);
      await clickWith(tester, 'Beta', [ctrl]);
      await tester.tap(inToolbar(find.text('Move to…')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(SimpleDialog),
          matching: find.text('Work'),
        ),
      );
      await settle(tester);
      final ws = (await tester.runAsync(app.repo.load))!;
      for (final id in ids) {
        expect(ws.rootProjectOf(id), work);
      }
      expect(find.text('2 tasks moved'), findsOneWidget);
    });
  });

  testWidgets('«⋯»: «Priority», «Duplicate», «Complete»; у одних выполненных '
      '— «Uncomplete»; у смешанных «⋯» скрыт', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final ids = await addTasks(tester, app, ['Alpha', 'Beta']);
      Future<void> more(String item) async {
        await tester.tap(inToolbar(find.byTooltip('More actions')));
        await tester.pumpAndSettle();
        await tester.tap(find.text(item));
        await tester.pumpAndSettle();
      }

      await clickWith(tester, 'Alpha', [ctrl]);
      await clickWith(tester, 'Beta', [ctrl]);
      await more('Priority');
      await tester.tap(find.text('Priority 1'));
      await settle(tester);
      for (final id in ids) {
        expect((await load(tester, app, id)).priority, 1);
      }

      await clickWith(tester, 'Alpha', [ctrl]);
      await more('Duplicate');
      await settle(tester);
      expect(find.text('Alpha'), findsNWidgets(2));

      await clickWith(tester, 'Beta', [ctrl]);
      await more('Complete');
      await settle(tester);
      expect((await load(tester, app, ids[1])).isCompleted, isTrue);
      expect(find.text('1 task completed'), findsOneWidget);

      // Выполненные видны с «Completed tasks» в «Отображении».
      final inbox = (await tester.runAsync(app.repo.load))!.inbox!.id;
      final view = (await tester.runAsync(
        () => app.viewsRepo.load(ViewType.project, objectId: inbox),
      ))!;
      await tester.runAsync(
        () => app.views.save(view, view.copyWith(showCompletedTasks: true)),
      );
      await settle(tester);
      await clickWith(tester, 'Beta', [ctrl]);
      await tester.tap(inToolbar(find.byTooltip('More actions')));
      await tester.pumpAndSettle();
      expect(find.text('Uncomplete'), findsOneWidget);
      expect(find.text('Complete'), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      await clickWith(tester, 'Alpha', [ctrl]);
      expect(inToolbar(find.text('2 selected')), findsOneWidget);
      expect(inToolbar(find.byTooltip('More actions')), findsNothing);
    });
  });

  testWidgets('переход на другой вид снимает выделение', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await addTasks(tester, app, ['Alpha']);
      await clickWith(tester, 'Alpha', [ctrl]);
      expect(inToolbar(find.text('1 selected')), findsOneWidget);
      await tester.tap(find.text('Today'));
      await settle(tester);
      expect(inToolbar(find.textContaining('selected')), findsNothing);
    });
  });

  testWidgets('телефон: «⋯» вида → «Select tasks», касание выделяет, а не '
      'открывает задачу', (tester) async {
    await withApp(tester, size: const Size(400, 800), (device) async {
      final app = AppCommands(device);
      await addTasks(tester, app, ['Alpha', 'Beta']);
      await tester.tap(find.byTooltip('More actions').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select tasks'));
      await tester.pumpAndSettle();
      expect(inToolbar(find.text('0 selected')), findsOneWidget);

      await tester.tap(find.text('Alpha'));
      await tester.pumpAndSettle();
      expect(find.byType(TaskDialog), findsNothing);
      expect(inToolbar(find.text('1 selected')), findsOneWidget);
      await tester.tap(inToolbar(find.byTooltip('Clear selection')));
      await tester.pumpAndSettle();
      expect(inToolbar(find.textContaining('selected')), findsNothing);
    });
  });

  testWidgets(
    'выделенная задача ушла из вида (`e` — выполнена) — «Выбрано: 1», '
    '«Удалить» её не трогает',
    (tester) async {
      await withApp(tester, (device) async {
        final app = AppCommands(device);
        final ids = await addTasks(tester, app, ['Alpha', 'Beta']);
        await clickWith(tester, 'Alpha', [ctrl]);
        await clickWith(tester, 'Beta', [ctrl]);
        await focusRow(tester, 'Alpha');
        await key(tester, LogicalKeyboardKey.keyE);
        await settle(tester);
        expect(inToolbar(find.text('1 selected')), findsOneWidget);

        await tester.tap(inToolbar(find.text('Delete')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Delete'),
          ),
        );
        await settle(tester);
        final ws = (await tester.runAsync(app.repo.load))!;
        expect(ws.task(ids[0])!.isCompleted, isTrue);
        expect(ws.task(ids[1]), isNull);
      });
    },
  );

  testWidgets('`Shift+Delete` без выделения — удаляет задачу в фокусе после '
      'подтверждения', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final ids = await addTasks(tester, app, ['Alpha', 'Beta']);
      await focusRow(tester, 'Alpha');
      await tester.sendKeyDownEvent(shift);
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.sendKeyUpEvent(shift);
      await tester.pumpAndSettle();
      expect(find.text('Delete task?'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Delete'),
        ),
      );
      await settle(tester);
      final ws = (await tester.runAsync(app.repo.load))!;
      expect(ws.task(ids[0]), isNull);
      expect(ws.task(ids[1]), isNotNull);
    });
  });

  testWidgets(
    '`Enter` по строке при выделении — окно задачи, выделение снято',
    (tester) async {
      await withApp(tester, (device) async {
        final app = AppCommands(device);
        await addTasks(tester, app, ['Alpha', 'Beta']);
        await clickWith(tester, 'Alpha', [ctrl]);
        await focusRow(tester, 'Beta');
        await key(tester, LogicalKeyboardKey.enter);
        expect(find.byType(TaskDialog), findsOneWidget);
        await key(tester, LogicalKeyboardKey.escape);
        expect(inToolbar(find.textContaining('selected')), findsNothing);
      });
    },
  );

  testWidgets('проект в архиве: `Ctrl+клик` и `x` не выделяют', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final work = (await tester.runAsync(
        () => app.projects.add(name: 'Work'),
      ))!;
      await settle(tester);
      await tester.runAsync(
        () => app.tasks.add(content: 'Report', projectId: work),
      );
      await settle(tester);
      await tester.runAsync(() => app.projects.archive(work));
      await settle(tester);
      await tester.tap(find.text('My Projects'));
      await settle(tester);
      await tester.tap(find.text('Archived projects only'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Work'));
      await settle(tester);

      await focusRow(tester, 'Report');
      await key(tester, LogicalKeyboardKey.keyX);
      expect(inToolbar(find.textContaining('selected')), findsNothing);
      await clickWith(tester, 'Report', [ctrl]);
      expect(inToolbar(find.textContaining('selected')), findsNothing);
      // Не только панель: само выделение пусто.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(TaskRow).first),
      );
      expect(container.read(taskSelectionProvider).ids, isEmpty);
    });
  });

  testWidgets('широкий экран с мышью — у «Входящих» нет «⋯» с «Select tasks»', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await tester.pumpAndSettle();
      final app = AppCommands(device);
      await addTasks(tester, app, ['Alpha']);
      expect(find.byType(SelectTasksMenuButton), findsNothing);
    });
  });

  testWidgets('телефон в режиме выделения: касание кружка выделяет, а не '
      'выполняет; «Select all» — все задачи', (tester) async {
    await withApp(tester, size: const Size(400, 800), (device) async {
      final app = AppCommands(device);
      final ids = await addTasks(tester, app, ['Alpha', 'Beta', 'Gamma']);
      await tester.tap(find.byTooltip('More actions').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select tasks'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: row('Alpha'),
          matching: find.byType(TaskCheckCircle),
        ),
      );
      await settle(tester);
      expect(
        (await tester.runAsync(app.repo.load))!.task(ids[0])!.isCompleted,
        isFalse,
      );
      expect(inToolbar(find.text('1 selected')), findsOneWidget);

      await tester.tap(inToolbar(find.byTooltip('Select all')));
      await tester.pumpAndSettle();
      expect(inToolbar(find.text('3 selected')), findsOneWidget);
    });
  });
}
