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
import 'package:planner/domain/workspace.dart';
import 'package:planner/features/shell/ui/sidebar.dart';
import 'package:planner/features/tasks/ui/selection_toolbar.dart';
import 'package:planner/features/tasks/ui/task_row.dart';

// Сквозной сценарий M4.8 на настоящей платформе: `Ctrl+клик` и
// `Ctrl+Shift+клик` выделяют задачи, панель выделения — «Срок» → «Завтра» у
// всех, «Отменить» (решение 9 плана M4). Язык — язык системы. Кадры для
// отчёта — в SCREENSHOT_DIR:
//   flutter test integration_test/selection_test.dart -d windows
//     --dart-define=SCREENSHOT_DIR=C:/temp/shots
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const shots = String.fromEnvironment('SCREENSHOT_DIR');

  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('planner_select_'));

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

  testWidgets('`Ctrl+клик`, `Ctrl+Shift+клик` — три задачи; «Срок» → '
      '«Завтра» у всех; «Отменить» возвращает', (tester) async {
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
    final names = ru
        ? [
            'Купить краску',
            'Позвонить электрику',
            'Выбрать плитку',
            'Вынести мусор',
          ]
        : ['Buy paint', 'Call the electrician', 'Pick tiles', 'Take out trash'];
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
      () => find.byType(TaskRow).evaluate().length == 4,
    );

    Future<void> click(String text, List<LogicalKeyboardKey> held) async {
      for (final key in held) {
        await tester.sendKeyDownEvent(key);
      }
      await tester.tap(find.text(text), kind: PointerDeviceKind.mouse);
      for (final key in held.reversed) {
        await tester.sendKeyUpEvent(key);
      }
      await tester.pumpAndSettle();
    }

    await click(names[0], [LogicalKeyboardKey.controlLeft]);
    await click(names[2], [
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.shiftLeft,
    ]);
    final toolbar = find.byType(SelectionToolbar);
    expect(
      find.descendant(
        of: toolbar,
        matching: find.text(ru ? 'Выбрано: 3' : '3 selected'),
      ),
      findsOneWidget,
    );
    await shot(tester, 'm48-1-selection');

    await tester.tap(
      find.descendant(of: toolbar, matching: find.text(ru ? 'Срок' : 'Date')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(ru ? 'Завтра' : 'Tomorrow').last);
    final repo = WorkspaceRepository(services.db);

    /// Дождаться записи в базе: она в фоновом изоляте.
    Future<void> saved(String what, bool Function(Workspace ws) ready) async {
      var ok = false;
      for (var i = 0; i < 100 && !ok; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        ok = ready(await repo.load());
      }
      expect(ok, isTrue, reason: 'не записано: $what');
    }

    await saved(
      'срок у трёх',
      (ws) =>
          ids.take(3).every((id) => ws.task(id)?.due != null) &&
          ws.task(ids[3])?.due == null,
    );
    await shot(tester, 'm48-2-tomorrow');

    await tester.tap(find.text(ru ? 'Отменить' : 'Undo'));
    await saved('отмена', (ws) => ids.every((id) => ws.task(id)?.due == null));

    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await services.close();
  });
}
