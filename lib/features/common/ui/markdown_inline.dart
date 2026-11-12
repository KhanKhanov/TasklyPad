import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown/markdown.dart' as md;

import '../../../app/platform_providers.dart';
import '../../../app/theme/app_palette.dart';
import '../../../domain/markdown_text.dart';
import '../../../l10n/app_localizations.dart';
import '../../../platform/link_opener.dart';
import 'app_toast.dart';

/// Открыть ссылку [href] из текста задачи или проекта; схема не из
/// [openableLink] или открыть не удалось — тост «Не удалось открыть ссылку».
Future<void> openLink(BuildContext context, String? href) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final text = AppLocalizations.of(context).linkOpenFailed;
  final uri = openableLink(href);
  final opener = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(linkOpenerProvider);
  final ok = uri != null && await opener.open(uri);
  if (!ok && messenger != null && messenger.mounted) {
    showAppToast(messenger, text: text);
  }
}

/// Строка с markdown, отрисованная (help «Format text in a Todoist task»):
/// жирный, курсив, код, зачёркнутый, ссылка. Разбор — [parseInlineMarkdown];
/// символы разметки не видны. Нажатие на ссылку открывает её ([openLink]),
/// а не то, что под строкой (задачу, редактор).
class MarkdownInline extends StatefulWidget {
  const MarkdownInline(
    this.text, {
    super.key,
    required this.style,
    this.maxLines,
    this.overflow,
  });

  final String text;
  final TextStyle style;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  State<MarkdownInline> createState() => _MarkdownInlineState();
}

class _MarkdownInlineState extends State<MarkdownInline> {
  late List<md.Node> _nodes = parseInlineMarkdown(widget.text);

  /// Распознаватели нажатий ссылок — по одному на ссылку, переиспользуются
  /// между перестройками и освобождаются в [dispose].
  final List<TapGestureRecognizer> _links = [];
  int _used = 0;

  @override
  void didUpdateWidget(MarkdownInline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _nodes = parseInlineMarkdown(widget.text);
    }
  }

  @override
  void dispose() {
    for (final r in _links) {
      r.dispose();
    }
    super.dispose();
  }

  TapGestureRecognizer _link(String? href) {
    if (_used == _links.length) _links.add(TapGestureRecognizer());
    return _links[_used++]..onTap = () => openLink(context, href);
  }

  @override
  Widget build(BuildContext context) {
    _used = 0;
    final palette = AppPalette.of(context);
    final spans = _spans(_nodes, widget.style, palette);
    // Лишние распознаватели (ссылок стало меньше) больше не нужны.
    while (_links.length > _used) {
      _links.removeLast().dispose();
    }
    return Text.rich(
      TextSpan(style: widget.style, children: spans),
      maxLines: widget.maxLines,
      overflow: widget.overflow,
    );
  }

  /// Куски текста дерева [nodes]. Нажатие ссылки [link] висит на каждом
  /// листе внутри неё: Flutter отдаёт нажатие самому глубокому куску под
  /// курсором, и распознаватель на внешнем куске ссылки не сработал бы.
  List<InlineSpan> _spans(
    List<md.Node> nodes,
    TextStyle style,
    AppPalette palette, [
    TapGestureRecognizer? link,
  ]) {
    TextSpan leaf(String text) => TextSpan(
      text: text,
      style: style,
      recognizer: link,
      mouseCursor: link == null ? null : SystemMouseCursors.click,
    );
    return [
      for (final node in nodes)
        switch (node) {
          md.Text(:final text) => leaf(text),
          md.Element(tag: 'img', :final attributes) => leaf(
            attributes['alt'] ?? '',
          ),
          md.Element(tag: 'br') => leaf(' '),
          md.Element(tag: 'a', :final attributes, :final children) => TextSpan(
            children: _spans(
              children ?? const [],
              _decorated(
                style,
                TextDecoration.underline,
              ).copyWith(color: palette.accent),
              palette,
              _link(attributes['href']),
            ),
          ),
          md.Element(:final tag, :final children) => TextSpan(
            children: _spans(
              children ?? const [],
              _styleOf(tag, style, palette),
              palette,
              link,
            ),
          ),
          _ => leaf(node.textContent),
        },
    ];
  }

  static TextStyle _styleOf(String tag, TextStyle style, AppPalette palette) =>
      switch (tag) {
        'strong' => style.copyWith(
          fontWeight: (style.fontWeight ?? FontWeight.normal).value >= 600
              ? FontWeight.w800
              : FontWeight.w700,
        ),
        'em' => style.copyWith(fontStyle: FontStyle.italic),
        'del' => _decorated(style, TextDecoration.lineThrough),
        'code' => style.copyWith(
          fontFamily: 'Consolas',
          fontFamilyFallback: const ['Roboto Mono', 'monospace'],
          backgroundColor: palette.raised,
        ),
        _ => style,
      };

  /// [style] с ещё одной линией: зачёркнутая выполненная задача со ссылкой
  /// остаётся зачёркнутой.
  static TextStyle _decorated(TextStyle style, TextDecoration line) => style
      .copyWith(decoration: TextDecoration.combine([?style.decoration, line]));
}
