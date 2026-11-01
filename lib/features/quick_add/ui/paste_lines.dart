import 'package:flutter/services.dart';

/// Вставлены строки [lines] (две и больше). [joined] — поле, если вставить
/// их одной задачей: строки через пробел.
typedef PasteLinesCallback = void Function(
  List<String> lines,
  TextEditingValue joined,
);

/// Вставка нескольких строк в поле названия (help «Add or manage multiple
/// tasks»): поле не меняется, а [onLines] спрашивает «Добавить X задач?».
/// Перенос, набранный или вставленный одной строкой, становится пробелом:
/// название задачи — одна строка.
class PasteLinesFormatter extends TextInputFormatter {
  PasteLinesFormatter(this.onLines);

  final PasteLinesCallback onLines;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!newValue.text.contains('\n') && !newValue.text.contains('\r')) {
      return newValue;
    }
    final joined = _flatten(newValue);
    final inserted = _inserted(oldValue.text, newValue.text);
    final lines = [
      for (final line in inserted.split(RegExp(r'\r\n|\r|\n')))
        if (line.trim().isNotEmpty) line.trim(),
    ];
    if (lines.length < 2) return joined;
    // Окно — после того, как поле закончит обработку ввода.
    Future<void>.microtask(() => onLines(lines, joined));
    return oldValue;
  }

  /// Переносы → пробел; курсор остаётся после того же текста.
  static TextEditingValue _flatten(TextEditingValue v) {
    String flat(String s) => s
        .replaceAll(RegExp(r'\r\n|\r|\n'), ' ')
        .replaceAll(RegExp(' {2,}'), ' ');
    final cursor = v.selection.isValid
        ? v.selection.extentOffset.clamp(0, v.text.length)
        : v.text.length;
    final before = flat(v.text.substring(0, cursor));
    final text = flat(v.text);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(
        offset: before.length.clamp(0, text.length),
      ),
    );
  }

  /// Вставленный кусок: между общим началом и общим концом строк.
  static String _inserted(String before, String after) {
    var prefix = 0;
    final shortest = before.length < after.length
        ? before.length
        : after.length;
    while (prefix < shortest && before[prefix] == after[prefix]) {
      prefix++;
    }
    var suffix = 0;
    while (suffix < shortest - prefix &&
        before[before.length - 1 - suffix] ==
            after[after.length - 1 - suffix]) {
      suffix++;
    }
    return after.substring(prefix, after.length - suffix);
  }
}
