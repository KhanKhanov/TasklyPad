import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:planner/app/app.dart';
import 'package:planner/app/bootstrap.dart';
import 'package:planner/app/data_providers.dart';
import 'package:planner/app/sync_providers.dart';
import 'package:planner/data/repositories/workspace_repository.dart';
import 'package:planner/domain/models.dart';
import 'package:planner/domain/workspace.dart';
import 'package:planner/features/common/ui/drag_source.dart';
import 'package:planner/features/projects/ui/project_drag.dart';
import 'package:planner/features/sections/ui/section_drag.dart';
import 'package:planner/features/shell/ui/sidebar.dart';
import 'package:planner/features/tasks/logic/due_dates.dart';
import 'package:planner/features/tasks/state/today.dart';
import 'package:planner/features/views/ui/view_parts.dart';

import '../test/features/support/drag_gestures.dart';

// Сквозной сценарий M4.9 на настоящей платформе: перетаскивание мышью за
// ручку в проекте (порядок, подзадача, раздел, сайдбар, `Ctrl+Z`), в «Сегодня»
// (зона «на завтра») и «Предстоящем» (день). Язык — язык системы. Кадры для
// отчёта — в SCREENSHOT_DIR:
//   flutter test integration_test/drag_test.dart -d windows
//     --dart-define=SCREENSHOT_DIR=C:/temp/shots
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const shots = String.fromEnvironment('SCREENSHOT_DIR');

  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('planner_drag_'));

  tearDown(() {
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows может держать файл базы ещё мгновение — временная папка.
    }
  });

  /// Кадр всего окна в [shots]; без папки — ничего.
  Future<void> shot(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    if (shots.isEmpty) return;
    final view = tester.binding.renderViews.first;
    // ignore: invalid_use_of_protected_member — корневой слой окна целиком.
    final layer = view.layer! as OffsetLayer;
    final ratio = view.flutterView.devicePixelRatio;
    final image = await layer.toImage(Offset.zero & (view.size * ratio));
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    Directory(shots).createSync(recursive: true);
    File(p.join(shots, '$name.png'))
        .writeAsBytesSync(bytes!.buffer.asUint8List());
  }

  testWidgets('перетаскивание мышью: проект, «Сегодня», «Предстоящее»', (
    tester,
  ) async {
    final services = await bootstrap(
      dataDirectory: p.join(dir.path, 'data'),
      markerDirectory: p.join(dir.path, 'marker'),
      profile: 'a',
    );
    final container = ProviderContainer(
      overrides: [syncServicesProvider.overrideWithValue(services)],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const PlannerApp(),
      ),
    );
    await tester.pumpAndSettle();
    final ru =
        Localizations.localeOf(tester.element(find.byType(Scaffold).first))
            .languageCode ==
        'ru';
    final repo = WorkspaceRepository(services.db);

    // База работает в фоновом изоляте, и `pumpAndSettle` её не ждёт.
    Future<void> until(String what, bool Function() ready) async {
      for (var i = 0; i < 100 && !ready(); i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(ready(), isTrue, reason: 'не дождались: $what');
    }

    /// Дождаться записи в базе.
    Future<void> saved(String what, bool Function(Workspace ws) ready) async {
      var ok = false;
      for (var i = 0; i < 100 && !ok; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
        ok = ready((await tester.runAsync(repo.load))!);
      }
      expect(ok, isTrue, reason: 'не записано: $what');
      await tester.pumpAndSettle();
    }

    final name = ru ? 'Ремонт' : 'Renovation';
    final sectionName = ru ? 'Кухня' : 'Kitchen';
    final projects = container.read(projectCommandsProvider);
    final tasks = container.read(taskCommandsProvider);
    final project = await projects.add(name: name);
    final section = await container
        .read(sectionCommandsProvider)
        .add(project, name: sectionName);
    final names = ru
        ? ['Купить краску', 'Выбрать плитку', 'Вынести мусор', 'Позвонить']
        : ['Buy paint', 'Pick tiles', 'Take out trash', 'Call'];
    final ids = [
      for (final n in names) await tasks.add(content: n, projectId: project),
    ];
    final inSidebar = find.descendant(
      of: find.byType(Sidebar),
      matching: find.text(name),
    );
    await until('проект в сайдбаре', () => inSidebar.evaluate().isNotEmpty);
    await tester.tap(inSidebar);
    await until(
      'задачи проекта',
      () => find.text(names.last).evaluate().isNotEmpty,
    );

    List<String> order(Workspace ws, {String? sectionId}) => [
      for (final t in ws.children(
        null,
        projectId: project,
        sectionId: sectionId,
      ))
        t.id,
    ];

    // Порядок: первая задача — под последнюю.
    await mouseDrag(tester, names[0], belowHalf(tester, names[3]));
    await saved(
      'порядок',
      (ws) => order(ws).join() == [ids[1], ids[2], ids[3], ids[0]].join(),
    );
    await shot(tester, 'm49-1-order');

    // Подзадача: «Позвонить» — сдвиг вправо под «Вынести мусор».
    await mouseDrag(tester, names[3], belowHalf(tester, names[2], dx: 40));
    await saved('подзадача', (ws) => ws.task(ids[3])?.parentId == ids[2]);
    await shot(tester, 'm49-2-subtask');

    // Раздел: «Выбрать плитку» — на заголовок раздела.
    await mouseDrag(tester, names[1], tester.getCenter(find.text(sectionName)));
    await saved('раздел', (ws) => ws.task(ids[1])?.sectionId == section);
    await shot(tester, 'm49-3-section');

    // Сайдбар: «Вынести мусор» — во «Входящие».
    final inbox = find.descendant(
      of: find.byType(Sidebar),
      matching: find.text(ru ? 'Входящие' : 'Inbox'),
    );
    final mouse = await startMouseDrag(
      tester,
      names[2],
      tester.getCenter(inbox.first),
    );
    await shot(tester, 'm49-4-sidebar-drag');
    await mouse.up();
    final inboxId = (await tester.runAsync(repo.load))!.inbox!.id;
    await saved('сайдбар', (ws) => ws.task(ids[2])?.projectId == inboxId);

    // `Ctrl+Z` возвращает перенос.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await saved('Ctrl+Z', (ws) => ws.task(ids[2])?.projectId == project);

    // «Сегодня»: задача на сегодня — в зону «на завтра».
    final today = container.read(todayProvider);
    final todayIso = isoDate(today);
    final tomorrowIso = isoDate(
      DateTime(today.year, today.month, today.day + 1),
    );
    final dayAfterIso = isoDate(
      DateTime(today.year, today.month, today.day + 2),
    );
    final mine = await tasks.add(
      content: ru ? 'Сегодняшняя' : 'For today',
      due: Due(date: todayIso),
    );
    await tester.tap(
      find.descendant(
        of: find.byType(Sidebar),
        matching: find.text(ru ? 'Сегодня' : 'Today'),
      ),
    );
    final mineName = ru ? 'Сегодняшняя' : 'For today';
    await until(
      'задача в «Сегодня»',
      () => find.text(mineName).evaluate().isNotEmpty,
    );
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    final zone = Offset(size.width - 120, size.height - 60);
    final dragging = await startMouseDrag(tester, mineName, zone);
    await shot(tester, 'm49-5-tomorrow-zone');
    await dragging.up();
    await saved('на завтра', (ws) => ws.task(mine)?.due?.date == tomorrowIso);

    // «Предстоящее»: на заголовок второго дня после сегодняшнего.
    await tester.tap(
      find.descendant(
        of: find.byType(Sidebar),
        matching: find.text(ru ? 'Предстоящее' : 'Upcoming'),
      ),
    );
    await until('день', () => find.byType(DayHeader).evaluate().length > 2);
    await mouseDrag(
      tester,
      mineName,
      tester.getCenter(find.byType(DayHeader).at(2)),
    );
    await saved('на день', (ws) => ws.task(mine)?.due?.date == dayAfterIso);
    await shot(tester, 'm49-6-upcoming');

    // M4.10: порядок проектов — вторая над первой в сайдбаре.
    final secondName = ru ? 'Вторая' : 'Second';
    final second = await projects.add(name: secondName);
    Finder projectTile(String n) => find.ancestor(
      of: find.descendant(of: find.byType(Sidebar), matching: find.text(n)),
      matching: find.byType(ProjectDragTile),
    );
    await until(
      'вторая в сайдбаре',
      () => projectTile(secondName).evaluate().isNotEmpty,
    );
    final first = tester.getRect(projectTile(name).first);
    await mouseDragAt(
      tester,
      inside(tester, projectTile(secondName).first, dx: 80),
      Offset(first.left + 80, first.top + 5),
    );
    await saved(
      'порядок проектов',
      (ws) =>
          ws.childProjects(null).where((p) => !p.isInbox).first.id == second,
    );
    await shot(tester, 'm410-1-project-order');

    // Порядок разделов: «Ванная» — ручкой над «Кухней», задачи остаются.
    final bathroom = await container
        .read(sectionCommandsProvider)
        .add(project, name: ru ? 'Ванная' : 'Bathroom');
    await tester.tap(projectTile(name).first);
    await until(
      'разделы проекта',
      () => find.byType(SectionHeaderDrag).evaluate().length == 2,
    );
    Finder sectionHeader(String n) => find.ancestor(
      of: find.text(n),
      matching: find.byType(SectionHeaderDrag),
    );
    final bathroomName = ru ? 'Ванная' : 'Bathroom';
    await hoverAt(tester, tester.getCenter(sectionHeader(bathroomName)));
    final grip = find.descendant(
      of: sectionHeader(bathroomName),
      matching: find.byType(DragGrip),
    );
    final target = tester.getRect(sectionHeader(sectionName));
    final dragging2 = await startMouseDragAt(
      tester,
      tester.getCenter(grip),
      Offset(target.left + 120, target.top + 6),
    );
    await shot(tester, 'm410-2-section-drag');
    await dragging2.up();
    await saved(
      'порядок разделов',
      (ws) => ws.sectionsOf(project).first.id == bathroom,
    );
    await shot(tester, 'm410-3-section-order');

    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await services.close();
  });
}
