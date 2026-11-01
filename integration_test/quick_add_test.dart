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
import 'package:planner/features/quick_add/state/quick_add_controller.dart';
import 'package:planner/features/quick_add/ui/quick_add_field.dart';
import 'package:planner/features/tasks/ui/add_task_editor.dart';

// Быстрое добавление на настоящей платформе: файл базы, шрифты и ввод
// Windows. Язык интерфейса и разбора — язык системы (ru или en), поэтому
// фразы берутся на нём. Кадры для отчёта — в папку SCREENSHOT_DIR:
//   flutter test integration_test/quick_add_test.dart -d windows
//     --dart-define=SCREENSHOT_DIR=C:/temp/shots
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const shots = String.fromEnvironment('SCREENSHOT_DIR');

  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('planner_qa_'));

  tearDown(() {
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows может держать файл базы ещё мгновение — временная папка.
    }
  });

  /// Кадр всего окна (с диалогами) в [shots]; без папки — ничего.
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

  testWidgets('окно `q`: подсветка, автодополнение с созданием, добавление; '
      'вставка строк; «Основное»', (tester) async {
    final services = await bootstrap(
      dataDirectory: dir.path,
      markerDirectory: p.join(dir.path, 'marker'),
    );
    final container = ProviderContainer(
      overrides: [syncServicesProvider.overrideWithValue(services)],
    );
    final work = await container
        .read(projectCommandsProvider)
        .add(name: 'Работа', color: 'blue');
    await container.read(sectionCommandsProvider).add(work, name: 'Звонки');
    await container.read(labelCommandsProvider).add(name: 'дом');
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
    final field = find.descendant(
      of: find.byType(QuickAddField),
      matching: find.byType(TextField),
    );
    QuickAddController controller() =>
        tester.widget<TextField>(field).controller! as QuickAddController;

    await tester.sendKeyEvent(LogicalKeyboardKey.keyQ);
    await tester.pumpAndSettle();
    await tester.enterText(
      field,
      ru
          ? 'Позвонить маме завтра в 18:00 p1 #Работа /Звонки '
          : 'Call mom tomorrow at 6pm p1 #Работа /Звонки ',
    );
    await shot(tester, 'm36-1-highlight');
    expect(controller().highlights, hasLength(4));

    await tester.enterText(field, ru ? 'Купить молоко %до' : 'Buy milk %до');
    await shot(tester, 'm36-2-autocomplete');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter); // «Создать метку»
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter); // добавить
    await shot(tester, 'm36-3-added');

    final ws = await WorkspaceRepository(services.db).load();
    final task = ws.children(null).single;
    expect(task.labelIds.map((id) => ws.label(id)!.name), ['до']);

    await tester.tap(
      find.descendant(
        of: find.byType(AddTaskButton),
        matching: find.byType(TextButton),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      field,
      ru ? 'Хлеб\nСыр завтра' : 'Bread\nCheese tomorrow',
    );
    await tester.pumpAndSettle();
    await shot(tester, 'm36-4-paste');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.keyO);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await shot(tester, 'm36-5-general');

    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await services.close();
  });
}
