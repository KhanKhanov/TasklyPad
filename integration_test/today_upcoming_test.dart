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
import 'package:planner/app/data_providers.dart';
import 'package:planner/app/sync_providers.dart';
import 'package:planner/data/repositories/view_options_repository.dart';
import 'package:planner/data/repositories/workspace_repository.dart';
import 'package:planner/domain/models.dart';
import 'package:planner/domain/view_options.dart';
import 'package:planner/features/quick_add/ui/quick_add_field.dart';
import 'package:planner/features/shell/ui/sidebar.dart';
import 'package:planner/features/tasks/logic/due_dates.dart';
import 'package:planner/features/tasks/ui/task_row.dart';
import 'package:planner/features/tasks/ui/task_row_parts.dart';
import 'package:planner/features/views/ui/today_screen.dart';
import 'package:planner/features/views/ui/upcoming_screen.dart';
import 'package:planner/sync/io_sync_fs.dart';
import 'package:planner/sync/sync_runner.dart';
import 'package:planner/sync/sync_services.dart';

// Сквозной сценарий M4.6 на настоящей платформе: быстрое добавление в
// «Сегодня» → задача со сроком сегодня; «Выполненные задачи» и выполнение;
// «Предстоящее»; второй профиль через папку на диске видит выполнение и
// настройку вида. Язык — язык системы. Кадры для отчёта — в SCREENSHOT_DIR:
//   flutter test integration_test/today_upcoming_test.dart -d windows
//     --dart-define=SCREENSHOT_DIR=C:/temp/shots
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Два профиля с разными файлами базы, а не одна база дважды.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  const shots = String.fromEnvironment('SCREENSHOT_DIR');

  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('planner_today_'));

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

  testWidgets('быстрое добавление в «Сегодня» — срок сегодня; выполнение и '
      '«Выполненные задачи» доходят до второго профиля через папку', (
    tester,
  ) async {
    final data = p.join(dir.path, 'data');
    final markers = p.join(dir.path, 'marker');
    final folder = Directory(p.join(dir.path, 'cloud'))..createSync();
    final services = await bootstrap(
      dataDirectory: data,
      markerDirectory: markers,
      profile: 'a',
    );
    final phone = await bootstrap(
      dataDirectory: data,
      markerDirectory: markers,
      profile: 'b',
    );
    addTearDown(phone.close);
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

    final now = services.clock.nowWall();
    String day(int offset) =>
        isoDate(DateTime(now.year, now.month, now.day + offset));
    final tasks = container.read(taskCommandsProvider);
    for (final (content, offset, priority) in [
      (ru ? 'Сдать отчёт' : 'Send the report', -2, 1),
      (ru ? 'Оплатить интернет' : 'Pay for internet', 0, 2),
      (ru ? 'Забрать посылку' : 'Pick up the parcel', 1, 4),
      (ru ? 'Записаться к врачу' : 'Book a doctor', 3, 3),
    ]) {
      await tasks.add(
        content: content,
        priority: priority,
        due: Due(date: day(offset)),
      );
    }

    final todayItem = find.descendant(
      of: find.byType(Sidebar),
      matching: find.text(ru ? 'Сегодня' : 'Today'),
    );
    await tester.tap(todayItem);
    final row = find.byType(TaskRow);
    await until('«Сегодня»', () => row.evaluate().length == 2);
    expect(find.byType(TodayScreen), findsOneWidget);
    expect(find.text(ru ? 'Перенести' : 'Reschedule'), findsOneWidget);

    final milk = ru ? 'Купить молоко' : 'Buy milk';
    await tester.sendKeyEvent(LogicalKeyboardKey.keyQ);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(QuickAddField),
        matching: find.byType(TextField),
      ),
      milk,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await until(
      'задача из быстрого добавления',
      () => row.evaluate().length == 3,
    );
    final added = (await WorkspaceRepository(
      services.db,
    ).load()).children(null).firstWhere((t) => t.content == milk);
    expect(added.due, Due(date: day(0)));
    await shot(tester, 'm46-1-today');

    // «Выполненные задачи» — и выполнить молоко.
    await tester.tap(find.text(ru ? 'Отображение' : 'Display'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxMenuButton));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.ancestor(of: find.text(milk), matching: row),
        matching: find.byType(TaskCheckCircle),
      ),
    );
    await until(
      'выполнено',
      () => tester
          .widgetList<TaskRow>(row)
          .any((r) => r.item.value.content == milk && r.item.value.isCompleted),
    );
    await shot(tester, 'm46-2-today-completed');

    await tester.tap(
      find.descendant(
        of: find.byType(Sidebar),
        matching: find.text(ru ? 'Предстоящее' : 'Upcoming'),
      ),
    );
    await until(
      '«Предстоящее»',
      () => find.byType(UpcomingScreen).evaluate().isNotEmpty,
    );
    await shot(tester, 'm46-3-upcoming');

    // Второй профиль через папку на диске.
    SyncRunner runner(SyncServices s, String name) => SyncRunner(
      services: s,
      openFs: IoSyncFs.new,
      deviceInfo: {'device': name, 'platform': 'windows'},
    );
    final pc = runner(services, 'A');
    final other = runner(phone, 'B');
    await pc.setFolder(folder.path);
    await other.setFolder(folder.path);
    await pc.syncNow();
    await other.syncNow();

    final seen = (await WorkspaceRepository(
      phone.db,
    ).load()).children(null).firstWhere((t) => t.content == milk);
    expect(seen.isCompleted, isTrue);
    expect(seen.due, Due(date: day(0)));
    expect(
      (await ViewOptionsRepository(phone.db).load(ViewType.today))
          .showCompletedTasks,
      isTrue,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await services.close();
  });
}
