import 'package:flutter/material.dart';

import '../../../app/theme/app_palette.dart';
import '../../../domain/filter_engine.dart';
import '../../../domain/filter_query.dart';
import '../../../domain/rules.dart';
import '../../../l10n/app_localizations.dart';
import '../../common/ui/text_limit.dart';

/// Текст запроса фильтра с подсвеченным местом ошибки [error]: волнистое
/// подчёркивание цветом опасности (в help подсветки нет — допущение, О-69).
class FilterQueryController extends TextEditingController {
  FilterQueryController({super.text});

  FilterSyntaxError? _error;

  /// Ошибка разбора текущего текста; `null` — запрос разобран.
  FilterSyntaxError? get error => _error;
  set error(FilterSyntaxError? value) {
    if (value == _error) return;
    _error = value;
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final e = _error;
    final composing = withComposing && value.isComposingRangeValid;
    // Пустой участок (ошибка в конце) подчёркивать нечего; набор через IME
    // показывает своё подчёркивание.
    if (e == null || composing || e.start >= e.end || e.end > text.length) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    final danger = AppPalette.of(context).danger;
    return TextSpan(
      style: style,
      children: [
        TextSpan(text: text.substring(0, e.start)),
        TextSpan(
          text: text.substring(e.start, e.end),
          style: TextStyle(
            color: danger,
            decoration: TextDecoration.underline,
            decorationStyle: TextDecorationStyle.wavy,
            decorationColor: danger,
          ),
        ),
        TextSpan(text: text.substring(e.end)),
      ],
    );
  }
}

/// Текст ошибки разбора [error] запроса [query] — под полем запроса и на
/// экране фильтра с запросом, пришедшим с ошибкой с другого устройства.
String filterErrorText(
  AppLocalizations l10n,
  String query,
  FilterSyntaxError error,
) {
  final part = error.end <= query.length && error.start < error.end
      ? query.substring(error.start, error.end).trim()
      : '';
  return switch (error.kind) {
    FilterErrorKind.empty => l10n.filterErrorEmpty,
    FilterErrorKind.unexpected => l10n.filterErrorUnexpected(part),
    FilterErrorKind.unclosed => l10n.filterErrorUnclosed,
    FilterErrorKind.commaInGroup => l10n.filterErrorCommaInGroup,
    FilterErrorKind.unknown => l10n.filterErrorUnknown(part),
    FilterErrorKind.badDate => l10n.filterErrorBadDate(part),
    FilterErrorKind.unsupported => l10n.filterErrorUnsupported(part),
  };
}

/// Поле запроса окна фильтра: до [Limits.filterQuery] символов (О-80),
/// ошибка разбора — подсветкой и текстом под полем, иначе — предпросмотр
/// [lists]: сколько задач найдено в каждом списке (живой предпросмотр в
/// help не описан — допущение, О-69).
class FilterQueryField extends StatelessWidget {
  const FilterQueryField({
    super.key,
    required this.controller,
    required this.lists,
    required this.onChanged,
    required this.onSubmitted,
  });

  final FilterQueryController controller;

  /// Списки разобранного запроса; `null` — запрос пуст или с ошибкой.
  final List<FilterList>? lists;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final error = controller.error;
    final lists = this.lists;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          maxLength: Limits.filterQuery,
          inputFormatters: const [TextLimit(Limits.filterQuery)],
          // Длинный запрос переносится, Enter — сохранить, а не новая строка:
          // перевод строки в запросе ничего не значит.
          minLines: 1,
          maxLines: 4,
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: l10n.fieldQuery,
            errorText: error == null || controller.text.trim().isEmpty
                ? null
                : filterErrorText(l10n, controller.text, error),
            errorMaxLines: 3,
          ),
          onChanged: onChanged,
          onSubmitted: (_) => onSubmitted(),
        ),
        if (lists != null)
          for (final list in lists)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                lists.length == 1
                    ? l10n.filterPreview(list.tasks.length)
                    : '${list.title} — ${l10n.filterPreview(list.tasks.length)}',
                key: const ValueKey('filterPreview'),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: palette.textSecondary, fontSize: 13),
              ),
            ),
      ],
    );
  }
}
