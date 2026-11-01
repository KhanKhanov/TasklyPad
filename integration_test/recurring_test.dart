import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:planner/app/app.dart';
import 'package:planner/app/bootstrap.dart';
import 'package:planner/app/sync_providers.dart';
import 'package:planner/data/repositories/workspace_repository.dart';
import 'package:planner/features/quick_add/ui/quick_add_field.dart';
import 'package:planner/features/tasks/ui/task_dialog_top_bar.dart';
import 'package:planner/features/tasks/ui/task_row.dart';
import 'package:planner/features/tasks/ui/task_row_parts.dart';
import 'package:planner/sync/io_sync_fs.dart';
import 'package:planner/sync/sync_runner.dart';
import 'package:planner/sync/sync_services.dart';

// Сквозной сценарий M3.7 на настоящей платформе: повторяющаяся задача из окна
// `q`, выполнение кружком, второй профиль через папку на диске. Язык
// интерфейса и разбора — язык системы. Кадры для отчёта — в SCREENSHOT_DIR:
//   flutter test integration_test/recurring_test.dart -d windows
//     --dart-define=SCREENSHOT_DIR=C:/temp/shots
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Две базы в одном процессе — два профиля с разными файлами.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  const shots = String.fromEnvironment('SCREENSHOT_DIR');

  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('planner_rec_'));

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

  testWidgets('«Зарядка каждый день в 7:00» → выполнить → второй профиль '
      'через папку: новый срок, одна запись о выполнении, конфликтов нет', (
    tester,
  ) async {
    final data = p.join(dir.path, 'data');
    final markers = p.join(dir.path, 'marker');
    final folder = Directory(p.join(dir.path, 'cloud'))..createSync();
    final a = await bootstrap(
      dataDirectory: data,
      markerDirectory: markers,
      profile: 'a',
    );
    final b = await bootstrap(
      dataDirectory: data,
      markerDirectory: markers,
      profile: 'b',
    );
    SyncRunner runner(SyncServices services, String name) => SyncRunner(
      services: services,
      openFs: IoSyncFs.new,
      deviceInfo: {'device': name, 'platform': 'windows'},
    );
    final container = ProviderContainer(
      overrides: [syncServicesProvider.overrideWithValue(a)],
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
    final title = ru ? 'Зарядка' : 'Workout';

    await tester.sendKeyEvent(LogicalKeyboardKey.keyQ);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(QuickAddField),
        matching: find.byType(TextField),
      ),
      ru ? '$title каждый день в 7:00' : '$title every day at 7am',
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    final row = find.ancestor(
      of: find.text(title),
      matching: find.byType(TaskRow),
    );
    expect(
      find.descendant(of: row, matching: find.byIcon(Icons.repeat)),
      findsOneWidget,
    );
    await shot(tester, 'm37-1-row');

    // Планировщик: `t` на строке, «Повторить», «Пользовательский…».
    tester
        .widget<Focus>(
          find.descendant(of: row, matching: find.byType(Focus)).first,
        )
        .focusNode!
        .requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
    await shot(tester, 'm37-2-scheduler');
    await tester.tap(find.byIcon(Icons.repeat).last);
    await shot(tester, 'm37-3-repeat');
    await tester.tap(find.text(ru ? 'Пользовательский…' : 'Custom…'));
    await shot(tester, 'm37-4-custom');
    for (var i = 0; i < 2; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
    }

    // Меню окна задачи с пунктами повторяющейся задачи.
    await tester.tap(find.text(title));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(TaskDialogTopBar),
        matching: find.byIcon(Icons.more_horiz),
      ),
    );
    await shot(tester, 'm37-5-menu');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    final repoA = WorkspaceRepository(a.db);
    final before = (await repoA.load()).children(null).single;
    await tester.tap(
      find.descendant(of: row, matching: find.byType(TaskCheckCircle)),
    );
    await tester.pumpAndSettle();
    final after = (await repoA.load()).task(before.id)!;
    expect(after.isCompleted, isFalse);
    expect(after.due!.date.compareTo(before.due!.date), greaterThan(0));
    expect(after.due!.time, '07:00');

    final syncA = runner(a, 'A');
    final syncB = runner(b, 'B');
    await syncA.setFolder(folder.path);
    await syncB.setFolder(folder.path);
    await syncA.syncNow();
    await syncB.syncNow();

    final onB = (await WorkspaceRepository(b.db).load()).task(before.id)!;
    expect(onB.due, after.due);
    expect(await b.db.select(b.db.completions).get(), hasLength(1));
    expect(await a.store.conflicts(), isEmpty);
    expect(await b.store.conflicts(), isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await a.close();
    await b.close();
  });
}
