import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:planner/domain/view_options.dart';
import 'package:planner/domain/workspace.dart';
import 'package:planner/features/common/state/drag_session.dart';
import 'package:planner/features/common/ui/drag_layer.dart';
import 'package:planner/features/common/ui/drag_source.dart';
import 'package:planner/features/sections/ui/section_drag.dart';
import 'package:planner/features/shell/ui/sidebar.dart';

import '../../app/support/pump_app.dart';
import '../support/app_commands.dart';
import '../support/drag_gestures.dart';

// Перетаскивание разделов (шаг M4.10, help «Introduction to sections»: «Click
// the drag handle icon to the left of the section»): ручка слева при
// наведении, долгое нажатие касанием; раздел едет с задачами. Локаль — en.
void main() {
  late String work;
  late List<String> sections;

  Finder header(String name) => find.ancestor(
    of: find.text(name),
    matching: find.byType(SectionHeaderDrag),
  );

  Future<Workspace> load(WidgetTester tester, AppCommands app) async =>
      (await tester.runAsync(app.repo.load))!;

  Future<List<String>> order(WidgetTester tester, AppCommands app) async {
    final ws = await load(tester, app);
    return [for (final s in ws.sectionsOf(work)) s.name];
  }

  DragSessionState? session(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(DragLayer).first))
          .read(dragSessionProvider);

  /// Проект с разделами [names] и задачей «Task <имя>» в каждом; открыт.
  Future<void> prepare(
    WidgetTester tester,
    AppCommands app,
    List<String> names, {
    bool open = true,
  }) async {
    work = (await tester.runAsync(() => app.projects.add(name: 'Work')))!;
    await settle(tester);
    sections = [];
    for (final n in names) {
      final id = (await tester.runAsync(
        () => app.sections.add(work, name: n),
      ))!;
      await settle(tester);
      await tester.runAsync(
        () => app.tasks.add(content: 'Task $n', projectId: work, sectionId: id),
      );
      await settle(tester);
      sections.add(id);
    }
    if (open) {
      await tester.tap(
        find.descendant(of: find.byType(Sidebar), matching: find.text('Work')),
      );
      await tester.pumpAndSettle();
    }
  }

  /// Взять раздел [name] за ручку и довести до [to], не отпуская.
  Future<TestGesture> grab(WidgetTester tester, String name, Offset to) async {
    await hoverAt(tester, tester.getCenter(header(name)));
    final grip = find.descendant(
      of: header(name),
      matching: find.byType(DragGrip),
    );
    return startMouseDragAt(tester, tester.getCenter(grip), to);
  }

  /// Взять раздел [name] за ручку, довести до [to] и отпустить.
  Future<void> drag(WidgetTester tester, String name, Offset to) async {
    final mouse = await grab(tester, name, to);
    await mouse.up();
    await tester.pumpAndSettle();
    await settle(tester);
  }

  Offset topOf(WidgetTester tester, String name) {
    final r = tester.getRect(header(name));
    return Offset(r.left + 120, r.top + 6);
  }

  testWidgets('ручка при наведении; перед разделом — порядок, задачи '
      'остаются в своём разделе, тоста нет', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await prepare(tester, app, ['Alpha', 'Beta', 'Gamma']);
      expect(find.byType(DragGrip), findsNothing);
      await hoverAt(tester, tester.getCenter(header('Alpha')));
      expect(find.byType(DragGrip), findsOneWidget);

      final mouse = await grab(tester, 'Alpha', topOf(tester, 'Gamma'));
      expect(session(tester)?.indicator?.mark, DropMark.above);
      await mouse.up();
      await tester.pumpAndSettle();
      await settle(tester);

      expect(await order(tester, app), ['Beta', 'Alpha', 'Gamma']);
      final ws = await load(tester, app);
      final task = ws
          .children(null, projectId: work, sectionId: sections[0])
          .single;
      expect(task.content, 'Task Alpha');
      expect(find.text('Undo'), findsNothing);
    });
  });

  testWidgets('над задачами последнего раздела — после него', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await prepare(tester, app, ['Alpha', 'Beta', 'Gamma']);

      final mouse = await grab(
        tester,
        'Alpha',
        tester.getCenter(find.text('Task Gamma')),
      );
      expect(session(tester)?.indicator?.mark, DropMark.below);
      await mouse.up();
      await tester.pumpAndSettle();
      await settle(tester);
      expect(await order(tester, app), ['Beta', 'Gamma', 'Alpha']);
    });
  });

  testWidgets('долгое нажатие на заголовке перетаскивает раздел касанием', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await prepare(tester, app, ['Alpha', 'Beta', 'Gamma']);

      await longPressDragAt(
        tester,
        tester.getCenter(find.text('Alpha')),
        topOf(tester, 'Gamma'),
      );
      await settle(tester);
      expect(await order(tester, app), ['Beta', 'Alpha', 'Gamma']);
    });
  });

  testWidgets('нажатие на стрелку по-прежнему сворачивает раздел', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await prepare(tester, app, ['Alpha', 'Beta']);
      await tester.tap(
        find.descendant(
          of: header('Alpha'),
          matching: find.byIcon(Icons.expand_more),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Task Alpha'), findsNothing);
      expect(find.text('Task Beta'), findsOneWidget);
    });
  });

  testWidgets('отпускание вне слота ничего не пишет', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await prepare(tester, app, ['Alpha', 'Beta']);
      final mouse = await grab(tester, 'Alpha', const Offset(900, 24));
      expect(session(tester)?.indicator, isNull);
      await mouse.up();
      await tester.pumpAndSettle();
      expect(await order(tester, app), ['Alpha', 'Beta']);
    });
  });

  testWidgets('при сортировке проекта разделы переставляются, при '
      'группировке разделов нет', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await prepare(tester, app, ['Alpha', 'Beta']);
      Future<void> save(ViewOptions Function(ViewOptions) change) async {
        await tester.runAsync(() async {
          final v = await app.viewsRepo.load(ViewType.project, objectId: work);
          await app.views.save(v, change(v));
        });
        await settle(tester);
      }

      await save((v) => v.copyWith(sorting: Sorting.alphabetically));
      await drag(tester, 'Beta', topOf(tester, 'Alpha'));
      expect(await order(tester, app), ['Beta', 'Alpha']);

      await save((v) => v.copyWith(grouping: Grouping.priority));
      expect(find.byType(SectionHeaderDrag), findsNothing);
    });
  });

  testWidgets('архивные разделы — не источник и не цель', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await prepare(tester, app, ['Alpha', 'Beta']);
      await tester.runAsync(() => app.sections.archive(sections[1]));
      await settle(tester);
      await tester.runAsync(() async {
        final v = await app.viewsRepo.load(ViewType.project, objectId: work);
        await app.views.save(v, v.copyWith(showCompletedTasks: true));
      });
      await settle(tester);
      // Архивный раздел виден, но без перетаскивания.
      expect(find.text('Beta'), findsOneWidget);
      expect(header('Beta'), findsNothing);
      // Бросок на архивный раздел места не имеет.
      final mouse = await grab(
        tester,
        'Alpha',
        tester.getCenter(find.text('Beta')),
      );
      expect(session(tester)?.indicator?.owner, isNot('sec:${sections[1]}'));
      await mouse.up();
      await tester.pumpAndSettle();
      await settle(tester);
      expect(await order(tester, app), ['Alpha']);
    });
  });

  testWidgets('в архивном проекте разделы не перетаскиваются', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await prepare(tester, app, ['Alpha', 'Beta'], open: false);
      await tester.runAsync(() => app.projects.archive(work));
      await settle(tester);
      GoRouter.of(tester.element(find.byType(Scaffold).first))
          .go('/project/$work');
      await tester.pumpAndSettle();
      expect(find.text('Alpha'), findsOneWidget);
      expect(header('Alpha'), findsNothing);
    });
  });
}
