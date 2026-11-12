import 'package:flutter/material.dart';

import '../../../app/theme/app_palette.dart';
import '../../../l10n/app_localizations.dart';

/// Кнопки панели форматирования (help «Format text in a Todoist task»: на
/// компьютере — выделить текст и выбрать пункт меню редактора).
enum MarkdownFormat { bold, italic, strikethrough, code, link, quote }

/// Панель форматирования над выделением: «Жирный», «Курсив»,
/// «Зачёркнутый», «Код», «Ссылка», в описании — ещё «Цитата» ([blocks]).
/// Кнопки не забирают фокус у поля и нажатие по панели не считается
/// нажатием мимо поля — выделение остаётся.
class MarkdownToolbar extends StatelessWidget {
  const MarkdownToolbar({
    super.key,
    required this.onPressed,
    this.blocks = false,
  });

  final ValueChanged<MarkdownFormat> onPressed;
  final bool blocks;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    Widget button(MarkdownFormat format, IconData icon, String tooltip) =>
        IconButton(
          tooltip: tooltip,
          iconSize: 18,
          visualDensity: VisualDensity.compact,
          icon: Icon(icon, color: palette.textPrimary),
          onPressed: () => onPressed(format),
        );
    return TextFieldTapRegion(
      child: ExcludeFocus(
        child: Material(
          color: palette.raised,
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                button(MarkdownFormat.bold, Icons.format_bold, l10n.formatBold),
                button(
                  MarkdownFormat.italic,
                  Icons.format_italic,
                  l10n.formatItalic,
                ),
                button(
                  MarkdownFormat.strikethrough,
                  Icons.strikethrough_s,
                  l10n.formatStrikethrough,
                ),
                button(MarkdownFormat.code, Icons.code, l10n.formatCode),
                button(MarkdownFormat.link, Icons.link, l10n.formatLink),
                if (blocks)
                  button(
                    MarkdownFormat.quote,
                    Icons.format_quote,
                    l10n.formatQuote,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
