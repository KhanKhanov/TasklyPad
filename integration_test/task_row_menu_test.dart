import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
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
import 'package:planner/features/shell/ui/sidebar.dart';
import 'package:planner/features/tasks/ui/task_row.dart';

// Сквозной сценарий M4.7 на настоящей платформе: меню строки задачи правым
// кликом — срок «Завтра», затем `.` — приоритет 1 (О-48). Язык — язык
// системы. Кадры для отчёта — в SCREENSHOT_DIR:
//   flutter test integration_test/task_row_menu_test.dart -d windows
//     --dart-define=SCREENSHOT_DIR=C:/temp/shots
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const shots = String.fromEnvironment('SCREENSHOT_DIR');

  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('planner_menu_'));

  tearDown(() {
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows может держать файл базы ещё мгновение — временная папка.
    }
  });

  /// Кадр всего окна (с меню) в [shots]; без папки — ничего.
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

  testWidgets('правый клик — «Завтра» ставит срок; `.` — «Приоритет 1»', (
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

    final name = ru ? 'Ремонт' : 'Renovation';
    final project = await container
        .read(projectCommandsProvider)
        .add(name: name);
    final tasks = container.read(taskCommandsProvider);
    final paint = ru ? 'Купить краску' : 'Buy paint';
    final id = await tasks.add(content: paint, projectId: project);
    await tasks.add(
      content: ru ? 'Позвонить электрику' : 'Call the electrician',
      projectId: project,
    );
    final inSidebar = find.descendant(
      of: find.byType(Sidebar),
      matching: find.text(name),
    );
    await until('проект в сайдбаре', () => inSidebar.evaluate().isNotEmpty);
    await tester.tap(inSidebar);
    await until(
      'задачи проекта',
      () => find.byType(TaskRow).evaluate().length == 2,
    );

    await tester.tap(
      find.text(paint),
      buttons: kSecondaryMouseButton,
      kind: PointerDeviceKind.mouse,
    );
    await shot(tester, 'm47-1-menu');
    await tester.tap(find.byTooltip(ru ? 'Завтра' : 'Tomorrow'));
    final repo = WorkspaceRepository(services.db);

    /// Дождаться записи в базе: она в фоновом изоляте.
    Future<void> saved(String what, bool Function(Task? task) ready) async {
      var ok = false;
      for (var i = 0; i < 100 && !ok; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        ok = ready((await repo.load()).task(id));
      }
      expect(ok, isTrue, reason: 'не записано: $what');
    }

    await saved('срок «Завтра»', (t) => t?.due != null);
    await shot(tester, 'm47-2-tomorrow');

    await tester.tap(find.text(paint));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.period);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(ru ? 'Приоритет 1' : 'Priority 1'));
    await saved('приоритет 1', (t) => t?.priority == 1);
    await shot(tester, 'm47-3-priority');

    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await services.close();
  });
}
