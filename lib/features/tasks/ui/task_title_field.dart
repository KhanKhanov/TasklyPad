import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/app_palette.dart';
import '../../quick_add/ui/highlight_tap_region.dart';
import '../state/title_date_controller.dart';
import '../../common/ui/text_limit.dart';
import '../../../domain/rules.dart';

/// Название в окне задачи: одна строка, как в Todoist, — Enter сохраняет,
/// вставленный перевод строки становится пробелом; длинное название
/// переносится только на экране. Набранная дата подсвечена, клик по
/// подсветке оставляет её текстом ([TitleDateController]).
class TaskTitleField extends StatelessWidget {
  const TaskTitleField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.readOnly,
    required this.completed,
    required this.onSubmitted,
  });

  final TitleDateController controller;
  final FocusNode focusNode;
  final bool readOnly;

  /// Выполненная задача — название зачёркнуто.
  final bool completed;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return HighlightTapRegion(
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
        decoration: const InputDecoration(
          border: InputBorder.none,
          isDense: true,
        ),
        style: TextStyle(
          color: palette.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          decoration: completed ? TextDecoration.lineThrough : null,
        ),
        onSubmitted: (_) => onSubmitted(),
      ),
    );
  }
}
