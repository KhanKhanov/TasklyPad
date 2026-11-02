import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/domain/models.dart';
import 'package:planner/features/tasks/state/title_date_controller.dart';
import 'package:planner/features/tasks/ui/task_title_field.dart';

import '../../app/support/pump_app.dart';
import '../support/app_commands.dart';

// Дата в названии существующей задачи (решение 1А конца M3, help
// «Introduction to recurring dates»). Локаль — en; часы — пт 23.10.2026 9:00.
void main() {
  final field = find.descendant(
    of: find.byType(TaskTitleField),
    matching: find.byType(TextField),
  );

  TitleDateController controller(WidgetTester tester) =>
      tester.widget<TextField>(field).controller! as TitleDateController;

  Future<String> addTask(
    WidgetTester tester,
    AppCommands app,
    String content, {
    Due? due,
  }) async {
    final id = (await tester.runAsync(
      () => app.tasks.add(content: content, due: due),
    ))!;
    await settle(tester);
    return id;
  }

  Future<Task> task(WidgetTester tester, AppCommands app, String id) async =>
      (await tester.runAsync(app.read))!.task(id)!;

  Future<void> open(WidgetTester tester, String content) async {
    await tester.tap(find.text(content));
    await settle(tester);
  }

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(field, text);
    await tester.pump();
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
  }

  /// Середина участка [text] в поле, в координатах экрана.
  Offset centerOf(WidgetTester tester, String text) {
    RenderEditable? editable;
    void visit(RenderObject o) {
      if (o is RenderEditable) {
        editable ??= o;
      } else {
        o.visitChildren(visit);
      }
    }

    visit(tester.renderObject(field));
    final start = controller(tester).text.indexOf(text);
    final box = editable!
        .getBoxesForSelection(
          TextSelection(baseOffset: start, extentOffset: start + text.length),
        )
        .single
        .toRect();
    return editable!.localToGlobal(box.center);
  }

  testWidgets('набранная дата подсвечена; Enter — название без даты и новый '
      'срок одной правкой', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final id = await addTask(tester, app, 'Call mom');
      await open(tester, 'Call mom');
      await type(tester, 'Call mom tomorrow at 10');
      expect(controller(tester).parsed?.highlight.start, 9);

      await submit(tester);
      final t = await task(tester, app, id);
      expect(t.content, 'Call mom');
      expect(
        t.due,
        const Due(
          date: '2026-10-24',
          time: '10:00',
          string: 'tomorrow at 10',
          lang: 'en',
        ),
      );
      expect(controller(tester).text, 'Call mom');
      expect(controller(tester).parsed, isNull);
    });
  });

  testWidgets('дата, что уже стоит в названии, — текст: правка рядом и '
      'закрытие срок не меняют', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final id = await addTask(tester, app, 'Pay rent friday');
      await open(tester, 'Pay rent friday');
      expect(controller(tester).parsed, isNull);
      await type(tester, 'Pay the rent friday');
      expect(controller(tester).parsed, isNull);

      await submit(tester);
      final t = await task(tester, app, id);
      expect((t.content, t.due), ('Pay the rent friday', null));
    });
  });

  testWidgets('новая дата заменяет срок вместе с повтором', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final id = await addTask(
        tester,
        app,
        'Gym',
        due: const Due(
          date: '2026-10-23',
          string: 'every day',
          lang: 'en',
          rule: RecurrenceRule(rrule: ['FREQ=DAILY'], fromCompletion: false),
        ),
      );
      await open(tester, 'Gym');
      await type(tester, 'Gym every mon');
      await submit(tester);
      final due = (await task(tester, app, id)).due!;
      expect(
        (due.date, due.rule),
        (
          '2026-10-26',
          const RecurrenceRule(
            rrule: ['FREQ=WEEKLY;BYDAY=MO'],
            fromCompletion: false,
          ),
        ),
      );

      await type(tester, 'Gym next week');
      await submit(tester);
      final plain = (await task(tester, app, id)).due!;
      expect((plain.date, plain.isRecurring), ('2026-10-26', false));
    });
  });

  testWidgets('клик по подсветке и Backspace после даты оставляют её текстом', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final id = await addTask(tester, app, 'Meet');
      await open(tester, 'Meet');
      await type(tester, 'Meet tomorrow');
      await tester.tapAt(centerOf(tester, 'tomorrow'));
      await tester.pump();
      expect(controller(tester).parsed, isNull);
      await submit(tester);
      expect(
        (
          (await task(tester, app, id)).content,
          (await task(tester, app, id)).due,
        ),
        ('Meet tomorrow', null),
      );

      await type(tester, 'Meet tomorrow friday');
      expect(controller(tester).parsed?.due?.date, '2026-10-30');
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();
      expect(controller(tester).text, 'Meet tomorrow friday');
      expect(controller(tester).parsed, isNull);
    });
  });

  testWidgets('название из одной даты — пустое: сохраняется прежнее, без '
      'ошибки', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final id = await addTask(tester, app, 'Report');
      await open(tester, 'Report');
      await type(tester, 'tomorrow');
      await submit(tester);
      final t = await task(tester, app, id);
      expect((t.content, t.due), ('Report', null));
      // Тихо, как пустое название, — без тоста об ошибке.
      expect(find.byType(SnackBar), findsNothing);
    });
  });

  testWidgets('«Умное распознавание даты» выключено — дата в названии — '
      'текст', (tester) async {
    await withApp(
      tester,
      before: (device) =>
          AppCommands(device).general.save(smartDateRecognition: false),
      (device) async {
        final app = AppCommands(device);
        final id = await addTask(tester, app, 'Meet');
        await open(tester, 'Meet');
        await type(tester, 'Meet tomorrow');
        expect(controller(tester).parsed, isNull);
        await submit(tester);
        final t = await task(tester, app, id);
        expect((t.content, t.due), ('Meet tomorrow', null));
      },
    );
  });

  testWidgets('открыть задачу с датой в названии и закрыть без правки — '
      'ни одной правки в журнале', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await addTask(tester, app, 'Pay rent friday');
      final before = (await tester.runAsync(device.ownOps))!.length;
      await open(tester, 'Pay rent friday');
      await tester.tap(find.byTooltip('Close'));
      await settle(tester);
      expect((await tester.runAsync(device.ownOps))!.length, before);
    });
  });

  testWidgets('правка с датой и сразу закрытие окна — срок записан, ошибок '
      'нет', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final id = await addTask(tester, app, 'Call');
      await open(tester, 'Call');
      await type(tester, 'Call tomorrow');
      await tester.tap(find.byTooltip('Close'));
      await settle(tester);
      final t = await task(tester, app, id);
      expect((t.content, t.due?.date), ('Call', '2026-10-24'));
    });
  });
}
