import 'package:flutter/material.dart';

import '../../../app/theme/app_palette.dart';
import '../../../domain/markdown_text.dart';
import '../../../domain/rules.dart';
import '../../../l10n/app_localizations.dart';
import '../../common/ui/markdown_block.dart';
import '../../common/ui/markdown_editable.dart';
import '../../common/ui/markdown_keys.dart';
import '../../common/ui/text_limit.dart';

/// Описание в окне задачи: несколько строк; markdown — по решению 7А плана
/// M4: вне поля отрисован ([MarkdownBlock]), в поле — исходный текст,
/// `Ctrl+B` / `Ctrl+I` — [MarkdownKeys]. Сохраняет окно при уходе фокуса.
class TaskDescriptionField extends StatelessWidget {
  const TaskDescriptionField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.readOnly,
    this.onHold,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool readOnly;

  /// Поле удерживается окном «Ссылка» ([MarkdownEditable.onHold]).
  final ValueChanged<bool>? onHold;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final decoration = InputDecoration(
      hintText: AppLocalizations.of(context).descriptionHint,
      border: InputBorder.none,
      isDense: true,
    );
    final style = TextStyle(color: palette.textSecondary, fontSize: 14);
    return MarkdownEditable(
      controller: controller,
      focusNode: focusNode,
      readOnly: readOnly,
      onHold: onHold,
      hasMarkup: hasDescriptionMarkup,
      decoration: decoration,
      rendered: (text) => MarkdownBlock(text, style: style),
      editor: MarkdownKeys(
        controller: controller,
        focusNode: focusNode,
        blocks: true,
        max: Limits.description,
        enabled: !readOnly,
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          readOnly: readOnly,
          maxLines: null,
          inputFormatters: const [TextLimit(Limits.description)],
          decoration: decoration,
          style: style,
        ),
      ),
    );
  }
}
