import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/data/projection/entity_fields.dart';
import 'package:planner/domain/workspace.dart';
import 'package:planner/features/quick_add/state/quick_add_controller.dart';
import 'package:planner/features/quick_add/ui/quick_add_composer.dart';
import 'package:planner/features/quick_add/ui/quick_add_field.dart';
import 'package:planner/features/shell/ui/sidebar.dart';
import 'package:planner/features/tasks/ui/add_task_editor.dart';

import '../../app/support/pump_app.dart';
import '../../sync/support/devices.dart';
import '../support/app_commands.dart';

// Быстрое добавление глазами пользователя (план M3.6). Локаль — en; часы
// тестового устройства — пятница 23.10.2026, 9:00.
void main() {
  final field = find.descendant(
    of: find.byType(QuickAddField),
    matching: find.byType(TextField),
  );

  QuickAddController controller(WidgetTester tester) =>
      tester.widget<TextField>(field).controller! as QuickAddController;

  Future<Workspace> read(WidgetTester tester, TestDevice device) async =>
      (await tester.runAsync(AppCommands(device).read))!;

  Future<void> openQuickAdd(WidgetTester tester) async {
    await tester.sendKeyEvent(LogicalKeyboardKey.keyQ);
    await settle(tester);
  }

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(field, text);
    await tester.pump();
  }

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await settle(tester);
  }

  /// Середина подсвеченного участка [text] в поле, в координатах экрана.
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

  testWidgets('`q` → окно; «Buy milk tomorrow p1» подсвечено, чипы '
      'показывают срок и приоритет; Enter — задача, окно закрыто, тост', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      await openQuickAdd(tester);
      expect(find.byType(QuickAddComposer), findsOneWidget);
      await type(tester, 'Buy milk tomorrow p1');
      expect(controller(tester).highlights.map((h) => h.kind.name), [
        'due',
        'priority',
      ]);
      final dialog = find.byType(Dialog);
      expect(
        find.descendant(of: dialog, matching: find.text('Tomorrow')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialog, matching: find.text('Priority 1')),
        findsOneWidget,
      );

      await press(tester, LogicalKeyboardKey.enter);
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('Task added'), findsOneWidget);
      final task = (await read(tester, device)).children(null).single;
      expect(task.content, 'Buy milk');
      expect(task.due?.date, '2026-10-24');
      expect(task.due?.string, 'tomorrow');
      expect(task.due?.lang, 'en');
      expect(task.priority, 1);
    });
  });

  testWidgets('`Ctrl+N` — то же окно быстрого добавления', (tester) async {
    await withApp(tester, (device) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await settle(tester);
      expect(find.byType(QuickAddComposer), findsOneWidget);
    });
  });

  testWidgets('клик по подсветке — дата остаётся текстом названия', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      await openQuickAdd(tester);
      await type(tester, 'Meet tomorrow');
      await tester.tapAt(centerOf(tester, 'tomorrow'));
      await tester.pump();
      expect(controller(tester).highlights, isEmpty);
      // Отмена держится при наборе дальше: участок едет с текстом.
      await type(tester, 'Big Meet tomorrow');
      expect(controller(tester).highlights, isEmpty);

      await press(tester, LogicalKeyboardKey.enter);
      final task = (await read(tester, device)).children(null).single;
      expect(task.content, 'Big Meet tomorrow');
      expect(task.due, isNull);
    });
  });

  testWidgets('Backspace сразу после даты — дата становится текстом, знак '
      'не стирается; следующий Backspace стирает', (tester) async {
    await withApp(tester, (device) async {
      await openQuickAdd(tester);
      await type(tester, 'Call tomorrow');
      expect(controller(tester).highlights, hasLength(1));
      await press(tester, LogicalKeyboardKey.backspace);
      expect(controller(tester).text, 'Call tomorrow');
      expect(controller(tester).highlights, isEmpty);
      await press(tester, LogicalKeyboardKey.backspace);
      expect(controller(tester).text, 'Call tomorro');
    });
  });

  testWidgets('`#` — «Create project», Enter выбирает; проект создаётся '
      'вместе с задачей', (tester) async {
    await withApp(tester, (device) async {
      await openQuickAdd(tester);
      await type(tester, 'Read #Books');
      expect(find.text('Create project "Books"'), findsOneWidget);
      await press(tester, LogicalKeyboardKey.enter);
      expect(controller(tester).text, 'Read #Books ');
      expect(find.text('Create project "Books"'), findsNothing);
      // До добавления задачи проекта нет (решение 1А).
      expect((await read(tester, device)).projectTree(), isEmpty);

      await press(tester, LogicalKeyboardKey.enter);
      final ws = await read(tester, device);
      final books = ws.projectTree().single.value;
      expect(books.name, 'Books');
      expect(ws.children(null, projectId: books.id).single.content, 'Read');
    });
  });

  testWidgets('метка из списка нажатием; неизвестный проект без «Create» — '
      'текст названия', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final urgent = (await tester.runAsync(
        () => app.labels.add(name: 'urgent'),
      ))!;
      await settle(tester);
      await openQuickAdd(tester);
      await type(tester, 'Fix %ur');
      await tester.tap(find.text('urgent'));
      await tester.pump();
      expect(controller(tester).text, 'Fix %urgent ');
      await type(tester, 'Fix %urgent #Nowhere');
      await press(tester, LogicalKeyboardKey.escape); // закрыть список
      expect(find.byType(Dialog), findsOneWidget);
      await press(tester, LogicalKeyboardKey.enter);

      final task = (await read(tester, device)).children(null).single;
      expect(task.content, 'Fix #Nowhere');
      expect(task.labelIds, [urgent]);
    });
  });

  testWidgets('вставка двух строк — «Add 2 tasks?»; «Add 2 tasks» — каждая '
      'строка разобрана сама', (tester) async {
    await withApp(tester, (device) async {
      await tester.tap(
        find.descendant(
          of: find.byType(AddTaskButton),
          matching: find.text('Add task'),
        ),
      );
      await tester.pumpAndSettle();
      await type(tester, 'Milk\nBread tomorrow\n');
      await tester.pumpAndSettle();
      expect(find.text('Add 2 tasks?'), findsOneWidget);
      expect(controller(tester).text, isEmpty);
      await tester.tap(find.text('Add 2 tasks'));
      await settle(tester);

      final tasks = (await read(tester, device)).children(null);
      expect(tasks.map((t) => t.content), ['Milk', 'Bread']);
      expect(tasks.first.due, isNull);
      expect(tasks.last.due?.date, '2026-10-24');
    });
  });

  testWidgets('вставка строк — «Add 1 task»: строки через пробел в поле', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      await openQuickAdd(tester);
      await type(tester, 'Milk\nBread');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add 1 task'));
      await tester.pumpAndSettle();
      expect(controller(tester).text, 'Milk Bread');
      expect((await read(tester, device)).children(null), isEmpty);
    });
  });

  testWidgets('вставка строк с отрезком времени в окно без срока — срок '
      'сегодня со временем отрезка; строка из одних токенов пропускается', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      await openQuickAdd(tester);
      await type(tester, 'Call 15:00-16:00\np1\nLunch 13:00-14:00');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add 3 tasks'));
      await settle(tester);
      final tasks = (await read(tester, device)).children(null);
      expect(tasks.map((t) => t.content), ['Call', 'Lunch']);
      expect(tasks.map((t) => (t.due?.date, t.due?.time)), [
        ('2026-10-23', '15:00'),
        ('2026-10-23', '13:00'),
      ]);
      expect(tasks.first.duration?.amount, 60);
    });
  });

  testWidgets('метка из «Create» остаётся, когда метки выбирают чипом', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final urgent = (await tester.runAsync(
        () => app.labels.add(name: 'urgent'),
      ))!;
      await settle(tester);
      await openQuickAdd(tester);
      await type(tester, 'Buy %shop');
      await press(tester, LogicalKeyboardKey.enter); // «Create label»
      expect(controller(tester).text, 'Buy %shop ');
      // Чип меток уже показывает новую метку: «shop».
      final chip = find.descendant(
        of: find.byType(Dialog),
        matching: find.byIcon(Icons.sell_outlined),
      );
      expect(
        find.descendant(of: find.byType(Dialog), matching: find.text('shop')),
        findsOneWidget,
      );
      await tester.tap(chip);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, 'urgent'));
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(controller(tester).text, 'Buy %shop ');
      await press(tester, LogicalKeyboardKey.enter);

      final ws = await read(tester, device);
      final task = ws.children(null).single;
      expect(task.content, 'Buy');
      expect(task.labelIds.map((id) => ws.label(id)!.name).toSet(), {
        'urgent',
        'shop',
      });
      expect(task.labelIds, contains(urgent));
    });
  });

  testWidgets('стёртый токен из «Create», набранный снова без «Create», — '
      'текст', (tester) async {
    await withApp(tester, (device) async {
      await openQuickAdd(tester);
      await type(tester, 'Read #Books');
      await press(tester, LogicalKeyboardKey.enter); // «Create project»
      await type(tester, 'Read ');
      await type(tester, 'Read #Books');
      await press(tester, LogicalKeyboardKey.escape); // закрыть список
      await press(tester, LogicalKeyboardKey.enter);
      final ws = await read(tester, device);
      expect(ws.projectTree(), isEmpty);
      expect(ws.children(null).single.content, 'Read #Books');
    });
  });

  testWidgets('подсказок нет в описании после `//` и для `#` в подзадаче', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await tester.runAsync(() => app.tasks.add(content: 'Trip'));
      await settle(tester);
      await openQuickAdd(tester);
      await type(tester, 'Report // ask @Ivan');
      expect(find.text('Create label "Ivan"'), findsNothing);
      await press(tester, LogicalKeyboardKey.escape);

      await tester.tap(find.text('Trip'));
      await settle(tester);
      await tester.tap(find.text('Add sub-task'));
      await tester.pumpAndSettle();
      await type(tester, 'Pack #Wo');
      expect(find.text('Create project "Wo"'), findsNothing);
    });
  });

  testWidgets('пока IME собирает слово, Backspace после даты стирает знак', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      await openQuickAdd(tester);
      final c = controller(tester);
      c.value = const TextEditingValue(
        text: 'Call tomorrow',
        selection: TextSelection.collapsed(offset: 13),
        composing: TextRange(start: 5, end: 13),
      );
      c.value = const TextEditingValue(
        text: 'Call tomorro',
        selection: TextSelection.collapsed(offset: 12),
        composing: TextRange(start: 5, end: 12),
      );
      expect(c.text, 'Call tomorro');
    });
  });

  testWidgets('срок чипом убирает распознанную дату из текста', (tester) async {
    await withApp(tester, (device) async {
      await openQuickAdd(tester);
      await type(tester, 'Pay rent tomorrow');
      await tester.tap(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text('Tomorrow'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();
      expect(controller(tester).text, 'Pay rent');
      await press(tester, LogicalKeyboardKey.enter);
      final task = (await read(tester, device)).children(null).single;
      expect(task.content, 'Pay rent');
      expect(task.due?.date, '2026-10-23');
    });
  });

  testWidgets('«Add sub-task»: тот же разбор, `#` — текст', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final parent = (await tester.runAsync(
        () => app.tasks.add(content: 'Trip'),
      ))!;
      // Между записями — кадр: иначе обновление снимка, начатое в
      // поддельном времени теста, держит базу, и вторая запись его ждёт.
      await settle(tester);
      await tester.runAsync(() => app.projects.add(name: 'Work'));
      await settle(tester);
      await tester.tap(find.text('Trip'));
      await settle(tester);
      await tester.tap(find.text('Add sub-task'));
      await tester.pumpAndSettle();
      await type(tester, 'Pack #Work tomorrow');
      await press(tester, LogicalKeyboardKey.enter);

      final ws = await read(tester, device);
      final sub = ws.children(parent).single;
      expect(sub.content, 'Pack #Work');
      expect(sub.due?.date, '2026-10-24');
    });
  });

  testWidgets('«Smart date recognition» выключено — дата в названии', (
    tester,
  ) async {
    await withApp(
      tester,
      before: (device) =>
          AppCommands(device).general.setSmartDateRecognition(false),
      (device) async {
        await openQuickAdd(tester);
        await type(tester, 'Pay tomorrow p2');
        await press(tester, LogicalKeyboardKey.enter);
        final task = (await read(tester, device)).children(null).single;
        expect(task.content, 'Pay tomorrow');
        expect(task.due, isNull);
        expect(task.priority, 2);
      },
    );
  });

  testWidgets('`↓` в окне открывает описание; описание пишется в задачу', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      await openQuickAdd(tester);
      expect(find.text('Description'), findsNothing);
      await type(tester, 'Call mom');
      await press(tester, LogicalKeyboardKey.arrowDown);
      await tester.enterText(
        find.widgetWithText(TextField, 'Description'),
        'about weekend',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);
      final task = (await read(tester, device)).children(null).single;
      expect(task.description, 'about weekend');
    });
  });

  testWidgets('«Add task» в сайдбаре на экране проекта — задача в проект', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final work = (await tester.runAsync(
        () => app.projects.add(name: 'Work'),
      ))!;
      await settle(tester);
      await tester.tap(find.text('Work').first);
      await settle(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(Sidebar),
          matching: find.text('Add task'),
        ),
      );
      await settle(tester);
      await type(tester, 'Report');
      await press(tester, LogicalKeyboardKey.enter);
      final ws = await read(tester, device);
      expect(ws.children(null, projectId: work).single.content, 'Report');
    });
  });

  Future<bool> saved(WidgetTester tester, TestDevice device) async =>
      (await tester.runAsync(
        AppCommands(device).settings.smartDateRecognition,
      ))!;

  Future<Finder> openGeneral(WidgetTester tester) async {
    await tester.sendKeyEvent(LogicalKeyboardKey.keyO);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await settle(tester);
    expect(find.text('General'), findsOneWidget);
    return find.widgetWithText(SwitchListTile, 'Smart date recognition');
  }

  testWidgets('компьютер: «Settings → General» — переключатель сохраняет '
      'только «Update», одной op', (tester) async {
    await withApp(tester, (device) async {
      final general = await openGeneral(tester);
      expect(tester.widget<SwitchListTile>(general).value, isTrue);
      await tester.tap(general);
      await tester.pump();
      expect(await saved(tester, device), isTrue);
      await tester.tap(find.text('Update').first);
      await settle(tester);
      expect(await saved(tester, device), isFalse);
      expect(tester.widget<SwitchListTile>(general).value, isFalse);
      final ops = (await tester.runAsync(device.ownOps))!;
      expect(
        ops.where((op) => op.field == SettingsFields.smartDateRecognition),
        hasLength(1),
      );
    });
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('Android: «Settings → General» — переключатель сохраняет сразу', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      final general = await openGeneral(tester);
      await tester.tap(general);
      await settle(tester);
      expect(await saved(tester, device), isFalse);
      expect(tester.widget<SwitchListTile>(general).value, isFalse);
    });
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
