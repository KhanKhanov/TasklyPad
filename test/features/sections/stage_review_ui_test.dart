import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/domain/view_options.dart';
import 'package:planner/features/common/state/drag_session.dart';
import 'package:planner/features/common/ui/drag_layer.dart';
import 'package:planner/features/sections/ui/section_editor.dart';
import 'package:planner/features/shell/ui/sidebar.dart';

import '../../app/support/pump_app.dart';
import '../support/app_commands.dart';
import '../support/drag_gestures.dart';

// Находки ревью конца этапа M4 (шаг M4.13) у раздела: переименование
// переживает смену сортировки и не превращается в перетаскивание. Локаль — en.
void main() {
  late String work;

  Future<void> prepare(WidgetTester tester, AppCommands app) async {
    work = (await tester.runAsync(() => app.projects.add(name: 'Work')))!;
    await settle(tester);
    final id = (await tester.runAsync(
      () => app.sections.add(work, name: 'Alpha'),
    ))!;
    await settle(tester);
    await tester.runAsync(
      () => app.tasks.add(content: 'Task', projectId: work, sectionId: id),
    );
    await settle(tester);
    await tester.tap(
      find.descendant(of: find.byType(Sidebar), matching: find.text('Work')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alpha'));
    await tester.pumpAndSettle();
    expect(find.byType(SectionEditor), findsOneWidget);
  }

  Finder field() => find.descendant(
    of: find.byType(SectionEditor),
    matching: find.byType(TextField),
  );

  testWidgets('переименование раздела переживает смену сортировки: поле и '
      'набранное остаются', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await prepare(tester, app);
      await tester.enterText(field(), 'Alpha 2');
      await tester.pump();
      final editor = tester.state(find.byType(SectionEditor));

      await tester.runAsync(() async {
        final v = await app.viewsRepo.load(ViewType.project, objectId: work);
        await app.views.save(v, v.copyWith(sorting: Sorting.alphabetically));
      });
      await settle(tester);

      expect(find.byType(SectionEditor), findsOneWidget);
      expect(tester.state(find.byType(SectionEditor)), same(editor));
      expect(tester.widget<TextField>(field()).controller!.text, 'Alpha 2');
    });
  });

  testWidgets('долгое нажатие в поле переименования раздела не начинает '
      'перетаскивание', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await prepare(tester, app);
      final from = tester.getCenter(field());
      final touch = await tester.startGesture(from);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await moveInSteps(tester, touch, from, from + const Offset(0, 120));
      expect(
        ProviderScope.containerOf(tester.element(find.byType(DragLayer).first))
            .read(dragSessionProvider),
        isNull,
      );
      await touch.up();
      await tester.pumpAndSettle();
      expect(find.byType(SectionEditor), findsOneWidget);
    });
  });

  testWidgets('после отмены переименования долгое нажатие на заголовке снова '
      'перетаскивает раздел', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await prepare(tester, app);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(SectionEditor), findsNothing);

      final from = tester.getCenter(find.text('Alpha')) + const Offset(60, 0);
      final touch = await tester.startGesture(from);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await moveInSteps(tester, touch, from, from + const Offset(0, 60));
      expect(
        ProviderScope.containerOf(tester.element(find.byType(DragLayer).first))
            .read(dragSessionProvider),
        isNotNull,
      );
      await touch.up();
      await tester.pumpAndSettle();
    });
  });
}
