import 'package:flutter/widgets.dart';

import '../../../app/theme/app_palette.dart';
import '../../../nlp/scanner.dart';

/// Текст поля с подсвеченными участками [spans] (по порядку, без
/// перекрытий): цвет акцента на его бледном фоне, как в быстром добавлении
/// Todoist. Участок за концом текста или перекрывающий предыдущий
/// пропускается.
TextSpan highlightedTextSpan(
  BuildContext context,
  String text,
  List<Span> spans,
  TextStyle? style,
) {
  final palette = AppPalette.of(context);
  final marked = style?.merge(
    TextStyle(
      color: palette.accent,
      backgroundColor: palette.accent.withValues(alpha: 0.14),
    ),
  );
  final children = <TextSpan>[];
  var at = 0;
  for (final s in spans) {
    if (s.start < at || s.end > text.length) continue;
    if (s.start > at) children.add(TextSpan(text: text.substring(at, s.start)));
    children.add(TextSpan(text: text.substring(s.start, s.end), style: marked));
    at = s.end;
  }
  if (at < text.length) children.add(TextSpan(text: text.substring(at)));
  return TextSpan(style: style, children: children);
}
