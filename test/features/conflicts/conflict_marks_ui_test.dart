import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:planner/data/projection/entity_fields.dart';
import 'package:planner/features/conflicts/ui/conflict_card.dart';
import 'package:planner/features/labels/ui/filters_labels_screen.dart';
import 'package:planner/features/projects/ui/project_screen.dart';
import 'package:planner/features/tasks/ui/task_dialog.dart';

import '../../app/support/pump_app.dart';
import '../../sync/support/devices.dart';
import 'support/conflict_fixtures.dart';

// Пометка «Конфликт» у спорной сущности и окно «Выбрать» (решение 1Б «Хода
// M4.13»). Конфликты настоящие, локаль — en.
void main() {
  const banner = 'Changed on two devices';

  void go(WidgetTester tester, String path) =>
      GoRouter.of(tester.element(find.byType(Scaffold).first)).go(path);

  testWidgets('задача: чип в строке, плашка в окне, «Choose» — окно с '
      'карточкой; выбор стороны закрывает окно, чип и плашку', (tester) async {
    await withApp(tester, (device) async {
      final id = await makeConflict(tester, device);
      expect(find.text('Conflict'), findsOneWidget);

      await tester.tap(find.text('theirs'));
      await settle(tester);
      expect(find.byType(TaskDialog), findsOneWidget);
      expect(find.text(banner), findsOneWidget);

      await tester.tap(find.text('Choose'));
      await settle(tester);
      expect(find.byType(ConflictCardView), findsOneWidget);
      expect(find.text('Name: mine'), findsOneWidget);

      await tester.tap(find.text('Keep this version').first);
      await settle(tester);
      expect(find.byType(ConflictCardView), findsNothing);
      expect(find.byType(TaskDialog), findsOneWidget);
      expect(find.text(banner), findsNothing);
      expect(find.text('Conflict'), findsNothing);
      expect(
        (await tester.runAsync(() => device.taskRow(id)))!.content,
        'mine',
      );

      // `Ctrl+Z` после выбора ничего не откатывает: у выбора нет «Отменить».
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await settle(tester);
      expect(
        (await tester.runAsync(() => device.taskRow(id)))!.content,
        'mine',
      );
    });
  });

  testWidgets('`Esc` в окне карточек закрывает только его, окно задачи '
      'остаётся', (tester) async {
    await withApp(tester, (device) async {
      await makeConflict(tester, device);
      await tester.tap(find.text('theirs'));
      await settle(tester);
      await tester.tap(find.text('Choose'));
      await settle(tester);
      expect(find.byType(ConflictCardView), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(find.byType(ConflictCardView), findsNothing);
      expect(find.byType(TaskDialog), findsOneWidget);
      expect(find.text(banner), findsOneWidget);
    });
  });

  testWidgets('проект: значок с подсказкой в сайдбаре и плашка в заголовке', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      final id = await makeProjectConflict(tester, device);
      expect(find.byTooltip(banner), findsOneWidget);
      expect(find.text(banner), findsNothing);

      go(tester, '/project/$id');
      await settle(tester);
      expect(find.byType(ProjectScreen), findsOneWidget);
      expect(find.text(banner), findsOneWidget);

      await tester.tap(find.text('Choose'));
      await settle(tester);
      await tester.tap(find.text('Keep this version').first);
      await settle(tester);
      expect(find.text(banner), findsNothing);
      expect(find.byTooltip(banner), findsNothing);
    });
  });

  testWidgets('спор об описании проекта не помечает его (решение 1А)', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      final id = await makeProjectDescriptionConflict(tester, device);
      go(tester, '/project/$id');
      await settle(tester);
      expect(find.byTooltip(banner), findsNothing);
      expect(find.text(banner), findsNothing);
      // Спор есть — он на экране «Конфликты», только без пометки.
      go(tester, '/conflicts');
      await settle(tester);
      expect(find.byType(ConflictCardView), findsOneWidget);
    });
  });

  testWidgets('раздел: чип в заголовке открывает окно с карточкой', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      final (:project, section: _) = await makeSectionConflict(tester, device);
      go(tester, '/project/$project');
      await settle(tester);
      expect(find.text('Conflict'), findsOneWidget);

      await tester.tap(find.text('Conflict'));
      await settle(tester);
      expect(find.byType(ConflictCardView), findsOneWidget);

      await tester.tap(find.text('Keep this version').first);
      await settle(tester);
      expect(find.byType(ConflictCardView), findsNothing);
      expect(find.text('Conflict'), findsNothing);
    });
  });

  testWidgets('метка: цвет в споре — значок на «Фильтры и метки»', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      await makeLabelColorConflict(tester, device);
      go(tester, '/filters-labels');
      await settle(tester);
      expect(find.byType(FiltersLabelsScreen), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(FiltersLabelsScreen),
          matching: find.byTooltip(banner),
        ),
        findsOneWidget,
      );
    });
  });

  testWidgets('узкий экран: окно карточек — на весь экран', (tester) async {
    await withApp(tester, size: const Size(400, 800), (device) async {
      await makeConflict(tester, device);
      await tester.tap(find.text('theirs'));
      await settle(tester);
      await tester.tap(find.text('Choose'));
      await settle(tester);
      expect(find.byType(ConflictCardView), findsOneWidget);
      final dialog = find.ancestor(
        of: find.byType(ConflictCardView),
        matching: find.byType(Dialog),
      );
      expect(tester.getSize(dialog), const Size(400, 800));
    });
  });

  // Ревью 1Б: окно задачи, закрываясь само (задачу удалили выбором), снимало
  // верхний маршрут — окно карточек, а само оставалось пустым затемнением.
  testWidgets('«Оставить удалённым» из окна задачи — закрываются и окно '
      'карточек, и окно задачи', (tester) async {
    await withApp(tester, (device) async {
      final mutator = device.services.mutator;
      final other = (await tester.runAsync(() => TestDevice.start(seed: 7)))!;
      final id = (await tester.runAsync(
        () => mutator.create(EntityTypes.task, {
          TaskFields.content: 'Report',
          TaskFields.projectId: inboxProjectId,
        }),
      ))!;
      await settle(tester);
      final created = (await tester.runAsync(device.ownOps))!;
      await tester.runAsync(() async {
        await other.services.engine.applyAll(created);
        await other.services.mutator.update(EntityTypes.task, id, {
          TaskFields.content: 'Report v2',
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
      expect(find.text('Conflict'), findsOneWidget);
      // Барьер есть у каждого маршрута, и у страниц: окон нет — столько.
      final barriers = find.byType(ModalBarrier).evaluate().length;

      await tester.tap(find.text('Report v2'));
      await settle(tester);
      await tester.tap(find.text('Choose'));
      await settle(tester);
      await tester.tap(find.text('Keep deleted'));
      await settle(tester);
      await tester.tap(find.text('Keep deleted').last);
      await settle(tester);

      expect(
        (await tester.runAsync(() => device.taskRow(id)))!.deleted,
        isTrue,
      );
      expect(find.byType(ConflictCardView), findsNothing);
      expect(find.byType(TaskDialog), findsNothing);
      expect(find.byType(ModalBarrier), findsNWidgets(barriers));
    });
  });
}
