import 'package:flutter/services.dart';

import '../../../domain/rules.dart';

/// Ограничение ввода по [Limits.length] — в символах Unicode, как считают
/// команды (решение 14А plans/m4). Встроенный `maxLength` поля считает
/// графемы: семья-эмодзи для него один символ, а для команды — несколько;
/// этот форматтер строже, поэтому принятое полем команда не отклонит.
///
/// Как у `maxLength`: на пределе ввод без выделения не принимается; вставка
/// сверх лимита обрезается — но обрезается вставленное, а не конец текста.
/// Стирать можно всегда, даже текст длиннее лимита (пришёл с другого
/// устройства).
class TextLimit extends TextInputFormatter {
  const TextLimit(this.max);

  final int max;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final length = Limits.length(newValue.text);
    if (length <= max || length < Limits.length(oldValue.text)) {
      return newValue;
    }
    if (Limits.length(oldValue.text) >= max && oldValue.selection.isCollapsed) {
      return oldValue;
    }
    // Вставленное стоит перед курсором: лишние символы снимаются оттуда.
    final cursor = newValue.selection.end.clamp(0, newValue.text.length);
    final before = newValue.text.substring(0, cursor).runes.toList();
    final after = newValue.text.substring(cursor);
    final keep = before.length - (length - max);
    if (keep < 0) {
      final text = Limits.clip(newValue.text, max);
      return TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
    final head = String.fromCharCodes(before.take(keep));
    return TextEditingValue(
      text: head + after,
      selection: TextSelection.collapsed(offset: head.length),
    );
  }
}
