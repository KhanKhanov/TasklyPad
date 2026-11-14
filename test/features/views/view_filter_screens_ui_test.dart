import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:planner/domain/models.dart';
import 'package:planner/domain/view_options.dart';
import 'package:planner/features/shell/ui/sidebar.dart';

import '../../app/support/pump_app.dart';
import '../support/app_commands.dart';
import '../support/drag_gestures.dart';

// Фильтр «Отображения» вне «Входящих» (решения 3А, 4А plans/m5): «Сегодня» —
// и «Перенести» берёт только видимые просроченные, экран метки, экран
// фильтра; бросок на своё место в дне при скрытой соседке. Часы теста —
// пятница 23.10.2026. Локаль — en.
void main() {
  void go(WidgetTester tester, String location) =>
      GoRouter.of(tester.element(find.byType(Scaffold).first)).go(location);

  Future<String> add(
    WidgetTester tester,
    AppCommands app,
    String content, {
    int priority = 4,
    String? date,
    Set<String> labelIds = const {},
  }) async {
    final id = (await tester.runAsync(
      () => app.tasks.add(
        content: content,
        priority: priority,
        due: date == null ? null : Due(date: date),
        labelIds: labelIds,
      ),
    ))!;
    await settle(tester);
    return id;
  }

  Future<void> setView(
    WidgetTester tester,
    AppCommands app,
    ViewType type,
    ViewOptions Function(ViewOptions) change, {
    String? objectId,
  }) async {
    await tester.runAsync(() async {
      final v = await app.viewsRepo.load(type, objectId: objectId);
      await app.views.save(v, change(v));
    });
    await settle(tester);
  }

  Future<void> openToday(WidgetTester tester) async {
    await tester.tap(
      find.descendant(of: find.byType(Sidebar), matching: find.text('Today')),
    );
    await settle(tester);
  }

  Future<Due?> dueOf(WidgetTester tester, AppCommands app, String id) async =>
      (await tester.runAsync(app.read))!.task(id)!.due;

  testWidgets('«Today» с «Priority 1»: скрытая просроченная не видна, '
      '«Reschedule» переносит только видимые', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final shown = await add(
        tester,
        app,
        'Shown',
        priority: 1,
        date: '2026-10-20',
      );
      final hidden = await add(tester, app, 'Hidden', date: '2026-10-21');
      await setView(
        tester,
        app,
        ViewType.today,
        (v) => v.copyWith(filteredBy: 'p1'),
      );
      await openToday(tester);
      expect(find.text('Shown'), findsOneWidget);
      expect(find.text('Hidden'), findsNothing);

      await tester.tap(find.text('Reschedule'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tomorrow').last);
      await settle(tester);
      expect(await dueOf(tester, app, shown), const Due(date: '2026-10-24'));
      expect(await dueOf(tester, app, hidden), const Due(date: '2026-10-21'));
    });
  });

  testWidgets('экран метки с «Priority 1» — только подходящие задачи', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final home = (await tester.runAsync(() => app.labels.add(name: 'home')))!;
      await settle(tester);
      await add(tester, app, 'Urgent', priority: 1, labelIds: {home});
      await add(tester, app, 'Calm', labelIds: {home});
      await setView(
        tester,
        app,
        ViewType.label,
        (v) => v.copyWith(filteredBy: 'p1'),
        objectId: home,
      );
      go(tester, '/label/$home');
      await settle(tester);
      expect(find.text('Urgent'), findsOneWidget);
      expect(find.text('Calm'), findsNothing);
    });
  });

  testWidgets('экран фильтра с «Priority 1» в «Display» — только подходящие '
      'задачи его списка', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await add(tester, app, 'Urgent', priority: 1, date: '2026-10-23');
      await add(tester, app, 'Calm', date: '2026-10-23');
      final filter = (await tester.runAsync(
        () => app.filters.add(name: 'Day', query: 'today'),
      ))!;
      await settle(tester);
      await setView(
        tester,
        app,
        ViewType.filter,
        (v) => v.copyWith(filteredBy: 'p1'),
        objectId: filter,
      );
      go(tester, '/filter/$filter');
      await settle(tester);
      expect(find.text('Urgent'), findsOneWidget);
      expect(find.text('Calm'), findsNothing);
    });
  });

  testWidgets('«Today» «Manual» с меткой в «Display»: бросок на своё место '
      'при скрытой соседке выше — ничего не пишется', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final home = (await tester.runAsync(() => app.labels.add(name: 'home')))!;
      await settle(tester);
      // Один приоритет: скрытая задача — между видимыми в порядке дня.
      await add(tester, app, 'Alpha', date: '2026-10-23', labelIds: {home});
      await add(tester, app, 'Hidden', date: '2026-10-23');
      await add(tester, app, 'Gamma', date: '2026-10-23', labelIds: {home});
      await setView(
        tester,
        app,
        ViewType.today,
        (v) => v.copyWith(sorting: Sorting.manual, filteredBy: '%home'),
      );
      await openToday(tester);
      expect(find.text('Hidden'), findsNothing);
      final before = (await tester.runAsync(device.ownOps))!.length;

      await mouseDrag(tester, 'Gamma', belowHalf(tester, 'Alpha'));
      await settle(tester);
      expect((await tester.runAsync(device.ownOps))!.length, before);
      expect(find.text('Task moved'), findsNothing);
    });
  });
}
