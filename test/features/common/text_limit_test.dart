import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/features/common/ui/text_limit.dart';

// Ограничение ввода в символах Unicode (решение 14А plans/m4).
void main() {
  const limit = TextLimit(3);

  TextEditingValue typed(String text) => TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: text.length),
  );

  test('в пределах лимита — без изменений', () {
    expect(limit.formatEditUpdate(typed('ab'), typed('abc')).text, 'abc');
  });

  test('вставка сверх лимита обрезается, курсор в конце', () {
    final out = limit.formatEditUpdate(typed(''), typed('abcdef'));
    expect(out.text, 'abc');
    expect(out.selection.baseOffset, 3);
  });

  test('на пределе ввод в середину не принимается, хвост цел', () {
    const old = TextEditingValue(
      text: 'abc',
      selection: TextSelection.collapsed(offset: 1),
    );
    const next = TextEditingValue(
      text: 'aXbc',
      selection: TextSelection.collapsed(offset: 2),
    );
    expect(limit.formatEditUpdate(old, next), old);
  });

  test('вставка в середину сверх лимита обрезает вставленное', () {
    const old = TextEditingValue(
      text: 'ab',
      selection: TextSelection.collapsed(offset: 1),
    );
    const next = TextEditingValue(
      text: 'aXYZb',
      selection: TextSelection.collapsed(offset: 4),
    );
    final out = limit.formatEditUpdate(old, next);
    expect(out.text, 'aXb');
    expect(out.selection.baseOffset, 2);
  });

  test('текст длиннее лимита (с другого устройства) стирать можно', () {
    final out = limit.formatEditUpdate(typed('abcde'), typed('abcd'));
    expect(out.text, 'abcd');
  });

  test('эмодзи — один символ: три эмодзи помещаются, четвёртое — нет', () {
    expect(limit.formatEditUpdate(typed(''), typed('😀😀😀')).text, '😀😀😀');
    expect(limit.formatEditUpdate(typed(''), typed('😀😀😀😀')).text, '😀😀😀');
  });
}
