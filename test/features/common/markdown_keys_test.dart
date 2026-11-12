import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/app/theme/app_themes.dart';
import 'package:planner/features/common/logic/markdown_edits.dart';
import 'package:planner/features/common/ui/markdown_keys.dart';
import 'package:planner/features/common/ui/markdown_toolbar.dart';
import 'package:planner/l10n/app_localizations.dart';

// `Ctrl+B` / `Ctrl+I` в поле с markdown (решение 7А плана M4; в help клавиши
// не найдены — допущение О-69).
void main() {
  TextEditingValue select(String text, int start, int end) => TextEditingValue(
    text: text,
    selection: TextSelection(baseOffset: start, extentOffset: end),
  );

  test('выделение оборачивается, выделение остаётся на слове', () {
    final out = toggleMarker(select('Buy milk now', 4, 8), '**');
    expect(out.text, 'Buy **milk** now');
    expect(out.selection, const TextSelection(baseOffset: 6, extentOffset: 10));
  });

  test('повторно — снимает: знаки вокруг выделения', () {
    final out = toggleMarker(select('Buy **milk** now', 6, 10), '**');
    expect(out.text, 'Buy milk now');
    expect(out.selection, const TextSelection(baseOffset: 4, extentOffset: 8));
  });

  test('знаки по краям выделенного — снимаются', () {
    final out = toggleMarker(select('Buy *milk* now', 4, 10), '*');
    expect(out.text, 'Buy milk now');
  });

  test('курсив не снимается с половины жирного — оборачивает', () {
    expect(toggleMarker(select('**milk**', 2, 6), '*').text, '***milk***');
    expect(toggleMarker(select('**milk**', 0, 8), '*').text, '***milk***');
  });

  test('без выделения — пара знаков, курсор между ними', () {
    final out = toggleMarker(
      const TextEditingValue(
        text: 'ab',
        selection: TextSelection.collapsed(offset: 1),
      ),
      '**',
    );
    expect(out.text, 'a****b');
    expect(out.selection, const TextSelection.collapsed(offset: 3));
  });

  testWidgets(
    'Ctrl+B и Ctrl+I в поле, повтор снимает; сверх лимита текст не меняется',
    (tester) async {
      final controller = TextEditingController(text: 'abc');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: MarkdownKeys(
              controller: controller,
              max: 9,
              child: TextField(controller: controller, autofocus: true),
            ),
          ),
        ),
      );
      await tester.pump();
      controller.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 3,
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      expect(controller.text, '**abc**');

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      expect(controller.text, '***abc***');

      // Повторное Ctrl+B на жирном слове снимает жирный.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      expect(controller.text, '*abc*');

      // 9 символов — предел: 8 + пара знаков не помещается.
      controller.value = const TextEditingValue(
        text: 'abcdefgh',
        selection: TextSelection(baseOffset: 0, extentOffset: 3),
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      expect(controller.text, 'abcdefgh');
    },
  );

  test('цитата: у каждой строки выделения, повторно — снимается', () {
    final on = quoteToggle(select('a\nbc\nd', 2, 4))!
        .apply(select('a\nbc\nd', 2, 4));
    expect(on.text, 'a\n> bc\nd');
    final two = select('ab\ncd', 0, 5);
    final quoted = quoteToggle(two)!.apply(two);
    expect(quoted.text, '> ab\n> cd');
    expect(quoteToggle(quoted)!.apply(quoted).text, 'ab\ncd');
  });

  test('ссылка: выделение — текст ссылки; в ссылке — смена адреса и '
      'снятие, текст остаётся', () {
    final v = select('Read docs now', 5, 9);
    final linked = linkChange(v, 'https://x.com')!.apply(v);
    expect(linked.text, 'Read [docs](https://x.com) now');
    expect(
      linked.selection,
      const TextSelection(baseOffset: 6, extentOffset: 10),
    );

    final link = linkAt(linked.text, linked.selection)!;
    expect(link.url, 'https://x.com');
    final moved = linkChange(linked, 'https://y.org')!.apply(linked);
    expect(moved.text, 'Read [docs](https://y.org) now');
    expect(unlinkChange(link).apply(linked).text, 'Read docs now');
    expect(
      linkAt('Read docs', const TextSelection.collapsed(offset: 2)),
      isNull,
    );
  });

  test('крайние случаи правок (ревью M4.12)', () {
    // Цитата: выделение до конца строки вместе с `\n` — следующая не
    // цитируется.
    final lines = select('ab\ncd\nef', 0, 3);
    expect(quoteToggle(lines)!.apply(lines).text, '> ab\ncd\nef');
    // Курсив с жирного курсива.
    expect(toggleMarker(select('***a***', 3, 4), '*').text, '**a**');
    // Ссылка поверх части другой ссылки, через `]` или перевод строки — нет.
    expect(linkChange(select('a [b](x) c', 0, 4), 'y'), isNull);
    expect(linkChange(select('a]b', 0, 3), 'y'), isNull);
    expect(linkChange(select('a\nb', 0, 3), 'y'), isNull);
    // Адрес с парными скобками — целиком.
    const wiki = '[docs](https://en.wikipedia.org/wiki/Foo_(bar)) x';
    final link = linkAt(wiki, const TextSelection.collapsed(offset: 2))!;
    expect(link.url, 'https://en.wikipedia.org/wiki/Foo_(bar)');
    expect(unlinkChange(link).apply(select(wiki, 1, 5)).text, 'docs x');
  });

  group('панель форматирования', () {
    Future<(TextEditingController, FocusNode)> pump(
      WidgetTester tester, {
      bool blocks = false,
    }) async {
      final controller = TextEditingController(text: 'Buy milk now');
      final focus = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          theme: buildThemeData(tasklyTheme.light, Brightness.light),
          home: Material(
            child: Padding(
              padding: const EdgeInsets.only(top: 100),
              child: MarkdownKeys(
                controller: controller,
                focusNode: focus,
                blocks: blocks,
                // Многострочное, как поля приложения: однострочное поле
                // Flutter на компьютере выделяет всё при получении фокуса.
                child: TextField(
                  controller: controller,
                  focusNode: focus,
                  maxLines: null,
                ),
              ),
            ),
          ),
        ),
      );
      focus.requestFocus();
      await tester.pump();
      return (controller, focus);
    }

    testWidgets('мышь над кнопкой панели — подсказка без ошибок (ручная '
        'проверка M4.12: «paint transform cannot be reliably computed»)', (
      tester,
    ) async {
      final (controller, _) = await pump(tester);
      controller.selection = const TextSelection(
        baseOffset: 4,
        extentOffset: 8,
      );
      await tester.pumpAndSettle();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      final bold = tester.getCenter(find.byTooltip('Bold'));
      await mouse.moveTo(bold);
      await tester.pump();
      await mouse.moveTo(bold + const Offset(3, 2));
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
      expect(find.text('Bold'), findsOneWidget);
      await mouse.moveTo(tester.getCenter(find.byTooltip('Italic')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

    testWidgets('видна при выделении на компьютере, кнопки ставят разметку '
        'и не забирают фокус', (tester) async {
      final (controller, focus) = await pump(tester);
      expect(find.byTooltip('Bold'), findsNothing);
      controller.selection = const TextSelection(
        baseOffset: 4,
        extentOffset: 8,
      );
      await tester.pump();
      expect(find.byTooltip('Bold'), findsOneWidget);
      expect(find.byTooltip('Quote'), findsNothing);

      await tester.tap(find.byTooltip('Strikethrough'));
      await tester.pump();
      expect(controller.text, 'Buy ~~milk~~ now');
      expect(focus.hasFocus, isTrue);
      await tester.tap(find.byTooltip('Code'));
      await tester.pump();
      expect(controller.text, 'Buy ~~`milk`~~ now');
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

    testWidgets('«Ссылка»: окно с адресом, «Save» — ссылка; снова — корзина '
        'убирает ссылку', (tester) async {
      final (controller, focus) = await pump(tester);
      controller.selection = const TextSelection(
        baseOffset: 4,
        extentOffset: 8,
      );
      await tester.pump();
      await tester.tap(find.byTooltip('Link'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Address'),
        'https://milk.example',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(controller.text, 'Buy [milk](https://milk.example) now');
      expect(focus.hasFocus, isTrue);

      await tester.tap(find.byTooltip('Link'));
      await tester.pumpAndSettle();
      expect(find.text('https://milk.example'), findsOneWidget);
      await tester.tap(find.byTooltip('Remove link'));
      await tester.pumpAndSettle();
      expect(controller.text, 'Buy milk now');
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

    testWidgets('в описании есть «Цитата»', (tester) async {
      final (controller, _) = await pump(tester, blocks: true);
      controller.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 3,
      );
      await tester.pump();
      expect(find.byTooltip('Quote'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

    testWidgets('скобки в адресе из окна кодируются — ссылка не рвётся', (
      tester,
    ) async {
      final (controller, _) = await pump(tester);
      controller.selection = const TextSelection(
        baseOffset: 4,
        extentOffset: 8,
      );
      await tester.pump();
      await tester.tap(find.byTooltip('Link'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Address'),
        'https://x.org/a)b c',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(controller.text, 'Buy [milk](https://x.org/a%29b%20c) now');
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

    testWidgets('панель — над выделением, и на второй строке ниже, чем на '
        'первой', (tester) async {
      final (controller, _) = await pump(tester);
      controller.text = 'first line\nsecond line';
      controller.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 5,
      );
      await tester.pumpAndSettle();
      final first = tester.getBottomLeft(find.byType(MarkdownToolbar)).dy;
      controller.selection = const TextSelection(
        baseOffset: 11,
        extentOffset: 17,
      );
      await tester.pumpAndSettle();
      final second = tester.getBottomLeft(find.byType(MarkdownToolbar)).dy;
      expect(second, greaterThan(first));
      expect(
        first,
        lessThanOrEqualTo(tester.getTopLeft(find.byType(TextField)).dy + 8),
      );
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

    testWidgets('поле только для просмотра: фокус без ошибок, панели нет', (
      tester,
    ) async {
      final controller = TextEditingController(text: 'Read only');
      final focus = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: MarkdownKeys(
              controller: controller,
              focusNode: focus,
              enabled: false,
              child: TextField(
                controller: controller,
                focusNode: focus,
                readOnly: true,
                maxLines: null,
              ),
            ),
          ),
        ),
      );
      focus.requestFocus();
      await tester.pump();
      focus.unfocus();
      await tester.pump();
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

    testWidgets('на Android панели нет (в Todoist — тоже)', (tester) async {
      final (controller, _) = await pump(tester);
      controller.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 3,
      );
      await tester.pump();
      expect(find.byTooltip('Bold'), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });
}
