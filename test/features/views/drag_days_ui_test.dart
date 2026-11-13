import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/domain/models.dart';
import 'package:planner/domain/view_options.dart';
import 'package:planner/features/common/state/drag_session.dart';
import 'package:planner/features/common/ui/drag_layer.dart';
import 'package:planner/features/common/ui/drag_rows.dart';
import 'package:planner/features/common/ui/drag_source.dart';
import 'package:planner/features/shell/ui/sidebar.dart';
import 'package:planner/features/tasks/ui/add_task_editor.dart';
import 'package:planner/features/tasks/ui/selection_toolbar.dart';
import 'package:planner/features/views/ui/tomorrow_drop_zone.dart';
import 'package:planner/features/views/ui/view_parts.dart';
import 'package:planner/features/views/ui/week_strip.dart';

import '../../app/support/pump_app.dart';
import '../support/app_commands.dart';
import '../support/drag_gestures.dart';

// Перетаскивание в «Сегодня» и «Предстоящем» (шаг M4.9, решения 1А–3А):
// перестановка в дне, зона «на завтра», бросок на день и на проект в
// сайдбаре. Часы теста — пятница 23.10.2026. Локаль — en.
void main() {
  Finder inSidebar(String text) =>
      find.descendant(of: find.byType(Sidebar), matching: find.text(text));

  Future<String> add(
    WidgetTester tester,
    AppCommands app,
    String content, {
    String? date,
    int priority = 4,
  }) async {
    final id = (await tester.runAsync(
      () => app.tasks.add(
        content: content,
        priority: priority,
        due: date == null ? null : Due(date: date),
      ),
    ))!;
    await settle(tester);
    return id;
  }

  Future<Task> load(WidgetTester tester, AppCommands app, String id) async =>
      (await tester.runAsync(app.repo.load))!.task(id)!;

  Future<void> open(WidgetTester tester, String view) async {
    await tester.tap(inSidebar(view));
    await tester.pumpAndSettle();
  }

  /// Названия [names] сверху вниз, как они стоят на экране.
  List<String> onScreen(WidgetTester tester, List<String> names) {
    final shown =
        [
          for (final n in names)
            if (find.text(n).evaluate().isNotEmpty) n,
        ]..sort(
          (a, b) => tester
              .getTopLeft(find.text(a))
              .dy
              .compareTo(tester.getTopLeft(find.text(b)).dy),
        );
    return shown;
  }

  DragSessionState? session(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(DragLayer).first))
          .read(dragSessionProvider);

  Future<void> setView(
    WidgetTester tester,
    AppCommands app,
    ViewType type,
    ViewOptions Function(ViewOptions) change,
  ) async {
    await tester.runAsync(() async {
      final v = await app.viewsRepo.load(type);
      await app.views.save(v, change(v));
    });
    await settle(tester);
  }

  group('«Сегодня»', () {
    testWidgets('«Умная»: внутри своего класса — порядок меняется, срок '
        'нет; линия не выходит выше класса', (tester) async {
      await withApp(tester, (device) async {
        final app = AppCommands(device);
        final cat = await add(
          tester,
          app,
          'Cat',
          date: '2026-10-23',
          priority: 1,
        );
        await add(tester, app, 'Ann', date: '2026-10-23');
        final bob = await add(tester, app, 'Bob', date: '2026-10-23');
        await open(tester, 'Today');
        expect(onScreen(tester, ['Cat', 'Ann', 'Bob']), ['Cat', 'Ann', 'Bob']);

        // Верхняя половина «Cat» — выше класса «Bob»: линия под «Cat».
        final mouse = await startMouseDrag(
          tester,
          'Bob',
          aboveHalf(tester, 'Cat'),
        );
        final line = session(tester)?.indicator;
        // Линия — под «Cat», на уровне списка: не выше класса «Bob».
        expect(line?.owner, cat);
        expect(line?.mark, DropMark.below);
        expect(line?.indent, dragGutter);
        await mouse.up();
        await tester.pumpAndSettle();
        await settle(tester);
        expect(onScreen(tester, ['Cat', 'Ann', 'Bob']), ['Cat', 'Bob', 'Ann']);
        expect((await load(tester, app, bob)).due?.date, '2026-10-23');
      });
    });

    testWidgets('нижняя половина последней строки — последней, на завтра '
        'не уходит', (tester) async {
      await withApp(tester, (device) async {
        final app = AppCommands(device);
        final ann = await add(tester, app, 'Ann', date: '2026-10-23');
        await add(tester, app, 'Bob', date: '2026-10-23');
        await open(tester, 'Today');

        await mouseDrag(tester, 'Ann', belowHalf(tester, 'Bob'));
        await settle(tester);
        expect(onScreen(tester, ['Ann', 'Bob']), ['Bob', 'Ann']);
        expect((await load(tester, app, ann)).due?.date, '2026-10-23');
      });
    });

    testWidgets('«Вручную»: линия ходит среди всех задач дня', (tester) async {
      await withApp(tester, (device) async {
        final app = AppCommands(device);
        await add(tester, app, 'Cat', date: '2026-10-23', priority: 1);
        await add(tester, app, 'Ann', date: '2026-10-23');
        await setView(
          tester,
          app,
          ViewType.today,
          (v) => v.copyWith(sorting: Sorting.manual),
        );
        await open(tester, 'Today');
        final before = onScreen(tester, ['Cat', 'Ann']);

        await mouseDrag(tester, before.last, aboveHalf(tester, before.first));
        await settle(tester);
        expect(onScreen(tester, ['Cat', 'Ann']), [before.last, before.first]);
      });
    });

    testWidgets('зона «на завтра»: под последней строкой — линия и подпись, '
        'бросок меняет срок на завтра с тостом', (tester) async {
      await withApp(tester, (device) async {
        final app = AppCommands(device);
        final ann = await add(tester, app, 'Ann', date: '2026-10-23');
        await add(tester, app, 'Bob', date: '2026-10-23');
        await open(tester, 'Today');

        final mouse = await startMouseDrag(
          tester,
          'Ann',
          const Offset(600, 740),
        );
        expect(session(tester)?.indicator?.owner, 'tomorrow');
        expect(session(tester)?.indicator?.caption, 'Tomorrow');
        await mouse.up();
        await tester.pumpAndSettle();
        await settle(tester);

        expect((await load(tester, app, ann)).due?.date, '2026-10-24');
        expect(find.text('Due date changed'), findsOneWidget);
        expect(onScreen(tester, ['Ann', 'Bob']), ['Bob']);
      });
    });

    testWidgets('«Просрочено»: перестановки нет; на зону «завтра» и проект '
        'в сайдбаре — можно, срок при проекте не меняется', (tester) async {
      await withApp(tester, (device) async {
        final app = AppCommands(device);
        final work = (await tester.runAsync(
          () => app.projects.add(name: 'Work', isFavorite: true),
        ))!;
        await settle(tester);
        final late1 = await add(tester, app, 'Late1', date: '2026-10-20');
        final late2 = await add(tester, app, 'Late2', date: '2026-10-20');
        await add(tester, app, 'Ann', date: '2026-10-23');
        await open(tester, 'Today');

        await mouseDrag(tester, 'Late1', belowHalf(tester, 'Late2'));
        await settle(tester);
        expect(find.text('Task moved'), findsNothing);
        expect(find.text('Due date changed'), findsNothing);

        await mouseDrag(
          tester,
          'Late1',
          tester.getCenter(inSidebar('Work').first),
        );
        await settle(tester);
        final moved = await load(tester, app, late1);
        expect(moved.projectId, work);
        expect(moved.due?.date, '2026-10-20');

        await mouseDrag(tester, 'Late2', const Offset(1000, 740));
        await settle(tester);
        // Прежний тост уходит, и новый ждёт очереди.
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        expect((await load(tester, app, late2)).due?.date, '2026-10-24');
        expect(find.text('Due date changed'), findsOneWidget);
      });
    });

    testWidgets('выделенные не тащатся вместе: двигается только взятая, '
        'выделение остаётся', (tester) async {
      await withApp(tester, (device) async {
        final app = AppCommands(device);
        await add(tester, app, 'Ann', date: '2026-10-23');
        await add(tester, app, 'Bob', date: '2026-10-23');
        await add(tester, app, 'Cid', date: '2026-10-23');
        await open(tester, 'Today');
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.tap(find.text('Ann'));
        await tester.tap(find.text('Bob'));
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();

        await mouseDrag(tester, 'Ann', belowHalf(tester, 'Cid'));
        await settle(tester);
        expect(onScreen(tester, ['Ann', 'Bob', 'Cid']), ['Bob', 'Cid', 'Ann']);
        expect(find.byType(SelectionToolbar), findsOneWidget);
        expect(find.text('2 selected'), findsOneWidget);
      });
    });

    testWidgets('группировка выключает перетаскивание: ручки нет', (
      tester,
    ) async {
      await withApp(tester, (device) async {
        final app = AppCommands(device);
        await add(tester, app, 'Ann', date: '2026-10-23');
        await setView(
          tester,
          app,
          ViewType.today,
          (v) => v.copyWith(grouping: Grouping.priority),
        );
        await open(tester, 'Today');
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: tester.getCenter(find.text('Ann')));
        addTearDown(mouse.removePointer);
        await mouse.moveTo(tester.getCenter(find.text('Ann')));
        await tester.pump();
        expect(find.byType(DragGrip), findsNothing);
      });
    });
    testWidgets('«Умная»: у дня нет задач своего класса — линия там, куда '
        'задача встанет, и бросок меняет срок', (tester) async {
      await withApp(tester, (device) async {
        final app = AppCommands(device);
        await add(tester, app, 'Cat', date: '2026-10-23', priority: 1);
        final late1 = await add(tester, app, 'Late', date: '2026-10-20');
        await open(tester, 'Today');

        final mouse = await startMouseDrag(
          tester,
          'Late',
          belowHalf(tester, 'Cat'),
        );
        // Приоритет ниже, чем у «Cat»: встанет после неё — и линия там.
        final line = session(tester)?.indicator;
        expect(line, isNotNull);
        expect(line?.mark, DropMark.below);
        await mouse.up();
        await tester.pumpAndSettle();
        await settle(tester);
        expect((await load(tester, app, late1)).due?.date, '2026-10-23');
        expect(find.text('Due date changed'), findsOneWidget);
      });
    });

    testWidgets('просроченную можно бросить на сегодня, когда активных задач '
        'сегодня нет: на заголовок дня', (tester) async {
      await withApp(tester, (device) async {
        final app = AppCommands(device);
        final late1 = await add(tester, app, 'Late', date: '2026-10-20');
        await open(tester, 'Today');

        final mouse = await startMouseDrag(
          tester,
          'Late',
          tester.getCenter(find.byType(DayHeader)),
        );
        expect(session(tester)?.indicator?.owner, 'day:2026-10-23');
        expect(session(tester)?.indicator?.mark, DropMark.frame);
        await mouse.up();
        await tester.pumpAndSettle();
        await settle(tester);
        expect((await load(tester, app, late1)).due?.date, '2026-10-23');
      });
    });

    testWidgets('2А: «Добавить задачу» под списком — зона «на завтра», линия '
        'и подпись на этом месте', (tester) async {
      await withApp(tester, (device) async {
        final app = AppCommands(device);
        final ann = await add(tester, app, 'Ann', date: '2026-10-23');
        await add(tester, app, 'Bob', date: '2026-10-23');
        await open(tester, 'Today');

        final mouse = await startMouseDrag(
          tester,
          'Ann',
          tester.getCenter(find.text('Add task').last),
        );
        final line = session(tester)!.indicator!;
        expect(line.owner, 'end-day:2026-10-23');
        expect(line.caption, 'Tomorrow');
        await mouse.up();
        await tester.pumpAndSettle();
        await settle(tester);
        expect((await load(tester, app, ann)).due?.date, '2026-10-24');
      });
    });

    testWidgets('2А: выполненная строка — «на завтра», линия и подпись на ней '
        'самой, а не в зоне под экраном', (tester) async {
      await withApp(tester, (device) async {
        final app = AppCommands(device);
        final ann = await add(tester, app, 'Ann', date: '2026-10-23');
        final done = <String>[];
        for (var i = 1; i <= 7; i++) {
          done.add(await add(tester, app, 'Done $i', date: '2026-10-23'));
        }
        for (final id in done) {
          await tester.runAsync(() => app.tasks.complete(id));
          await settle(tester);
        }
        await setView(
          tester,
          app,
          ViewType.today,
          (v) => v.copyWith(showCompletedTasks: true),
        );
        await open(tester, 'Today');
        // Зона «на завтра» ниже экрана: список выполненных её отодвинул.
        expect(find.byType(TomorrowDropZone).hitTestable(), findsNothing);

        final mouse = await startMouseDrag(
          tester,
          'Ann',
          tester.getCenter(find.text('Done 3')),
        );
        final line = session(tester)!.indicator!;
        expect(line.owner, done[2]);
        expect(line.caption, 'Tomorrow');
        await mouse.up();
        await tester.pumpAndSettle();
        await settle(tester);
        expect((await load(tester, app, ann)).due?.date, '2026-10-24');
      }, size: const Size(1100, 420));
    });

    testWidgets('верхний редактор (`Shift+A`) — место перед первой строкой, '
        'а не «на завтра»', (tester) async {
      await withApp(tester, (device) async {
        final app = AppCommands(device);
        await add(tester, app, 'Ann', date: '2026-10-23');
        final bob = await add(tester, app, 'Bob', date: '2026-10-23');
        await open(tester, 'Today');
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pumpAndSettle();
        expect(find.byType(AddTaskEditor), findsOneWidget);

        await mouseDrag(
          tester,
          'Bob',
          tester.getCenter(find.byType(AddTaskEditor)),
        );
        await settle(tester);
        expect(onScreen(tester, ['Ann', 'Bob']), ['Bob', 'Ann']);
        expect((await load(tester, app, bob)).due?.date, '2026-10-23');
      });
    });

    testWidgets('видимый тост не перехватывает бросок: второй бросок идёт '
        'сквозь тост в ту же зону', (tester) async {
      await withApp(tester, (device) async {
        final app = AppCommands(device);
        final ann = await add(tester, app, 'Ann', date: '2026-10-23');
        final bob = await add(tester, app, 'Bob', date: '2026-10-23');
        await open(tester, 'Today');

        // Первый бросок справа — тост встаёт слева внизу, под вторым.
        await mouseDrag(tester, 'Ann', const Offset(1000, 740));
        await settle(tester);
        expect((await load(tester, app, ann)).due?.date, '2026-10-24');
        final toast = find.text('Due date changed');
        expect(toast, findsOneWidget);
        const under = Offset(600, 740);
        expect(
          tester
              .getRect(
                find.ancestor(of: toast, matching: find.byType(Material)).first,
              )
              .contains(under),
          isTrue,
        );

        await mouseDrag(tester, 'Bob', under);
        await settle(tester);
        expect((await load(tester, app, bob)).due?.date, '2026-10-24');
      });
    });
  });

  group('«Предстоящее»', () {
    testWidgets('на другой день с позицией: срок меняется, тост «Срок '
        'изменён», `Ctrl+Z` возвращает', (tester) async {
      await withApp(tester, (device) async {
        final app = AppCommands(device);
        final sat = await add(tester, app, 'Sat1', date: '2026-10-24');
        await add(tester, app, 'Sun1', date: '2026-10-25');
        await add(tester, app, 'Sun2', date: '2026-10-25');
        await open(tester, 'Upcoming');

        await mouseDrag(tester, 'Sat1', belowHalf(tester, 'Sun1'));
        await settle(tester);
        expect((await load(tester, app, sat)).due?.date, '2026-10-25');
        expect(find.text('Due date changed'), findsOneWidget);
        expect(onScreen(tester, ['Sat1', 'Sun1', 'Sun2']), [
          'Sun1',
          'Sat1',
          'Sun2',
        ]);

        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await settle(tester);
        expect((await load(tester, app, sat)).due?.date, '2026-10-24');
      });
    });

    testWidgets('на заголовок дня — меняется только дата', (tester) async {
      await withApp(tester, (device) async {
        final app = AppCommands(device);
        final sun = await add(tester, app, 'Sun1', date: '2026-10-25');
        await open(tester, 'Upcoming');

        await mouseDrag(
          tester,
          'Sun1',
          tester.getCenter(find.textContaining('Saturday').first),
        );
        await settle(tester);
        expect((await load(tester, app, sun)).due?.date, '2026-10-24');
      });
    });

    testWidgets('день выше центра прокрутки тоже принимает бросок', (
      tester,
    ) async {
      await withApp(tester, (device) async {
        final app = AppCommands(device);
        await add(tester, app, 'Sat1', date: '2026-10-24');
        final sun = await add(tester, app, 'Sun1', date: '2026-10-25');
        await open(tester, 'Upcoming');
        // Выбран воскресный день: пятница и суббота — выше центра списка.
        await tester.tap(
          find.descendant(
            of: find.byType(WeekStrip),
            matching: find.text('25'),
          ),
        );
        await tester.pumpAndSettle();
        await tester.drag(
          find.byType(CustomScrollView).last,
          const Offset(0, 260),
        );
        await tester.pumpAndSettle();
        expect(find.text('Sat1'), findsOneWidget);

        await mouseDrag(tester, 'Sun1', belowHalf(tester, 'Sat1'));
        await settle(tester);
        expect((await load(tester, app, sun)).due?.date, '2026-10-24');
      });
    });

    testWidgets('просроченная — на день: срок меняется; перестановки в '
        '«Просрочено» нет', (tester) async {
      await withApp(tester, (device) async {
        final app = AppCommands(device);
        final late1 = await add(tester, app, 'Late1', date: '2026-10-20');
        await add(tester, app, 'Late2', date: '2026-10-20');
        await add(tester, app, 'Sun1', date: '2026-10-25');
        await open(tester, 'Upcoming');

        await mouseDrag(tester, 'Late1', belowHalf(tester, 'Late2'));
        await settle(tester);
        expect(find.text('Task moved'), findsNothing);

        await mouseDrag(tester, 'Late1', belowHalf(tester, 'Sun1'));
        await settle(tester);
        expect((await load(tester, app, late1)).due?.date, '2026-10-25');
      });
    });
  });
}
