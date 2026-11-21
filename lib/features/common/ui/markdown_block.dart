import 'package:material_ui/material_ui.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../../app/theme/app_palette.dart';
import '../../../domain/markdown_text.dart';
import 'markdown_inline.dart';

/// Описание задачи или проекта с markdown, отрисованное (help «Format text in
/// a Todoist task»): всё строчное, что в названии, и заголовки, цитаты, блоки
/// кода, списки. Переводы строк сохраняются, как в поле ввода. Картинки не
/// загружаются — вместо них подпись: приложение ходит в сеть только для
/// синхронизации по LAN (CLAUDE.md).
class MarkdownBlock extends StatelessWidget {
  const MarkdownBlock(this.text, {super.key, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    // Цвет линий (подчёркивание ссылки, зачёркивание) — цвет текста: иначе
    // он остаётся от светлой темы по умолчанию (см. ниже), почти чёрный.
    final base = style.copyWith(decorationColor: style.color);
    final code = base.copyWith(
      fontFamily: 'Consolas',
      fontFamilyFallback: const ['Roboto Mono', 'monospace'],
      backgroundColor: palette.raised,
    );
    final theme = Theme.of(context);
    // Только наши поля: MarkdownBody достраивает остальные из темы
    // устаревшей `package:flutter/material.dart` — нашей темы `material_ui`
    // она не видит (светлая тема Flutter по умолчанию), поэтому всё, что
    // зависит от темы и встречается в описании, задано здесь (О-87).
    final sheet = MarkdownStyleSheet(
      p: base,
      a: base.copyWith(
        color: palette.accent,
        decorationColor: palette.accent,
        decoration: TextDecoration.underline,
      ),
      h1: base.copyWith(
        fontSize: (style.fontSize ?? 14) + 6,
        fontWeight: FontWeight.w700,
        color: palette.textPrimary,
        decorationColor: palette.textPrimary,
      ),
      h2: base.copyWith(
        fontSize: (style.fontSize ?? 14) + 3,
        fontWeight: FontWeight.w700,
        color: palette.textPrimary,
        decorationColor: palette.textPrimary,
      ),
      h3: base.copyWith(fontWeight: FontWeight.w700),
      h4: theme.textTheme.bodyLarge,
      h5: theme.textTheme.bodyLarge,
      h6: theme.textTheme.bodyLarge,
      horizontalRuleDecoration: BoxDecoration(
        border: Border(top: BorderSide(width: 5, color: theme.dividerColor)),
      ),
      code: code,
      codeblockDecoration: BoxDecoration(
        color: palette.raised,
        borderRadius: BorderRadius.circular(4),
      ),
      blockquote: base,
      blockquoteDecoration: BoxDecoration(
        border: Border(left: BorderSide(color: palette.outline, width: 3)),
      ),
      blockquotePadding: const EdgeInsets.only(left: 12),
      listBullet: base,
      del: base.copyWith(decoration: TextDecoration.lineThrough),
    );
    return MarkdownBody(
      data: text,
      extensionSet: descriptionSyntax,
      softLineBreak: true,
      styleSheet: sheet,
      onTapLink: (_, href, _) => openLink(context, href),
      imageBuilder: (_, _, alt) => Text(alt ?? '', style: style),
    );
  }
}
