import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:planner/app/app.dart';
import 'package:planner/app/bootstrap.dart';
import 'package:planner/app/data_providers.dart';
import 'package:planner/app/sync_providers.dart';
import 'package:planner/data/repositories/view_options_repository.dart';
import 'package:planner/domain/models.dart';
import 'package:planner/domain/view_options.dart';
import 'package:planner/features/shell/ui/sidebar.dart';
import 'package:planner/features/tasks/ui/task_row.dart';

// Сквозной сценарий M4.5 на настоящей платформе: «Отображение» проекта —
// группировка по приоритету с меню и подменю, затем перезапуск: настройка
// осталась (О-22 — раньше «Выполненные задачи» сбрасывались). Язык — язык
// системы. Кадры для отчёта — в SCREENSHOT_DIR:
//   flutter test integration_test/view_options_test.dart -d windows
//     --dart-define=SCREENSHOT_DIR=C:/temp/shots
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const shots = String.fromEnvironment('SCREENSHOT_DIR');

  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('planner_view_'));

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

  testWidgets('группировка по приоритету в «Отображении» проекта — группы и '
      '«Отображение: 1»; после перезапуска настройка та же', (tester) async {
    final data = p.join(dir.path, 'data');
    final markers = p.join(dir.path, 'marker');
    final services = await bootstrap(
      dataDirectory: data,
      markerDirectory: markers,
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
    final label = await container
        .read(labelCommandsProvider)
        .add(name: ru ? 'дом' : 'home');
    for (final (content, priority, date) in [
      (ru ? 'Купить краску' : 'Buy paint', 1, '2026-11-05'),
      (ru ? 'Позвонить электрику' : 'Call the electrician', 2, null),
      (ru ? 'Выбрать плитку' : 'Pick tiles', 1, null),
      (ru ? 'Вынести мусор' : 'Take out trash', 4, '2026-11-04'),
    ]) {
      await tasks.add(
        content: content,
        projectId: project,
        priority: priority,
        due: date == null ? null : Due(date: date),
        labelIds: priority == 1 ? {label} : const {},
      );
    }
    final inSidebar = find.descendant(
      of: find.byType(Sidebar),
      matching: find.text(name),
    );
    await until('проект в сайдбаре', () => inSidebar.evaluate().isNotEmpty);
    await tester.tap(inSidebar);
    final row = find.byType(TaskRow);
    await until('задачи проекта', () => row.evaluate().length == 4);
    await shot(tester, 'm45-1-project');

    final display = ru ? 'Отображение' : 'Display';
    await tester.tap(find.text(display));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ru ? 'Группировка' : 'Grouping'));
    await shot(tester, 'm45-2-menu');
    await tester.tap(find.text(ru ? 'Приоритет' : 'Priority').last);
    final header = find.text(ru ? 'Приоритет 1' : 'Priority 1');
    await until('группы', () => header.evaluate().isNotEmpty);
    expect(find.text('$display: 1'), findsOneWidget);
    await shot(tester, 'm45-3-grouped');

    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await services.close();

    // Перезапуск с тем же профилем: группировка — из базы.
    final again = await bootstrap(
      dataDirectory: data,
      markerDirectory: markers,
      profile: 'a',
    );
    expect(
      (await ViewOptionsRepository(
        again.db,
      ).load(ViewType.project, objectId: project)).grouping,
      Grouping.priority,
    );
    await again.close();
  });
}
