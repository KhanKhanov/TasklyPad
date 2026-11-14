import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:planner/domain/workspace.dart';
import 'package:planner/features/common/state/drag_session.dart';
import 'package:planner/features/common/ui/app_switch.dart';
import 'package:planner/features/common/ui/drag_layer.dart';
import 'package:planner/features/projects/ui/project_drag.dart';
import 'package:planner/features/projects/ui/project_parts.dart';
import 'package:planner/features/shell/ui/sidebar.dart';

import '../../app/support/pump_app.dart';
import '../support/app_commands.dart';
import '../support/drag_gestures.dart';

// Перетаскивание проектов (шаг M4.10, help «Introduction to projects»: «you
// drag the project itself»): вся строка в сайдбаре и на экране «Мои
// проекты», уровень — сдвигом по X (шаг 16, три уровня). Локаль — en.
void main() {
  Finder inSidebar(String text) =>
      find.descendant(of: find.byType(Sidebar), matching: find.text(text));

  /// Строка проекта в дереве сайдбара (не «Избранное»: там не источник).
  Finder tile(String name) => find
      .ancestor(of: inSidebar(name), matching: find.byType(ProjectDragTile))
      .first;

  Future<String> addProject(
    WidgetTester tester,
    AppCommands app,
    String name, {
    String? parentId,
  }) async {
    final id = (await tester.runAsync(
      () => app.projects.add(name: name, parentId: parentId),
    ))!;
    await settle(tester);
    return id;
  }

  Future<Workspace> load(WidgetTester tester, AppCommands app) async =>
      (await tester.runAsync(app.repo.load))!;

  Future<List<String>> topNames(WidgetTester tester, AppCommands app) async {
    final ws = await load(tester, app);
    return [
      for (final p in ws.childProjects(null))
        if (!p.isInbox) p.name,
    ];
  }

  DragSessionState? session(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(DragLayer).first))
          .read(dragSessionProvider);

  Offset from(WidgetTester tester, String name) =>
      inside(tester, tile(name), dx: 60);

  /// Нижняя половина строки; [dx] — сдвиг уровня.
  Offset below(WidgetTester tester, String name, {double dx = 0}) {
    final r = tester.getRect(tile(name));
    return Offset(r.left + 60 + dx, r.bottom - 5);
  }

  Offset above(WidgetTester tester, String name, {double dx = 0}) {
    final r = tester.getRect(tile(name));
    return Offset(r.left + 60 + dx, r.top + 5);
  }

  Future<void> goTo(WidgetTester tester, String location) async {
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go(location);
    await tester.pumpAndSettle();
  }

  testWidgets('порядок: за строку мышью — новый порядок, тоста нет', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      for (final n in ['Alpha', 'Beta', 'Gamma']) {
        await addProject(tester, app, n);
      }

      await mouseDragAt(tester, from(tester, 'Alpha'), below(tester, 'Gamma'));
      await settle(tester);
      expect(await topNames(tester, app), ['Beta', 'Gamma', 'Alpha']);
      expect(find.text('Undo'), findsNothing);
      expect(session(tester), isNull);

      await mouseDragAt(tester, from(tester, 'Alpha'), above(tester, 'Beta'));
      await settle(tester);
      expect(await topNames(tester, app), ['Alpha', 'Beta', 'Gamma']);
    });
  });

  testWidgets('сдвиг вправо — подпроект предыдущего, влево — снова наверх', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final ids = [
        for (final n in ['Alpha', 'Beta', 'Gamma'])
          await addProject(tester, app, n),
      ];

      await mouseDragAt(
        tester,
        from(tester, 'Gamma'),
        below(tester, 'Beta', dx: 20),
      );
      await settle(tester);
      expect((await load(tester, app)).projectParent(ids[2]), ids[1]);

      await mouseDragAt(
        tester,
        from(tester, 'Gamma'),
        below(tester, 'Gamma', dx: -20),
      );
      await settle(tester);
      expect((await load(tester, app)).projectParent(ids[2]), isNull);
      expect(await topNames(tester, app), ['Alpha', 'Beta', 'Gamma']);
    });
  });

  testWidgets('подпроекты едут с родителем', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final alpha = await addProject(tester, app, 'Alpha');
      final kid = await addProject(tester, app, 'Kid', parentId: alpha);
      await addProject(tester, app, 'Beta');

      await mouseDragAt(tester, from(tester, 'Alpha'), below(tester, 'Beta'));
      await settle(tester);
      expect(await topNames(tester, app), ['Beta', 'Alpha']);
      expect((await load(tester, app)).projectParent(kid), alpha);
    });
  });

  testWidgets('предел трёх уровней: глубже линии нет и ничего не '
      'пишется', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final p1 = await addProject(tester, app, 'P1');
      final p2 = await addProject(tester, app, 'P2', parentId: p1);
      await addProject(tester, app, 'P3', parentId: p2);
      final free = await addProject(tester, app, 'Free');
      await addProject(tester, app, 'FreeKid', parentId: free);

      // «Free» с подпроектом — высота 2: между «P2» (уровень 2) и «P3»
      // (уровень 3) она не встанет.
      final mouse = await startMouseDragAt(
        tester,
        from(tester, 'Free'),
        below(tester, 'P2'),
      );
      expect(session(tester)?.indicator, isNull);
      await mouse.up();
      await tester.pumpAndSettle();
      await settle(tester);
      expect((await load(tester, app)).projectParent(free), isNull);
    });
  });

  testWidgets('клик по строке открывает проект, как раньше', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await addProject(tester, app, 'Alpha');
      await tester.tap(tile('Alpha'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(ProjectHeader),
          matching: find.text('Alpha'),
        ),
        findsOneWidget,
      );
    });
  });

  testWidgets('долгое нажатие перетаскивает проект касанием', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      for (final n in ['Alpha', 'Beta', 'Gamma']) {
        await addProject(tester, app, n);
      }

      await longPressDragAt(
        tester,
        from(tester, 'Alpha'),
        below(tester, 'Gamma'),
      );
      await settle(tester);
      expect(await topNames(tester, app), ['Beta', 'Gamma', 'Alpha']);
    });
  });

  testWidgets('отпускание вне слота ничего не пишет', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      for (final n in ['Alpha', 'Beta']) {
        await addProject(tester, app, n);
      }
      final mouse = await startMouseDragAt(
        tester,
        from(tester, 'Alpha'),
        const Offset(900, 24),
      );
      expect(session(tester)?.indicator, isNull);
      await mouse.up();
      await tester.pumpAndSettle();
      expect(await topNames(tester, app), ['Alpha', 'Beta']);
    });
  });

  testWidgets('«Входящие» — не источник; проект на задаче места не имеет', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await addProject(tester, app, 'Alpha');
      await addProject(tester, app, 'Beta');
      await tester.runAsync(() => app.tasks.add(content: 'Task'));
      await settle(tester);

      // «Входящие» тащить нельзя: строка без перетаскивания.
      final inbox = inside(tester, inSidebar('Inbox').first, dx: 20);
      final first = await startMouseDragAt(
        tester,
        inbox,
        inbox + const Offset(0, 120),
      );
      expect(session(tester), isNull);
      await first.up();
      await tester.pumpAndSettle();

      // Проект, брошенный на задачу, — ничего.
      final second = await startMouseDragAt(
        tester,
        from(tester, 'Alpha'),
        tester.getCenter(find.text('Task')),
      );
      expect(session(tester)?.indicator, isNull);
      await second.up();
      await tester.pumpAndSettle();
      expect(await topNames(tester, app), ['Alpha', 'Beta']);
    });
  });

  testWidgets('задача, брошенная на проект в сайдбаре, по-прежнему '
      'переносится', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final alpha = await addProject(tester, app, 'Alpha');
      final task = (await tester.runAsync(
        () => app.tasks.add(content: 'Task'),
      ))!;
      await settle(tester);

      // Мышь берёт задачу за ручку — через наведение на строку.
      final mouse = await hoverAt(tester, tester.getCenter(find.text('Task')));
      final grip = find.byTooltip('Drag to move');
      final at = tester.getCenter(grip);
      await mouse.moveTo(at);
      await mouse.down(at);
      await tester.pump();
      await moveInSteps(tester, mouse, at, tester.getCenter(tile('Alpha')));
      await mouse.up();
      await tester.pumpAndSettle();
      await settle(tester);
      expect((await load(tester, app)).task(task)?.projectId, alpha);
    });
  });

  testWidgets('экран «Мои проекты»: порядок меняется и в сайдбаре', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      for (final n in ['Alpha', 'Beta', 'Gamma']) {
        await addProject(tester, app, n);
      }
      await goTo(tester, '/projects');
      final onScreen = find.descendant(
        of: find.byType(ListView).last,
        matching: find.text('Alpha'),
      );
      final screenTile = find.ancestor(
        of: onScreen,
        matching: find.byType(ProjectDragTile),
      );
      final gamma = find.ancestor(
        of: find.descendant(
          of: find.byType(ListView).last,
          matching: find.text('Gamma'),
        ),
        matching: find.byType(ProjectDragTile),
      );
      await mouseDragAt(
        tester,
        inside(tester, screenTile, dx: 80),
        Offset(
          tester.getRect(gamma).left + 80,
          tester.getRect(gamma).bottom - 5,
        ),
      );
      await settle(tester);
      expect(await topNames(tester, app), ['Beta', 'Gamma', 'Alpha']);
    });
  });

  testWidgets('архивный проект — не источник', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final old = await addProject(tester, app, 'Old');
      await addProject(tester, app, 'Beta');
      await tester.runAsync(() => app.projects.archive(old));
      await settle(tester);
      await goTo(tester, '/projects');
      await tester.tap(find.byType(AppSwitch));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(ListView).last,
          matching: find.byType(ProjectDragTile),
        ),
        findsNothing,
      );

      final at = tester.getCenter(find.text('Old').last);
      final mouse = await startMouseDragAt(
        tester,
        at,
        at + const Offset(0, 90),
      );
      expect(session(tester), isNull);
      await mouse.up();
      await tester.pumpAndSettle();
      expect(await topNames(tester, app), ['Beta']);
    });
  });

  /// Нажать мышью в [at], сдвинуть на [dx] пикселей вправо и отпустить.
  Future<void> clickWithJitter(
    WidgetTester tester,
    Offset at,
    double dx,
  ) async {
    final mouse = await hoverAt(tester, at);
    await mouse.down(at);
    await tester.pump();
    await mouse.moveTo(at + Offset(dx, 0));
    await tester.pump();
    await mouse.up();
    await tester.pumpAndSettle();
  }

  testWidgets('клик со сдвигом мыши на 2–10 px открывает проект и ничего '
      'не пишет (порог — как у касания, а не 1 px)', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final ids = [
        for (final n in ['Alpha', 'Beta', 'Gamma'])
          await addProject(tester, app, n),
      ];
      for (final dx in [2.0, 6.0, 10.0]) {
        await goTo(tester, '/');
        await clickWithJitter(tester, from(tester, 'Beta'), dx);
        expect(
          find.descendant(
            of: find.byType(ProjectHeader),
            matching: find.text('Beta'),
          ),
          findsOneWidget,
          reason: 'сдвиг $dx px',
        );
      }
      final ws = await load(tester, app);
      expect(ws.projectParent(ids[1]), isNull);
      expect(await topNames(tester, app), ['Alpha', 'Beta', 'Gamma']);
      expect(find.text('Undo'), findsNothing);
    });
  });

  testWidgets('стрелка и «⋯» внутри строки проекта работают при '
      'перетаскиваемой строке', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final alpha = await addProject(tester, app, 'Alpha');
      await addProject(tester, app, 'Kid', parentId: alpha);
      expect(inSidebar('Kid'), findsOneWidget);

      await clickWithJitter(
        tester,
        tester.getCenter(
          find.descendant(
            of: tile('Alpha'),
            matching: find.byIcon(Icons.expand_more),
          ),
        ),
        3,
      );
      await settle(tester);
      expect(inSidebar('Kid'), findsNothing);

      await hoverAt(tester, from(tester, 'Alpha'));
      await tester.tap(
        find.descendant(
          of: tile('Alpha'),
          matching: find.byTooltip('More actions'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Edit'), findsWidgets);
    });
  });
}
