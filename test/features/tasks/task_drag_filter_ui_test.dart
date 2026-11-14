import 'package:flutter_test/flutter_test.dart';
import 'package:planner/domain/view_options.dart';

import '../../app/support/pump_app.dart';
import '../support/app_commands.dart';
import '../support/drag_gestures.dart';

// Перетаскивание во «Входящих» с фильтром «Отображения» «Приоритет 1»
// (решения 3А, 4А plans/m5): видны подходящие задачи и их предки, задача
// встаёт после видимой соседки, скрытые остаются на местах. Локаль — en.
void main() {
  Future<String> add(
    WidgetTester tester,
    AppCommands app,
    String name, {
    int priority = 4,
    String? parentId,
  }) async {
    final id = (await tester.runAsync(
      () =>
          app.tasks.add(content: name, priority: priority, parentId: parentId),
    ))!;
    await settle(tester);
    return id;
  }

  Future<void> filterP1(WidgetTester tester, AppCommands app) async {
    final inbox = (await tester.runAsync(app.read))!.inbox!.id;
    final view = ViewOptions(viewType: ViewType.project, objectId: inbox);
    await tester.runAsync(
      () => app.views.save(view, view.copyWith(filteredBy: 'p1')),
    );
    await settle(tester);
  }

  Future<List<String>> inboxOrder(WidgetTester tester, AppCommands app) async {
    final ws = (await tester.runAsync(app.read))!;
    return [
      for (final t in ws.children(null, projectId: ws.inbox!.id)) t.content,
    ];
  }

  testWidgets('бросок под видимую соседку — после неё; скрытая задача остаётся '
      'на месте', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await add(tester, app, 'Alpha', priority: 1);
      await add(tester, app, 'Hidden');
      await add(tester, app, 'Gamma', priority: 1);
      await filterP1(tester, app);
      expect(find.text('Hidden'), findsNothing);

      await mouseDrag(tester, 'Alpha', belowHalf(tester, 'Gamma'));
      await settle(tester);
      expect(await inboxOrder(tester, app), ['Hidden', 'Gamma', 'Alpha']);
    });
  });

  testWidgets('бросок на своё место при скрытой соседке выше — ничего не '
      'пишется, тоста нет', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await add(tester, app, 'Alpha', priority: 1);
      await add(tester, app, 'Hidden');
      await add(tester, app, 'Gamma', priority: 1);
      await filterP1(tester, app);
      final before = (await tester.runAsync(device.ownOps))!.length;

      await mouseDrag(tester, 'Gamma', belowHalf(tester, 'Alpha'));
      await settle(tester);
      expect(await inboxOrder(tester, app), ['Alpha', 'Hidden', 'Gamma']);
      expect((await tester.runAsync(device.ownOps))!.length, before);
      expect(find.text('Task moved'), findsNothing);
    });
  });

  testWidgets('подходящая подзадача неподходящей задачи — под ней; бросок '
      'подзадачи на своё место не отрывает её от родителя', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final parent = await add(tester, app, 'Parent');
      await add(tester, app, 'Hidden child', parentId: parent);
      final child = await add(
        tester,
        app,
        'Child',
        priority: 1,
        parentId: parent,
      );
      await add(tester, app, 'Other', priority: 1);
      await filterP1(tester, app);
      expect(find.text('Parent'), findsOneWidget);
      expect(find.text('Hidden child'), findsNothing);
      expect(
        tester.getTopLeft(find.text('Child')).dx,
        greaterThan(tester.getTopLeft(find.text('Parent')).dx),
      );

      await mouseDrag(
        tester,
        'Child',
        belowHalf(
          tester,
          'Parent',
          // Ручка подзадачи — на уровень правее; уровень тот же.
          x: gripX(tester, 'Child') + 28,
        ),
      );
      await settle(tester);
      final ws = (await tester.runAsync(app.read))!;
      expect(ws.task(child)!.parentId, parent);
      expect(await inboxOrder(tester, app), ['Parent', 'Other']);
    });
  });
}
