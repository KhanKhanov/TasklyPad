import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/app/app.dart';
import 'package:planner/app/data_providers.dart';
import 'package:planner/app/sync_providers.dart';
import 'package:planner/data/repositories/theme_settings_repository.dart';
import 'package:planner/features/projects/ui/project_screen.dart';
import 'package:planner/features/projects/ui/projects_screen.dart';
import 'package:planner/platform/conflict_notifier.dart';

import '../../sync/support/devices.dart';
import 'fake_conflict_notifier.dart';

/// Запустить приложение на устройстве с базой в памяти — тем же ядром
/// данных (`startSync`), что и настоящий запуск — выполнить [body] и
/// закрыть всё внутри теста. [overrides] — фейки поверх (выбор папки,
/// синхронизация); уведомления ОС — всегда фейк ([notifier]).
///
/// Закрытие — здесь, а не в `addTearDown`: поток запроса drift при отписке
/// ставит таймер, и он должен сработать до проверки «таймеров не осталось»,
/// которую фреймворк делает сразу после тела теста. [before] — подготовка
/// базы до запуска приложения (сохранённые настройки); [firstFrame] —
/// проверка первого кадра, пока потоки базы ещё не ответили.
Future<void> withApp(
  WidgetTester tester,
  Future<void> Function(TestDevice device) body, {
  Size size = const Size(1100, 800),
  List<Override> overrides = const [],
  ConflictNotifier? notifier,
  Future<void> Function(TestDevice device)? before,
  void Function()? firstFrame,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final device = (await tester.runAsync(TestDevice.start))!;
  await tester.runAsync(() async => before?.call(device));
  // Как в main: тема — до первого кадра.
  final theme = (await tester.runAsync(
    ThemeSettingsRepository(device.db).load,
  ))!;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        syncServicesProvider.overrideWithValue(device.services),
        initialThemeSettingsProvider.overrideWithValue(theme),
        conflictNotificationsProvider.overrideWithValue(
          notifier ?? FakeConflictNotifier(),
        ),
        ...overrides,
      ],
      child: const PlannerApp(),
    ),
  );
  try {
    firstFrame?.call();
    await settle(tester);
    await body(device);
  } finally {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(device.db.close);
  }
}

/// Дождаться, пока правка дойдёт до базы и снимок перестроит экран.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pumpAndSettle();
}

/// Первое меню «⋯» в области контента (заголовок проекта или строка на
/// экране «Мои проекты»), а не в сайдбаре: меню строк сайдбара всегда в
/// дереве, хоть и невидимы без наведения.
Finder screenMenu() => find
    .descendant(
      of: find.byWidgetPredicate(
        (w) => w is ProjectScreen || w is ProjectsScreen,
      ),
      matching: find.byTooltip('More actions'),
    )
    .first;
