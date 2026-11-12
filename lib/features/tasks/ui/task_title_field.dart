import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/app_palette.dart';
import '../../../domain/markdown_text.dart';
import '../../../domain/rules.dart';
import '../../common/ui/markdown_editable.dart';
import '../../common/ui/markdown_inline.dart';
import '../../common/ui/markdown_keys.dart';
import '../../common/ui/text_limit.dart';
import '../../quick_add/ui/highlight_tap_region.dart';
import '../state/title_date_controller.dart';

/// Название в окне задачи: одна строка, как в Todoist, — Enter сохраняет,
/// вставленный перевод строки становится пробелом; длинное название
/// переносится только на экране. Набранная дата подсвечена, клик по
/// подсветке оставляет её текстом ([TitleDateController]). Markdown — по
/// решению 7А: вне поля отрисован, в поле — исходный текст ([MarkdownEditable]),
/// `Ctrl+B` / `Ctrl+I` — [MarkdownKeys].
class TaskTitleField extends StatelessWidget {
  const TaskTitleField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.readOnly,
    this.onHold,
    required this.completed,
    required this.onSubmitted,
  });

  final TitleDateController controller;
  final FocusNode focusNode;
  final bool readOnly;

  /// Поле удерживается окном «Ссылка» ([MarkdownEditable.onHold]).
  final ValueChanged<bool>? onHold;

  /// Выполненная задача — название зачёркнуто.
  final bool completed;
  final VoidCallback onSubmitted;

  static const InputDecoration _decoration = InputDecoration(
    border: InputBorder.none,
    isDense: true,
  );

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final style = TextStyle(
      color: palette.textPrimary,
      fontSize: 18,
      fontWeight: FontWeight.w600,
      decoration: completed ? TextDecoration.lineThrough : null,
    );
    return MarkdownEditable(
      controller: controller,
      focusNode: focusNode,
      readOnly: readOnly,
      onHold: onHold,
      hasMarkup: hasInlineMarkup,
      decoration: _decoration,
      rendered: (text) => MarkdownInline(text, style: style),
      editor: MarkdownKeys(
        controller: controller,
        focusNode: focusNode,
        max: Limits.taskContent,
        enabled: !readOnly,
        child: HighlightTapRegion(
          spans: () => [?controller.parsed?.highlight.span],
          onTap: controller.dismiss,
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            readOnly: readOnly,
            maxLines: null,
            textInputAction: TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.deny(
                RegExp(r'[\r\n]+'),
                replacementString: ' ',
              ),
              const TextLimit(Limits.taskContent),
            ],
            decoration: _decoration,
            style: style,
            onSubmitted: (_) => onSubmitted(),
          ),
        ),
      ),
    );
  }
}
