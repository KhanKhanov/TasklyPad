import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/app/theme/app_palette.dart';
import 'package:planner/app/theme/app_themes.dart';
import 'package:planner/features/common/ui/markdown_block.dart';

// Описание с markdown берёт цвета из темы приложения, а не из светлой темы
// Flutter по умолчанию: flutter_markdown_plus ещё на устаревшей
// `package:flutter/material.dart` и нашей темы `material_ui` не видит (О-87).
void main() {
  Future<ThemeData> pump(WidgetTester tester, String text) async {
    final theme = buildThemeData(tasklyTheme.dark, Brightness.dark);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Material(
          child: MarkdownBlock(
            text,
            style: const TextStyle(fontSize: 14, color: Color(0xFFEEEEEE)),
          ),
        ),
      ),
    );
    return theme;
  }

  // Цвет фрагмента с [text] с учётом стилей предков: внешний стиль RichText —
  // от DefaultTextStyle и всегда из нашей темы, заголовок — во вложенном.
  TextStyle? styleOf(WidgetTester tester, String text) {
    final rich = tester.widget<RichText>(
      find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().contains(text),
      ),
    );
    TextStyle? found;
    void visit(InlineSpan span, TextStyle? inherited) {
      final style = inherited?.merge(span.style) ?? span.style;
      if (span is TextSpan) {
        if (span.text == text) found = style;
        for (final child in span.children ?? const <InlineSpan>[]) {
          visit(child, style);
        }
      }
    }

    visit(rich.text, null);
    return found;
  }

  Color? colorOf(WidgetTester tester, String text) =>
      styleOf(tester, text)?.color;

  testWidgets('заголовок #### в тёмной теме → цвет текста темы приложения', (
    tester,
  ) async {
    final theme = await pump(tester, '#### Заголовок');

    expect(colorOf(tester, 'Заголовок'), theme.textTheme.bodyLarge!.color);
  });

  testWidgets('ссылка и ~~зачёркнутое~~ в тёмной теме → линии цветом текста, '
      'не тёмным из светлой темы', (tester) async {
    final theme = await pump(tester, '[сайт](https://example.com) ~~готово~~');
    final accent = theme.extension<AppPalette>()!.accent;

    final link = styleOf(tester, 'сайт')!;
    expect(link.decoration, TextDecoration.underline);
    expect(link.decorationColor, accent);
    final done = styleOf(tester, 'готово')!;
    expect(done.decoration, TextDecoration.lineThrough);
    expect(done.decorationColor, const Color(0xFFEEEEEE));
  });

  testWidgets('линия --- в тёмной теме → цвет разделителя темы приложения', (
    tester,
  ) async {
    final theme = await pump(tester, 'до\n\n---\n\nпосле');

    final line = tester.widget<Container>(
      find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).border is Border,
      ),
    );
    final border = (line.decoration! as BoxDecoration).border! as Border;
    expect(border.top.color, theme.dividerColor);
  });
}
