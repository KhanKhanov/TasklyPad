import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/data/projection/entity_fields.dart';
import 'package:planner/domain/view_options.dart';
import 'package:planner/domain/view_order.dart';
import 'package:planner/features/tasks/ui/task_dialog.dart';
import 'package:planner/features/tasks/ui/task_row.dart';

import '../../app/support/fake_link_opener.dart';
import '../../app/support/pump_app.dart';
import '../../sync/support/devices.dart';
import '../support/app_commands.dart';

// Markdown в названии и описании (help «Format text in a Todoist task»; О-53,
// решения 6А, 7А плана M4). Локаль виджет-тестов — en.
const _title = '**Bold** and *it* `code` ~~old~~ [site](https://example.com/t)';
const _plain = 'Bold and it code old site';

void main() {
  Future<String> addTask(
    WidgetTester tester,
    TestDevice device,
    String content, {
    String description = '',
  }) async {
    final id = (await tester.runAsync(
      () =>
          AppCommands(device).tasks
              .add(content: content, description: description),
    ))!;
    await settle(tester);
    return id;
  }

  /// Стиль первого куска текста [piece] в отрисованной строке [of].
  TextStyle styleOf(WidgetTester tester, Finder of, String piece) {
    for (final rich in tester.widgetList<RichText>(
      find.descendant(of: of, matching: find.byType(RichText)),
    )) {
      TextStyle? found;
      rich.text.visitChildren((span) {
        if (span is TextSpan && span.text == piece) {
          found = span.style;
          return false;
        }
        return true;
      });
      if (found != null) return found!;
    }
    throw StateError('нет «$piece»');
  }

  Future<void> tapLink(WidgetTester tester, String text) async {
    await tester.tapOnText(find.textRange.ofSubstring(text));
    await settle(tester);
  }

  Finder panel() => find.byType(TaskDialog);

  testWidgets('строка задачи: разметка отрисована, знаков не видно', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      await addTask(tester, device, _title);
      final row = find.byType(TaskRow);
      expect(find.text(_plain), findsOneWidget);
      expect(find.textContaining('**'), findsNothing);
      expect(styleOf(tester, row, 'Bold').fontWeight, FontWeight.w700);
      expect(styleOf(tester, row, 'it').fontStyle, FontStyle.italic);
      expect(styleOf(tester, row, 'code').fontFamily, 'Consolas');
      expect(
        styleOf(tester, row, 'old').decoration,
        TextDecoration.lineThrough,
      );
      expect(styleOf(tester, row, 'site').decoration, TextDecoration.underline);
    });
  });

  testWidgets('ссылка в строке открывается, задача — нет', (tester) async {
    final links = FakeLinkOpener();
    await withApp(tester, links: links, (device) async {
      await addTask(tester, device, _title);
      await tapLink(tester, 'site');
      expect(links.opened, [Uri.parse('https://example.com/t')]);
      expect(panel(), findsNothing);
    });
  });

  testWidgets('ссылка с чужой схемой не открывается — тост', (tester) async {
    final links = FakeLinkOpener();
    await withApp(tester, links: links, (device) async {
      await addTask(tester, device, 'Run [tool](file:///C:/tool.exe)');
      await tapLink(tester, 'tool');
      expect(links.opened, isEmpty);
      expect(find.text("Couldn't open the link"), findsOneWidget);
    });
  });

  testWidgets('панель: название отрисовано; нажатие — исходный текст; Ctrl+B '
      'и Enter — сохранено с разметкой и снова отрисовано', (tester) async {
    await withApp(tester, (device) async {
      final id = await addTask(tester, device, '*Plan* trip');
      await tester.tap(find.text('Plan trip'));
      await settle(tester);
      final title = find.descendant(
        of: panel(),
        matching: find.text('Plan trip'),
      );
      expect(title, findsOneWidget);

      await tester.tap(title);
      await tester.pumpAndSettle();
      final field = find.descendant(
        of: panel(),
        matching: find.widgetWithText(TextField, '*Plan* trip'),
      );
      expect(field, findsOneWidget);
      final controller = tester.widget<TextField>(field).controller!;
      controller.selection = const TextSelection(
        baseOffset: 7,
        extentOffset: 11,
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);

      final ws = await tester.runAsync(() => AppCommands(device).read());
      expect(ws!.task(id)!.content, '*Plan* **trip**');
      expect(
        find.descendant(of: panel(), matching: find.text('Plan trip')),
        findsOneWidget,
      );
    });
  });

  Future<void> ctrl(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  }

  testWidgets('Ctrl+B рядом с датой в названии — меняется только разметка, '
      'срок не появляется (ревью M4.12)', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      final off = await addTask(tester, device, '**Call on friday**');
      final on = await addTask(tester, device, 'Meeting tomorrow');

      // Снять жирный: отрисованное название → поле → выделить внутри.
      await tester.tap(find.text('Call on friday'));
      await settle(tester);
      await tester.tap(
        find.descendant(of: panel(), matching: find.text('Call on friday')),
      );
      await tester.pumpAndSettle();
      var field = find.descendant(
        of: panel(),
        matching: find.widgetWithText(TextField, '**Call on friday**'),
      );
      tester.widget<TextField>(field).controller!.selection =
          const TextSelection(baseOffset: 2, extentOffset: 16);
      await ctrl(tester, LogicalKeyboardKey.keyB);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);
      var ws = (await tester.runAsync(app.read))!;
      expect(ws.task(off)!.content, 'Call on friday');
      expect(ws.task(off)!.due, isNull);

      // Обернуть всё название с датой-текстом.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      await tester.tap(find.text('Meeting tomorrow'));
      await settle(tester);
      field = find.descendant(
        of: panel(),
        matching: find.widgetWithText(TextField, 'Meeting tomorrow'),
      );
      await tester.tap(field);
      await tester.pump();
      tester.widget<TextField>(field).controller!.selection =
          const TextSelection(baseOffset: 0, extentOffset: 16);
      await ctrl(tester, LogicalKeyboardKey.keyB);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);
      ws = (await tester.runAsync(app.read))!;
      expect(ws.task(on)!.content, '**Meeting tomorrow**');
      expect(ws.task(on)!.due, isNull);
    });
  });

  testWidgets('панель форматирования в окне задачи: «Ссылка» на название с '
      'разметкой — поле не закрывается, ссылка сохраняется', (tester) async {
    await withApp(tester, (device) async {
      final id = await addTask(tester, device, '**Read** docs');
      await tester.tap(find.text('Read docs'));
      await settle(tester);
      await tester.tap(
        find.descendant(of: panel(), matching: find.text('Read docs')),
      );
      await tester.pumpAndSettle();
      final field = find.descendant(
        of: panel(),
        matching: find.widgetWithText(TextField, '**Read** docs'),
      );
      tester.widget<TextField>(field).controller!.selection =
          const TextSelection(baseOffset: 9, extentOffset: 13);
      await tester.pump();
      await tester.tap(find.byTooltip('Link'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Address'),
        'https://docs.example',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      final linked = find.descendant(
        of: panel(),
        matching: find.widgetWithText(
          TextField,
          '**Read** [docs](https://docs.example)',
        ),
      );
      expect(linked, findsOneWidget);
      expect(tester.widget<TextField>(linked).focusNode!.hasFocus, isTrue);

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);
      final ws = await tester.runAsync(() => AppCommands(device).read());
      expect(ws!.task(id)!.content, '**Read** [docs](https://docs.example)');
    });
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('«Ссылка» в названии с датой: пока окно открыто, срок не '
      'пишется; после Enter — ссылка и срок (ревью M4.12)', (tester) async {
    await withApp(tester, (device) async {
      final id = await addTask(tester, device, 'Read docs');
      await tester.tap(find.text('Read docs'));
      await settle(tester);
      final field = find
          .descendant(of: panel(), matching: find.byType(TextField))
          .first;
      await tester.tap(field);
      await tester.pump();
      final controller = tester.widget<TextField>(field).controller!;
      // Дата набрана сейчас — она распознана, а не текст из базы.
      controller.value = const TextEditingValue(
        text: 'Read docs tomorrow',
        selection: TextSelection.collapsed(offset: 18),
      );
      await tester.pump();
      controller.selection = const TextSelection(
        baseOffset: 5,
        extentOffset: 9,
      );
      await tester.pump();
      await tester.tap(find.byTooltip('Link'));
      await tester.pumpAndSettle();
      var ws = (await tester.runAsync(() => AppCommands(device).read()))!;
      expect(ws.task(id)!.content, 'Read docs');
      expect(ws.task(id)!.due, isNull);

      await tester.enterText(
        find.widgetWithText(TextField, 'Address'),
        'https://d.example',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(controller.text, 'Read [docs](https://d.example) tomorrow');

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);
      ws = (await tester.runAsync(() => AppCommands(device).read()))!;
      expect(ws.task(id)!.content, 'Read [docs](https://d.example)');
      expect(ws.task(id)!.due, isNotNull);
    });
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('Tab из названия открывает описание с разметкой', (tester) async {
    await withApp(tester, (device) async {
      const description = '# Steps\n- one';
      await addTask(tester, device, 'Task', description: description);
      await tester.tap(find.text('Task'));
      await settle(tester);
      await tester.tap(
        find.descendant(
          of: panel(),
          matching: find.widgetWithText(TextField, 'Task'),
        ),
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      final field = find.descendant(
        of: panel(),
        matching: find.widgetWithText(TextField, description),
      );
      expect(field, findsOneWidget);
      expect(tester.widget<TextField>(field).focusNode!.hasFocus, isTrue);
    });
  });

  testWidgets('правка с другого устройства видна в отрисованном названии', (
    tester,
  ) async {
    await withApp(tester, (device) async {
      final id = await addTask(tester, device, '**Alpha** one');
      await tester.tap(find.text('Alpha one'));
      await settle(tester);
      await tester.runAsync(
        () => AppCommands(device).tasks.rename(id, '**Beta** two'),
      );
      await settle(tester);
      expect(
        find.descendant(of: panel(), matching: find.text('Beta two')),
        findsOneWidget,
      );
    });
  });

  testWidgets('панель: описание с блоками отрисовано, ссылка открывается, '
      'нажатие — исходный текст', (tester) async {
    final links = FakeLinkOpener();
    await withApp(tester, links: links, (device) async {
      const description = '# Steps\n- **one**\n- [docs](https://example.com/d)';
      await addTask(tester, device, 'Task', description: description);
      // Строка показывает первую строку описания без знаков блоков.
      expect(
        find.descendant(of: find.byType(TaskRow), matching: find.text('Steps')),
        findsOneWidget,
      );
      await tester.tap(find.text('Task'));
      await settle(tester);
      expect(
        find.descendant(of: panel(), matching: find.byType(MarkdownBody)),
        findsOneWidget,
      );
      expect(find.textContaining('# Steps'), findsNothing);

      await tapLink(tester, 'docs');
      expect(links.opened, [Uri.parse('https://example.com/d')]);
      expect(find.byType(MarkdownBody), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: panel(),
          matching: find.text('Steps', findRichText: true),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: panel(),
          matching: find.widgetWithText(TextField, description),
        ),
        findsOneWidget,
      );
    });
  });

  testWidgets('описание проекта: markdown отрисован, ссылка открывается', (
    tester,
  ) async {
    final links = FakeLinkOpener();
    await withApp(tester, links: links, (device) async {
      final app = AppCommands(device);
      final id = (await tester.runAsync(() => app.projects.add(name: 'Work')))!;
      await settle(tester);
      await tester.runAsync(
        () => app.projects.setDescription(
          id,
          '**Goals** for [Q4](https://example.com/q4)',
        ),
      );
      await settle(tester);
      await tester.tap(find.text('Work'));
      await settle(tester);
      expect(find.text('Goals for Q4'), findsOneWidget);
      await tapLink(tester, 'Q4');
      expect(links.opened, [Uri.parse('https://example.com/q4')]);
      // Нажатие на ссылку не открыло редактор описания.
      expect(find.text('Save'), findsNothing);
    });
  });

  test('сортировка по имени — по видимому тексту без разметки', () async {
    final device = await TestDevice.start();
    final app = AppCommands(device);
    await app.tasks.add(content: '**b** task');
    await app.tasks.add(content: 'a task');
    await app.tasks.add(content: '[c](https://x.com) task');
    final ws = await app.read();
    final order = ws.taskOrder(
      DefaultOrder.smart,
      sorting: Sorting.alphabetically,
    );
    final tasks = ws.projectTasks(inboxProjectId, showCompleted: false)
      ..sort(order.compare);
    expect(
      [for (final t in tasks) t.content],
      ['a task', '**b** task', '[c](https://x.com) task'],
    );
  });
}
