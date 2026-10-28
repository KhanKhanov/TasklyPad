import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:planner/app/sync_providers.dart';
import 'package:planner/data/projection/entity_fields.dart';
import 'package:planner/features/conflicts/state/conflict_notices.dart';
import 'package:planner/features/conflicts/ui/conflicts_screen.dart';
import 'package:planner/features/settings/state/sync_controller.dart';

import '../../app/support/fake_conflict_notifier.dart';
import '../../app/support/pump_app.dart';
import '../../sync/support/devices.dart';
import '../settings/fake_sync.dart';

// Экран «Конфликты», пункт сайдбара и уведомление о новых конфликтах.
// Конфликт — настоящий: второе устройство и обмен ops через движок. Локаль — en.
void main() {
  /// Задача «a», переименованная параллельно: здесь — в «mine», на другом
  /// устройстве — позже в «theirs». Возвращает id задачи.
  ///
  /// Каждый шаг с базой приложения — отдельным `runAsync` с кадрами между
  /// ними: правка будит потоки экранов, их запросы идут в фейковом времени
  /// теста, и следующий запрос к той же базе внутри одного `runAsync` ждал
  /// бы их вечно.
  Future<String> makeConflict(WidgetTester tester, TestDevice device) async {
    final mutator = device.services.mutator;
    final other = (await tester.runAsync(() => TestDevice.start(seed: 7)))!;
    final id = (await tester.runAsync(
      () => mutator.create(EntityTypes.task, {
        TaskFields.content: 'a',
        TaskFields.projectId: inboxProjectId,
      }),
    ))!;
    await settle(tester);
    final created = (await tester.runAsync(device.ownOps))!;
    await settle(tester);
    await tester.runAsync(() async {
      await other.services.engine.applyAll(created);
      other.advance(const Duration(minutes: 1));
      await other.services.mutator.update(EntityTypes.task, id, {
        TaskFields.content: 'theirs',
      });
    });
    await tester.runAsync(
      () => mutator.update(EntityTypes.task, id, {TaskFields.content: 'mine'}),
    );
    await settle(tester);
    final theirs = (await tester.runAsync(other.ownOps))!;
    await tester.runAsync(() async {
      await device.services.engine.applyAll(theirs);
      await other.db.close();
    });
    await settle(tester);
    return id;
  }

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));

  Future<void> checkNotices(WidgetTester tester) async {
    await tester.runAsync(
      () => containerOf(tester).read(conflictNoticesProvider.notifier).check(),
    );
    await settle(tester);
  }

  testWidgets('нет конфликтов — пункта в сайдбаре нет, экран пуст', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      expect(find.text('Conflicts'), findsNothing);
      GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/conflicts');
      await settle(tester);
      expect(find.byType(ConflictsScreen), findsOneWidget);
      expect(find.text('No conflicts'), findsOneWidget);
    });
  });

  testWidgets('конфликт названия: пункт с числом, карточка с обеими '
      'сторонами; выбор стороны меняет задачу и закрывает конфликт', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      final id = await makeConflict(tester, device);
      final item = find.widgetWithText(InkWell, 'Conflicts');
      expect(item, findsOneWidget);
      expect(find.descendant(of: item, matching: find.text('1')), findsOne);

      await tester.tap(item);
      await settle(tester);
      expect(find.text('Task “theirs”'), findsOneWidget);
      expect(find.text('This device'), findsOneWidget);
      expect(find.textContaining('Device …'), findsOneWidget);
      expect(find.text('Applies now'), findsOneWidget);
      expect(find.text('Name: mine'), findsOneWidget);
      expect(find.text('Name: theirs'), findsOneWidget);

      // Ранняя сторона — своя правка «mine».
      await tester.tap(find.text('Keep this version').first);
      await settle(tester);
      expect(find.text('No conflicts'), findsOneWidget);
      expect(find.widgetWithText(InkWell, 'Conflicts'), findsNothing);
      final row = await tester.runAsync(() => device.taskRow(id));
      expect(row!.content, 'mine');
    });
  });

  testWidgets('новый конфликт при активном окне — тост с «Open» один раз; '
      'при неактивном — уведомление ОС, клик открывает экран', (tester) async {
    final notifier = FakeConflictNotifier();
    await withApp(tester, notifier: notifier, (device) async {
      await makeConflict(tester, device);
      await checkNotices(tester);
      expect(find.text('Conflict: Task “theirs”, field Name'), findsOneWidget);
      await tester.tap(find.text('Open'));
      await settle(tester);
      expect(find.byType(ConflictsScreen), findsOneWidget);

      await checkNotices(tester);
      expect(notifier.shown, isEmpty);
      ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first))
          .hideCurrentSnackBar();
      await settle(tester);

      GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/');
      await settle(tester);
      notifier.active = false;
      await makeConflict(tester, device);
      await checkNotices(tester);
      expect(notifier.shown.single.body, 'Conflict: Task “theirs”, field Name');
      expect(notifier.shown.single.title, 'Sync conflict');

      notifier.open();
      await settle(tester);
      expect(find.byType(ConflictsScreen), findsOneWidget);
    });
  });

  testWidgets('конфликт появился — тост после окончания прохода синхронизации, '
      'без вызова проверки вручную', (tester) async {
    final runner = FakeSyncRunner(folder: 'C:/OneDrive');
    await withApp(
      tester,
      overrides: [syncRunnerProvider.overrideWithValue(runner)],
      (device) async {
        await makeConflict(tester, device);
        expect(find.text('Conflict: Task “theirs”, field Name'), findsNothing);
        await tester.runAsync(
          () =>
              containerOf(tester)
                  .read(syncControllerProvider.notifier)
                  .syncNow(),
        );
        await settle(tester);
        expect(
          find.text('Conflict: Task “theirs”, field Name'),
          findsOneWidget,
        );
      },
    );
  });

  testWidgets('узкое окно — стороны одна под другой', (tester) async {
    await withApp(tester, size: const Size(400, 800), (device) async {
      await makeConflict(tester, device);
      GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/conflicts');
      await settle(tester);
      final buttons = find.text('Keep this version');
      expect(buttons, findsNWidgets(2));
      final (a, b) = (
        tester.getTopLeft(buttons.at(0)),
        tester.getTopLeft(buttons.at(1)),
      );
      expect(a.dx, b.dx);
      expect(b.dy, greaterThan(a.dy));
    });
  });

  testWidgets('«Оставить удалённым», когда удаление уже не действует, — '
      'только после подтверждения', (tester) async {
    await withApp(tester, (device) async {
      final mutator = device.services.mutator;
      final other = (await tester.runAsync(() => TestDevice.start(seed: 7)))!;
      final id = (await tester.runAsync(
        () => mutator.create(EntityTypes.task, {
          TaskFields.content: 'Отчёт',
          TaskFields.projectId: inboxProjectId,
        }),
      ))!;
      await settle(tester);
      final created = (await tester.runAsync(device.ownOps))!;
      await tester.runAsync(() async {
        await other.services.engine.applyAll(created);
        await other.services.mutator.update(EntityTypes.task, id, {
          TaskFields.content: 'Отчёт v2',
        });
      });
      await tester.runAsync(() => mutator.delete(EntityTypes.task, id));
      await settle(tester);
      final theirs = (await tester.runAsync(other.ownOps))!;
      await tester.runAsync(() async {
        await device.services.engine.applyAll(theirs);
        await other.db.close();
      });
      await settle(tester);
      await tester.runAsync(() => mutator.restore(EntityTypes.task, id));
      await settle(tester);
      GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/conflicts');
      await settle(tester);

      await tester.tap(find.text('Keep deleted'));
      await settle(tester);
      expect(find.text('Delete again?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(
        (await tester.runAsync(() => device.taskRow(id)))!.deleted,
        isFalse,
      );

      await tester.tap(find.text('Keep deleted'));
      await settle(tester);
      await tester.tap(find.text('Keep deleted').last);
      await settle(tester);
      expect(
        (await tester.runAsync(() => device.taskRow(id)))!.deleted,
        isTrue,
      );
      expect(find.text('No conflicts'), findsOneWidget);
    });
  });
}
