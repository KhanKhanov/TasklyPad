import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:planner/domain/models.dart';
import 'package:planner/domain/view_options.dart';
import 'package:planner/features/common/state/drag_session.dart';
import 'package:planner/features/common/ui/drag_layer.dart';
import 'package:planner/features/common/ui/drag_rows.dart';
import 'package:planner/features/common/ui/drag_source.dart';
import 'package:planner/features/shell/ui/sidebar.dart';
import 'package:planner/features/tasks/ui/selection_toolbar.dart';
import 'package:planner/features/tasks/ui/task_drag.dart';
import 'package:planner/features/tasks/ui/task_drag_ghost.dart';
import 'package:planner/features/tasks/ui/task_dialog.dart';

import '../../app/support/pump_app.dart';
import '../support/app_commands.dart';
import '../support/drag_gestures.dart';

// Перетаскивание задач в проекте (шаг M4.9, решения 1А–4А): ручка мышью,
// долгое нажатие касанием, порядок, раздел, уровень, сайдбар, окно задачи.
// Локаль — en; сегодня — пятница 23.10.2026.
void main() {
  Future<String> addTask(
    WidgetTester tester,
    AppCommands app,
    String name, {
    String? projectId,
    String? sectionId,
    String? parentId,
  }) async {
    final id = (await tester.runAsync(
      () => app.tasks.add(
        content: name,
        projectId: projectId,
        sectionId: sectionId,
        parentId: parentId,
      ),
    ))!;
    await settle(tester);
    return id;
  }

  Future<List<String>> addAll(
    WidgetTester tester,
    AppCommands app,
    List<String> names,
  ) async => [for (final n in names) await addTask(tester, app, n)];

  Future<Task> load(WidgetTester tester, AppCommands app, String id) async =>
      (await tester.runAsync(app.repo.load))!.task(id)!;

  /// Названия верхнего уровня «Входящих» по порядку.
  Future<List<String>> inboxOrder(WidgetTester tester, AppCommands app) async {
    final ws = (await tester.runAsync(app.repo.load))!;
    return [
      for (final t in ws.children(null, projectId: ws.inbox!.id)) t.content,
    ];
  }

  DragSessionState? session(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(DragLayer).first))
          .read(dragSessionProvider);

  Future<void> ctrlZ(WidgetTester tester) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle(tester);
  }

  testWidgets('ручка появляется при наведении мыши и пропадает без неё', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await addAll(tester, app, ['Alpha', 'Beta']);
      expect(find.byType(DragGrip), findsNothing);

      final mouse = await hoverRow(tester, 'Alpha');
      expect(find.byType(DragGrip), findsOneWidget);

      await mouse.moveTo(const Offset(900, 20));
      await tester.pump();
      expect(find.byType(DragGrip), findsNothing);
    });
  });

  testWidgets('перестановка: за ручку вниз — порядок и тост; `Ctrl+Z` '
      'возвращает', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await addAll(tester, app, ['Alpha', 'Beta', 'Gamma']);

      await mouseDrag(tester, 'Alpha', belowHalf(tester, 'Gamma'));
      await settle(tester);
      expect(await inboxOrder(tester, app), ['Beta', 'Gamma', 'Alpha']);
      expect(find.text('Task moved'), findsOneWidget);
      expect(session(tester), isNull);

      await ctrlZ(tester);
      expect(await inboxOrder(tester, app), ['Alpha', 'Beta', 'Gamma']);
    });
  });

  testWidgets('перестановка вверх: верхняя половина первой строки — '
      'первой', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await addAll(tester, app, ['Alpha', 'Beta', 'Gamma']);

      await mouseDrag(tester, 'Gamma', aboveHalf(tester, 'Alpha'));
      await settle(tester);
      expect(await inboxOrder(tester, app), ['Gamma', 'Alpha', 'Beta']);
    });
  });

  testWidgets('образ и линия видны, пока тащат; исходная строка бледнеет', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await addAll(tester, app, ['Alpha', 'Beta', 'Gamma']);

      final mouse = await startMouseDrag(
        tester,
        'Alpha',
        belowHalf(tester, 'Beta'),
      );
      // Образ — вся строка: с названием и шириной почти со строку
      // (решение 5А «M4.10a»).
      final ghost = find.byType(TaskDragGhost);
      expect(ghost, findsOneWidget);
      expect(
        find.descendant(of: ghost, matching: find.text('Alpha')),
        findsOneWidget,
      );
      expect(
        tester.getSize(ghost).width,
        greaterThan(tester.getSize(find.byType(TaskDragRow).first).width - 80),
      );
      final state = session(tester)!;
      expect(state.sources.length, 1);
      expect(state.indicator?.mark, DropMark.below);
      expect(
        find.descendant(
          of: find.byType(TaskDragRow).first,
          matching: find.byType(Opacity),
        ),
        findsWidgets,
      );
      await mouse.up();
      await tester.pumpAndSettle();
    });
  });

  testWidgets('сдвиг вправо — подзадача предыдущей, влево — снова наверх', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final ids = await addAll(tester, app, ['Alpha', 'Beta', 'Gamma']);

      final drag = await startMouseDrag(
        tester,
        'Gamma',
        // Уровень меняется после 1¼ шага (35 px) — гистерезис M4.10a.
        belowHalf(tester, 'Beta', dx: 40),
      );
      // Линия показывает то же, что запишется: под «Beta», на её уровень
      // глубже (поле под ручку + шаг уровня).
      final line = session(tester)!.indicator!;
      expect(line.owner, ids[1]);
      expect(line.mark, DropMark.below);
      expect(line.indent, dragGutter + 28);
      await drag.up();
      await tester.pumpAndSettle();
      await settle(tester);
      expect((await load(tester, app, ids[2])).parentId, ids[1]);

      await mouseDrag(
        tester,
        'Gamma',
        belowHalf(
          tester,
          'Gamma',
          // Ручка подзадачи стоит на уровень правее; влево — шаг уровня.
          x: gripX(tester, 'Gamma') + 28,
          dx: -30,
        ),
      );
      await settle(tester);
      expect((await load(tester, app, ids[2])).parentId, isNull);
      expect(await inboxOrder(tester, app), ['Alpha', 'Beta', 'Gamma']);
    });
  });

  testWidgets('сдвиг на шаг уровня (30 px) — ещё не подзадача: случайный '
      'сдвиг мыши уровень не меняет (уточнение 12.11.2026)', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final ids = await addAll(tester, app, ['Alpha', 'Beta', 'Gamma']);
      await mouseDrag(tester, 'Gamma', belowHalf(tester, 'Beta', dx: 30));
      await settle(tester);
      expect((await load(tester, app, ids[2])).parentId, isNull);
    });
  });

  testWidgets('предел четырёх уровней: глубже линии нет и ничего не '
      'пишется', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final a = await addTask(tester, app, 'L1');
      final b = await addTask(tester, app, 'L2', parentId: a);
      final c = await addTask(tester, app, 'L3', parentId: b);
      await addTask(tester, app, 'L4', parentId: c);
      final loose = await addTask(tester, app, 'Loose');
      final deep = await addTask(tester, app, 'Deep');
      await addTask(tester, app, 'Child', parentId: deep);

      // «Deep» с подзадачей — высота 2. Между «L3» и «L4» (L4 — уровень 4)
      // она не встанет: под L3 максимум уровень 3, а выше L4 — нельзя.
      final mouse = await startMouseDrag(
        tester,
        'Deep',
        belowHalf(tester, 'L3', dx: 120),
      );
      expect(session(tester)?.indicator, isNull);
      await mouse.up();
      await tester.pumpAndSettle();
      expect((await load(tester, app, deep)).parentId, isNull);
      expect(find.text('Task moved'), findsNothing);
      expect((await load(tester, app, loose)).parentId, isNull);
    });
  });

  testWidgets('бросок на «Входящие» в сайдбаре — в конец; на проект '
      'в сайдбаре — в конец проекта', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final work = (await tester.runAsync(
        () => app.projects.add(name: 'Work', isFavorite: true),
      ))!;
      await settle(tester);
      final ids = await addAll(tester, app, ['Alpha', 'Beta']);
      await addTask(tester, app, 'Old', projectId: work);

      final target = tester.getCenter(find.text('Work').first);
      await mouseDrag(tester, 'Alpha', target);
      await settle(tester);

      final moved = await load(tester, app, ids[0]);
      expect(moved.projectId, work);
      expect(find.text('Task moved'), findsOneWidget);
      final ws = (await tester.runAsync(app.repo.load))!;
      expect(
        [for (final t in ws.children(null, projectId: work)) t.content],
        ['Old', 'Alpha'],
      );

      await ctrlZ(tester);
      expect((await load(tester, app, ids[0])).projectId, ws.inbox!.id);
    });
  });

  testWidgets('отпускание вне слота ничего не пишет; `Esc` не отменяет', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await addAll(tester, app, ['Alpha', 'Beta']);

      final mouse = await startMouseDrag(
        tester,
        'Alpha',
        const Offset(900, 24),
      );
      expect(session(tester)?.indicator, isNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(session(tester), isNotNull);
      await mouse.up();
      await tester.pumpAndSettle();

      expect(await inboxOrder(tester, app), ['Alpha', 'Beta']);
      expect(find.text('Task moved'), findsNothing);
    });
  });

  testWidgets('долгое нажатие перетаскивает, короткое касание открывает '
      'окно задачи', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await addAll(tester, app, ['Alpha', 'Beta', 'Gamma']);

      await longPressDrag(
        tester,
        'Alpha',
        belowHalf(tester, 'Gamma', x: touchStart(tester, 'Alpha').dx),
      );
      await settle(tester);
      expect(await inboxOrder(tester, app), ['Beta', 'Gamma', 'Alpha']);
      expect(find.byType(TaskDialog), findsNothing);

      await tester.tap(find.text('Beta'));
      await tester.pumpAndSettle();
      expect(find.byType(TaskDialog), findsOneWidget);
    });
  });

  Finder inSidebar(String text) =>
      find.descendant(of: find.byType(Sidebar), matching: find.text(text));

  /// Открыть экран по адресу, как переход по ссылке.
  Future<void> goTo(WidgetTester tester, String location) async {
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go(location);
    await tester.pumpAndSettle();
  }

  /// Мышь над текстом [content]; true — ручка появилась.
  Future<bool> gripShowsOver(WidgetTester tester, String content) async {
    await hoverAt(tester, tester.getCenter(find.text(content)));
    return find.byType(DragGrip).evaluate().isNotEmpty;
  }

  Future<void> saveView(
    WidgetTester tester,
    AppCommands app,
    ViewOptions Function(ViewOptions) change,
  ) async {
    await tester.runAsync(() async {
      final ws = await app.read();
      final v = await app.viewsRepo.load(
        ViewType.project,
        objectId: ws.inbox!.id,
      );
      await app.views.save(v, change(v));
    });
    await settle(tester);
  }

  testWidgets('в раздел: на заголовок раздела — первой в нём; под строку '
      'раздела — в этот раздел', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final work = (await tester.runAsync(
        () => app.projects.add(name: 'Work'),
      ))!;
      await settle(tester);
      final sec = (await tester.runAsync(
        () => app.sections.add(work, name: 'Sec'),
      ))!;
      await settle(tester);
      final first = await addTask(tester, app, 'Alpha', projectId: work);
      final second = await addTask(tester, app, 'Beta', projectId: work);
      await addTask(tester, app, 'In1', projectId: work, sectionId: sec);
      await tester.tap(inSidebar('Work').first);
      await tester.pumpAndSettle();

      await mouseDrag(tester, 'Alpha', tester.getCenter(find.text('Sec')));
      await settle(tester);
      expect((await load(tester, app, first)).sectionId, sec);

      await mouseDrag(tester, 'Beta', belowHalf(tester, 'In1'));
      await settle(tester);
      final moved = await load(tester, app, second);
      expect(moved.sectionId, sec);
      final ws = (await tester.runAsync(app.repo.load))!;
      expect(
        [
          for (final t in ws.children(null, projectId: work, sectionId: sec))
            t.content,
        ],
        ['Alpha', 'In1', 'Beta'],
      );
    });
  });

  group('перетаскивания нет', () {
    testWidgets('при группировке', (tester) async {
      await withApp(tester, (device) async {
        final app = AppCommands(device);
        await addAll(tester, app, ['Alpha']);
        await saveView(
          tester,
          app,
          (v) => v.copyWith(grouping: Grouping.priority),
        );
        expect(await gripShowsOver(tester, 'Alpha'), isFalse);
      });
    });

    testWidgets('при сортировке с направлением', (tester) async {
      await withApp(tester, (device) async {
        final app = AppCommands(device);
        await addAll(tester, app, ['Alpha', 'Beta']);
        await saveView(
          tester,
          app,
          (v) => v.copyWith(sorting: Sorting.alphabetically),
        );
        expect(await gripShowsOver(tester, 'Alpha'), isFalse);
      });
    });

    testWidgets('в метке', (tester) async {
      await withApp(tester, (device) async {
        final app = AppCommands(device);
        final label = (await tester.runAsync(
          () => app.labels.add(name: 'Home'),
        ))!;
        await settle(tester);
        await tester.runAsync(
          () => app.tasks.add(content: 'Alpha', labelIds: {label}),
        );
        await settle(tester);
        await goTo(tester, '/label/$label');
        expect(find.text('Alpha'), findsOneWidget);
        expect(await gripShowsOver(tester, 'Alpha'), isFalse);
      });
    });

    testWidgets('в архивном проекте', (tester) async {
      await withApp(tester, (device) async {
        final app = AppCommands(device);
        final old = (await tester.runAsync(
          () => app.projects.add(name: 'Old'),
        ))!;
        await settle(tester);
        await addTask(tester, app, 'Alpha', projectId: old);
        await tester.runAsync(() => app.projects.archive(old));
        await settle(tester);
        await goTo(tester, '/project/$old');
        expect(find.text('Alpha'), findsOneWidget);
        expect(await gripShowsOver(tester, 'Alpha'), isFalse);
      });
    });

    testWidgets('у выполненной задачи', (tester) async {
      await withApp(tester, (device) async {
        final app = AppCommands(device);
        final ids = await addAll(tester, app, ['Alpha', 'Done']);
        await tester.runAsync(() => app.tasks.complete(ids[1]));
        await settle(tester);
        await saveView(
          tester,
          app,
          (v) => v.copyWith(showCompletedTasks: true),
        );
        expect(find.text('Done'), findsOneWidget);
        expect(await gripShowsOver(tester, 'Done'), isFalse);
        expect(await gripShowsOver(tester, 'Alpha'), isTrue);
      });
    });
  });

  testWidgets('несколько выделенных тащатся вместе; `Ctrl+Z` возвращает', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await addAll(tester, app, ['Alpha', 'Beta', 'Gamma', 'Delta']);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.tap(find.text('Alpha'));
      await tester.tap(find.text('Beta'));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      final mouse = await startMouseDrag(
        tester,
        'Alpha',
        belowHalf(tester, 'Delta'),
      );
      expect(session(tester)?.sources.length, 2);
      await mouse.up();
      await tester.pumpAndSettle();
      await settle(tester);
      expect(await inboxOrder(tester, app), [
        'Gamma',
        'Delta',
        'Alpha',
        'Beta',
      ]);
      expect(find.text('Task moved'), findsOneWidget);
      // Бросок удался — выделение снято.
      expect(find.text('2 selected'), findsNothing);

      await ctrlZ(tester);
      expect(await inboxOrder(tester, app), [
        'Alpha',
        'Beta',
        'Gamma',
        'Delta',
      ]);
    });
  });

  testWidgets('невыделенная при выделении тащится одна, выделение остаётся', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await addAll(tester, app, ['Alpha', 'Beta', 'Gamma']);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.tap(find.text('Alpha'));
      await tester.tap(find.text('Beta'));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      await mouseDrag(tester, 'Gamma', aboveHalf(tester, 'Alpha'));
      await settle(tester);
      expect(await inboxOrder(tester, app), ['Gamma', 'Alpha', 'Beta']);
      expect(find.byType(SelectionToolbar), findsOneWidget);
      expect(find.text('2 selected'), findsOneWidget);
    });
  });

  testWidgets('автопрокрутка: указатель у края, строка разобрана — бросок '
      'в место под указателем', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final work = (await tester.runAsync(
        () => app.projects.add(name: 'Work'),
      ))!;
      await settle(tester);
      // Шесть разделов по пять задач: каждый раздел — отдельный элемент
      // списка, поэтому ушедший за экран раздел разбирается.
      final sections = <String>[];
      for (var k = 1; k <= 6; k++) {
        final id = (await tester.runAsync(
          () => app.sections.add(work, name: 'Sec $k'),
        ))!;
        await settle(tester);
        sections.add(id);
        for (var n = 1; n <= 5; n++) {
          await tester.runAsync(
            () => app.tasks.add(
              content: 'Task $k-$n',
              projectId: work,
              sectionId: id,
            ),
          );
          await settle(tester);
        }
      }
      await tester.tap(inSidebar('Work').first);
      await tester.pumpAndSettle();

      final source = (await tester.runAsync(app.repo.load))!
          .children(null, projectId: work, sectionId: sections.first)
          .first
          .id;
      final mouse = await startMouseDrag(
        tester,
        'Task 1-1',
        // Тот же X, что у ручки: уровень не меняется.
        Offset(gripX(tester, 'Task 1-1'), 785),
      );
      for (var i = 0; i < 120; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      // Исходная строка уехала за экран и разобрана ленивым списком.
      expect(find.text('Task 1-1'), findsOneWidget); // только образ
      expect(
        find.descendant(
          of: find.byType(TaskDragRow),
          matching: find.text('Task 1-1'),
        ),
        findsNothing,
      );
      // Линия может стоять на заголовке раздела (рамка раздела): ждём кадров,
      // пока указатель не окажется на строке задачи — исход один.
      for (var i = 0; i < 40; i++) {
        final owner = session(tester)?.indicator?.owner;
        if (owner is String && !owner.startsWith('section:')) break;
        await tester.pump(const Duration(milliseconds: 16));
      }
      final mark = session(tester)!.indicator!;
      final owner = mark.owner as String;
      expect(owner, isNot(startsWith('section:')));
      await mouse.up();
      await tester.pumpAndSettle();
      await settle(tester);

      // Бросок попал туда, куда показывала линия под неподвижным указателем.
      final ws = (await tester.runAsync(app.repo.load))!;
      final moved = ws.task(source)!;
      final near = ws.task(owner)!;
      expect(moved.sectionId, near.sectionId);
      final ids = [
        for (final t in ws.children(
          null,
          projectId: work,
          sectionId: near.sectionId,
        ))
          t.id,
      ];
      expect(
        ids.indexOf(source),
        ids.indexOf(owner) + (mark.mark == DropMark.below ? 1 : -1),
      );
      expect(moved.sectionId, isNot(sections.first));
    });
  });

  group('окно задачи', () {
    Future<List<String>> subs(
      WidgetTester tester,
      AppCommands app,
      String parent,
    ) async {
      final ws = (await tester.runAsync(app.repo.load))!;
      return [for (final t in ws.children(parent)) t.content];
    }

    testWidgets('подзадачи переставляются, из родителя не выходят; бросок '
        'вне окна отменяется', (tester) async {
      await withApp(tester, (device) async {
        final app = AppCommands(device);
        final parent = await addTask(tester, app, 'Parent');
        await addTask(tester, app, 'S1', parentId: parent);
        await addTask(tester, app, 'S2', parentId: parent);
        await addTask(tester, app, 'S3', parentId: parent);
        // Свёрнутый родитель: подзадач нет в списке под окном.
        await tester.runAsync(() => app.tasks.setCollapsed(parent, true));
        await settle(tester);
        await tester.tap(find.text('Parent'));
        await tester.pumpAndSettle();
        expect(find.byType(TaskDialog), findsOneWidget);

        await mouseDrag(tester, 'S1', belowHalf(tester, 'S3'));
        await settle(tester);
        expect(await subs(tester, app, parent), ['S2', 'S3', 'S1']);

        // Сдвиг влево подзадачу из родителя не выводит.
        await mouseDrag(
          tester,
          'S2',
          belowHalf(tester, 'S1', dx: -60, x: gripX(tester, 'S2')),
        );
        await settle(tester);
        final ws = (await tester.runAsync(app.repo.load))!;
        for (final t in ws.children(parent)) {
          expect(t.parentId, parent);
        }
        expect(await subs(tester, app, parent), hasLength(3));

        // Вне окна — на затемнении — ничего не пишется.
        final before = await subs(tester, app, parent);
        await mouseDrag(tester, 'S3', const Offset(5, 5));
        await settle(tester);
        expect(await subs(tester, app, parent), before);
      });
    });
  });
}
