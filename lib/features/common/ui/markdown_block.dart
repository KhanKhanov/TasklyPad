import 'package:flutter/material.dart';
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
    final code = style.copyWith(
      fontFamily: 'Consolas',
      fontFamilyFallback: const ['Roboto Mono', 'monospace'],
      backgroundColor: palette.raised,
    );
    final sheet = MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
      p: style,
      a: style.copyWith(
        color: palette.accent,
        decoration: TextDecoration.underline,
      ),
      h1: style.copyWith(
        fontSize: (style.fontSize ?? 14) + 6,
        fontWeight: FontWeight.w700,
        color: palette.textPrimary,
      ),
      h2: style.copyWith(
        fontSize: (style.fontSize ?? 14) + 3,
        fontWeight: FontWeight.w700,
        color: palette.textPrimary,
      ),
      h3: style.copyWith(fontWeight: FontWeight.w700),
      code: code,
      codeblockDecoration: BoxDecoration(
        color: palette.raised,
        borderRadius: BorderRadius.circular(4),
      ),
      blockquote: style,
      blockquoteDecoration: BoxDecoration(
        border: Border(left: BorderSide(color: palette.outline, width: 3)),
      ),
      blockquotePadding: const EdgeInsets.only(left: 12),
      listBullet: style,
      del: style.copyWith(decoration: TextDecoration.lineThrough),
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
