import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:planner/data/projection/entity_fields.dart';
import 'package:planner/domain/view_options.dart';
import 'package:planner/features/common/state/drag_session.dart';
import 'package:planner/features/common/ui/drag_layer.dart';
import 'package:planner/features/common/ui/drag_source.dart';
import 'package:planner/features/tasks/ui/add_task_editor.dart';
import 'package:planner/features/tasks/ui/selection_toolbar.dart';
import 'package:planner/features/tasks/ui/task_dialog.dart';
import 'package:planner/features/tasks/ui/task_row_menu.dart';

import '../../app/support/pump_app.dart';
import '../support/app_commands.dart';
import '../support/drag_gestures.dart';

// Перетаскивание задач: находки ревью M4.9 (верхний редактор, подзадача под
// выполненной, выделение при пустом броске, выход указателя за окно,
// ручка и «⋯» во время перетаскивания, касание тащит одну, размонтирование
// посреди перетаскивания). Локаль — en; сегодня — пятница 23.10.2026.
void main() {
  Future<String> addTask(
    WidgetTester tester,
    AppCommands app,
    String name, {
    String? parentId,
  }) async {
    final id = (await tester.runAsync(
      () => app.tasks.add(content: name, parentId: parentId),
    ))!;
    await settle(tester);
    return id;
  }

  Future<List<String>> addAll(
    WidgetTester tester,
    AppCommands app,
    List<String> names,
  ) async => [for (final n in names) await addTask(tester, app, n)];

  Future<List<String>> inboxOrder(WidgetTester tester, AppCommands app) async {
    final ws = (await tester.runAsync(app.repo.load))!;
    return [
      for (final t in ws.children(null, projectId: ws.inbox!.id)) t.content,
    ];
  }

  DragSessionState? session(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(DragLayer).first))
          .read(dragSessionProvider);

  Future<void> ctrlClick(WidgetTester tester, List<String> names) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    for (final n in names) {
      await tester.tap(find.text(n));
    }
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
  }

  testWidgets('верхний редактор (`Shift+A`) — место перед первой строкой: '
      'задача встаёт первой, а не уходит в конец', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await addAll(tester, app, ['Alpha', 'Beta', 'Gamma']);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      expect(find.byType(AddTaskEditor), findsOneWidget);

      final mouse = await startMouseDrag(
        tester,
        'Gamma',
        tester.getCenter(find.byType(AddTaskEditor)),
      );
      expect(session(tester)?.indicator?.mark, DropMark.above);
      await mouse.up();
      await tester.pumpAndSettle();
      await settle(tester);
      expect(await inboxOrder(tester, app), ['Gamma', 'Alpha', 'Beta']);
    });
  });

  testWidgets('активная подзадача под выполненной: ручки нет, и линия '
      'встаёт после последней активной, а не рядом с ней', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final ids = await addAll(tester, app, ['Alpha', 'Parent']);
      final child = await addTask(tester, app, 'Child', parentId: ids[1]);
      await addTask(tester, app, 'Zed');
      await tester.runAsync(() => app.tasks.complete(ids[1]));
      await settle(tester);
      // Параллельная правка на другом устройстве: подзадачу вернули в работу.
      await tester.runAsync(
        () => device.services.mutator.update(EntityTypes.task, child, {
          TaskFields.isCompleted: false,
        }),
      );
      await settle(tester);
      await tester.runAsync(() async {
        final ws = await app.read();
        final v = await app.viewsRepo.load(
          ViewType.project,
          objectId: ws.inbox!.id,
        );
        await app.views.save(v, v.copyWith(showCompletedTasks: true));
      });
      await settle(tester);
      expect(find.text('Child'), findsOneWidget);

      // Ручки у подзадачи нет.
      await hoverAt(tester, tester.getCenter(dragRow('Child')));
      expect(find.byType(DragGrip), findsNothing);

      // Линия над подзадачей выполненной не ставится рядом с ней.
      final mouse = await startMouseDrag(
        tester,
        'Zed',
        belowHalf(tester, 'Child'),
      );
      final owner = session(tester)?.indicator?.owner;
      expect(owner, isNot(child));
      expect(owner, isNot(ids[1]));
      await mouse.up();
      await tester.pumpAndSettle();
    });
  });

  testWidgets('бросок выделенных на то же место и пустая отмена выделение не '
      'снимают', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await addAll(tester, app, ['Alpha', 'Beta', 'Gamma', 'Delta']);
      await ctrlClick(tester, ['Alpha', 'Beta']);
      expect(find.text('2 selected'), findsOneWidget);

      // Над «Gamma» — сразу после выбранных: порядок прежний.
      await mouseDrag(tester, 'Alpha', aboveHalf(tester, 'Gamma'));
      await settle(tester);
      expect(await inboxOrder(tester, app), [
        'Alpha',
        'Beta',
        'Gamma',
        'Delta',
      ]);
      expect(find.text('Task moved'), findsNothing);
      expect(find.text('2 selected'), findsOneWidget);
      expect(find.byType(SelectionToolbar), findsOneWidget);
    });
  });

  testWidgets('выход указателя за окно не сбрасывает точку отсчёта уровня', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final ids = await addAll(tester, app, ['Alpha', 'Beta']);

      final mouse = await startMouseDrag(
        tester,
        'Beta',
        const Offset(-30, -30),
      );
      // Вернулись прыжком: сдвиг считается от места, где взяли, а не где
      // указатель вошёл обратно.
      await mouse.moveTo(belowHalf(tester, 'Alpha', dx: 30));
      await tester.pump(const Duration(milliseconds: 16));
      await mouse.up();
      await tester.pumpAndSettle();
      await settle(tester);
      final ws = (await tester.runAsync(app.repo.load))!;
      expect(ws.task(ids[1])?.parentId, ids[0]);
    });
  });

  testWidgets('автопрокрутка не останавливается, когда указатель за краем '
      'окна; отпускание там ничего не пишет', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      for (var i = 1; i <= 30; i++) {
        await addTask(tester, app, 'T${i.toString().padLeft(2, '0')}');
      }
      final mouse = await startMouseDrag(tester, 'T01', const Offset(500, 840));
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).last)
          .position;
      expect(position.pixels, greaterThan(300));
      expect(session(tester)?.indicator, isNull);
      await mouse.up();
      await tester.pumpAndSettle();
      expect(session(tester), isNull);
      final order = await inboxOrder(tester, app);
      expect(order.first, 'T01');
    });
  });

  testWidgets('пока тащат, на строках под указателем нет ручки и «⋯»', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await addAll(tester, app, ['Alpha', 'Beta']);

      final mouse = await startMouseDrag(
        tester,
        'Alpha',
        tester.getCenter(dragRow('Beta')),
      );
      expect(find.byType(DragGrip), findsNothing);
      final menu = find.descendant(
        of: dragRow('Beta'),
        matching: find.byType(TaskRowMenuButton),
      );
      final visibility = tester.widget<Visibility>(
        find.ancestor(of: menu, matching: find.byType(Visibility)).first,
      );
      expect(visibility.visible, isFalse);
      await mouse.up();
      await tester.pumpAndSettle();
    });
  });

  testWidgets('долгое нажатие тащит одну задачу, даже если выделено '
      'несколько (help: несколько задач — только на компьютере)', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await addAll(tester, app, ['Alpha', 'Beta', 'Gamma', 'Delta']);
      await ctrlClick(tester, ['Alpha', 'Beta']);

      await longPressDrag(
        tester,
        'Alpha',
        belowHalf(tester, 'Delta', x: touchStart(tester, 'Alpha').dx),
      );
      await settle(tester);
      expect(await inboxOrder(tester, app), [
        'Beta',
        'Gamma',
        'Delta',
        'Alpha',
      ]);
    });
  });

  group('размонтирование посреди перетаскивания', () {
    testWidgets('смена экрана: сессия очищается, записи нет', (tester) async {
      await withApp(tester, (device) async {
        final app = AppCommands(device);
        await addAll(tester, app, ['Alpha', 'Beta', 'Gamma']);
        final mouse = await startMouseDrag(
          tester,
          'Alpha',
          belowHalf(tester, 'Beta'),
        );
        expect(session(tester), isNotNull);

        GoRouter.of(tester.element(find.byType(Scaffold).first))
            .go('/upcoming');
        await tester.pump(const Duration(milliseconds: 100));
        await mouse.up();
        await tester.pumpAndSettle();
        await settle(tester);
        expect(session(tester), isNull);
        expect(await inboxOrder(tester, app), ['Alpha', 'Beta', 'Gamma']);
      });
    });

    testWidgets('закрытие окна задачи: сессия очищается, записи нет', (
      tester,
    ) async {
      await withApp(tester, (device) async {
        final app = AppCommands(device);
        final parent = await addTask(tester, app, 'Parent');
        for (final n in ['S1', 'S2', 'S3']) {
          await addTask(tester, app, n, parentId: parent);
        }
        await tester.runAsync(() => app.tasks.setCollapsed(parent, true));
        await settle(tester);
        await tester.tap(find.text('Parent'));
        await tester.pumpAndSettle();
        expect(find.byType(TaskDialog), findsOneWidget);

        final mouse = await startMouseDrag(
          tester,
          'S1',
          belowHalf(tester, 'S3'),
        );
        final container = ProviderScope.containerOf(
          tester.element(find.byType(TaskDialog)),
        );
        expect(container.read(dragSessionProvider), isNotNull);

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.byType(TaskDialog), findsNothing);
        await mouse.up();
        await tester.pumpAndSettle();
        await settle(tester);
        expect(container.read(dragSessionProvider), isNull);
        final ws = (await tester.runAsync(app.repo.load))!;
        expect(
          [for (final t in ws.children(parent)) t.content],
          ['S1', 'S2', 'S3'],
        );
      });
    });

    testWidgets('задачу удалили на другом устройстве: бросок отказан без '
        'падения, остальное не тронуто', (tester) async {
      await withApp(tester, (device) async {
        final app = AppCommands(device);
        final ids = await addAll(tester, app, ['Alpha', 'Beta', 'Gamma']);
        final mouse = await startMouseDrag(
          tester,
          'Alpha',
          belowHalf(tester, 'Beta'),
        );
        await tester.runAsync(() => app.tasks.delete(ids[0]));
        await settle(tester);

        await moveInSteps(
          tester,
          mouse,
          belowHalf(tester, 'Beta'),
          belowHalf(tester, 'Gamma'),
          steps: 3,
        );
        await mouse.up();
        await tester.pumpAndSettle();
        await settle(tester);
        expect(session(tester), isNull);
        expect(await inboxOrder(tester, app), ['Beta', 'Gamma']);
      });
    });
  });
}
