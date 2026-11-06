import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:planner/features/common/state/drag_session.dart';
import 'package:planner/features/common/ui/drag_layer.dart';
import 'package:planner/features/common/ui/drag_source.dart';
import 'package:planner/features/labels/ui/label_drag.dart';
import 'package:planner/features/shell/ui/sidebar.dart';

import '../../app/support/pump_app.dart';
import '../support/app_commands.dart';
import '../support/drag_gestures.dart';

// Перетаскивание меток на странице «Фильтры и метки»: вся строка, без ручки
// (порядок меток в help не описан — допущение О-69). Локаль — en.
void main() {
  Finder tile(String name) =>
      find.ancestor(of: find.text(name), matching: find.byType(LabelDragTile));

  Future<List<String>> names(WidgetTester tester, AppCommands app) async {
    final ws = (await tester.runAsync(app.repo.load))!;
    return [for (final l in ws.labels) l.name];
  }

  DragSessionState? session(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(DragLayer).first))
          .read(dragSessionProvider);

  Future<void> prepare(
    WidgetTester tester,
    AppCommands app,
    List<String> labels, {
    String? favorite,
  }) async {
    for (final n in labels) {
      await tester.runAsync(
        () => app.labels.add(name: n, isFavorite: n == favorite),
      );
      await settle(tester);
    }
    GoRouter.of(tester.element(find.byType(Scaffold).first))
        .go('/filters-labels');
    await tester.pumpAndSettle();
  }

  Offset from(WidgetTester tester, String name) =>
      inside(tester, tile(name), dx: 120);

  Offset below(WidgetTester tester, String name) {
    final r = tester.getRect(tile(name));
    return Offset(r.left + 120, r.bottom - 5);
  }

  Offset above(WidgetTester tester, String name) {
    final r = tester.getRect(tile(name));
    return Offset(r.left + 120, r.top + 5);
  }

  testWidgets('порядок: за строку мышью, без ручки и без тоста', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await prepare(tester, app, ['Alpha', 'Beta', 'Gamma']);
      await hoverAt(tester, from(tester, 'Alpha'));
      expect(find.byType(DragGrip), findsNothing);

      await mouseDragAt(tester, from(tester, 'Alpha'), below(tester, 'Gamma'));
      await settle(tester);
      expect(await names(tester, app), ['Beta', 'Gamma', 'Alpha']);
      expect(find.text('Undo'), findsNothing);
      expect(session(tester), isNull);

      await mouseDragAt(tester, from(tester, 'Alpha'), above(tester, 'Beta'));
      await settle(tester);
      expect(await names(tester, app), ['Alpha', 'Beta', 'Gamma']);
    });
  });

  testWidgets('клик по строке открывает метку, как раньше', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await prepare(tester, app, ['Alpha', 'Beta']);
      await tester.tap(tile('Alpha'));
      await tester.pumpAndSettle();
      expect(find.byType(LabelDragTile), findsNothing);
      expect(find.text('Alpha'), findsWidgets);
      expect(
        GoRouter.of(tester.element(find.byType(Scaffold).first)).state.uri.path,
        startsWith('/label/'),
      );
    });
  });

  testWidgets('долгое нажатие перетаскивает метку касанием', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await prepare(tester, app, ['Alpha', 'Beta', 'Gamma']);
      await longPressDragAt(
        tester,
        from(tester, 'Alpha'),
        below(tester, 'Gamma'),
      );
      await settle(tester);
      expect(await names(tester, app), ['Beta', 'Gamma', 'Alpha']);
    });
  });

  testWidgets('отпускание вне слота и бросок на проект ничего не пишут', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await tester.runAsync(() => app.projects.add(name: 'Work'));
      await settle(tester);
      await prepare(tester, app, ['Alpha', 'Beta']);

      final outside = await startMouseDragAt(
        tester,
        from(tester, 'Alpha'),
        const Offset(900, 24),
      );
      expect(session(tester)?.indicator, isNull);
      await outside.up();
      await tester.pumpAndSettle();

      // Метка, брошенная на проект в сайдбаре, — не задача: места нет.
      final work = find.descendant(
        of: find.byType(Sidebar),
        matching: find.text('Work'),
      );
      final onProject = await startMouseDragAt(
        tester,
        from(tester, 'Alpha'),
        tester.getCenter(work.first),
      );
      expect(session(tester)?.indicator, isNull);
      await onProject.up();
      await tester.pumpAndSettle();
      expect(await names(tester, app), ['Alpha', 'Beta']);
    });
  });

  testWidgets('метка в «Избранном» сайдбара — не источник', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await prepare(tester, app, ['Alpha', 'Beta'], favorite: 'Beta');
      final fav = find
          .descendant(of: find.byType(Sidebar), matching: find.text('Beta'))
          .first;
      final mouse = await startMouseDragAt(
        tester,
        tester.getCenter(fav),
        tester.getCenter(fav) + const Offset(0, 200),
      );
      expect(session(tester), isNull);
      await mouse.up();
      await tester.pumpAndSettle();
      expect(await names(tester, app), ['Alpha', 'Beta']);
    });
  });

  testWidgets('клик со сдвигом мыши на 2–10 px открывает метку и ничего не '
      'пишет', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await prepare(tester, app, ['Alpha', 'Beta', 'Gamma']);
      for (final dx in [2.0, 6.0, 10.0]) {
        GoRouter.of(tester.element(find.byType(Scaffold).first))
            .go('/filters-labels');
        await tester.pumpAndSettle();
        final at = from(tester, 'Beta');
        final mouse = await hoverAt(tester, at);
        await mouse.down(at);
        await tester.pump();
        await mouse.moveTo(at + Offset(dx, 0));
        await tester.pump();
        await mouse.up();
        await tester.pumpAndSettle();
        expect(
          GoRouter.of(tester.element(find.byType(Scaffold).first))
              .state
              .uri
              .path,
          startsWith('/label/'),
          reason: 'сдвиг $dx px',
        );
      }
      expect(await names(tester, app), ['Alpha', 'Beta', 'Gamma']);
      expect(find.text('Undo'), findsNothing);
    });
  });
}
