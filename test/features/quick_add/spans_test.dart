import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/features/quick_add/logic/spans.dart';
import 'package:planner/features/quick_add/logic/suggestions.dart';
import 'package:planner/features/quick_add/state/edit_range.dart';
import 'package:planner/nlp/scanner.dart';

// Участки строки при правке и токен под курсором — чистые функции.
void main() {
  group('shiftSpans — отменённые участки едут с текстом', () {
    const text = 'Meet tomorrow team';
    const span = Span(5, 13); // tomorrow

    test('набор перед участком → участок сдвинут', () {
      expect(shiftSpans([span], text, 'Big $text'), [const Span(9, 17)]);
    });

    test('набор после участка → участок на месте', () {
      expect(shiftSpans([span], text, '$text now'), [span]);
    });

    test('набор вплотную к концу участка → участок на месте', () {
      expect(shiftSpans([span], text, 'Meet tomorrow, team'), [span]);
    });

    test('правка внутри участка → участок пропадает', () {
      expect(shiftSpans([span], text, 'Meet tomorow team'), isEmpty);
    });

    test('удаление текста перед участком → сдвиг назад', () {
      expect(shiftSpans([span], text, 'M tomorrow team'), [const Span(2, 10)]);
    });
  });

  group('editRange — место правки по курсору', () {
    TextEditingValue v(String text, int cursor) => TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: cursor),
    );

    test('«t» перед отменённым «tomorrow» — участок сдвинут, а не потерян', () {
      final before = v('Meet tomorrow', 5);
      final after = v('Meet ttomorrow', 6);
      final changed = editRange(before, after);
      expect(changed, const Span(5, 5));
      expect(
        shiftSpans(
          [const Span(5, 13)],
          before.text,
          after.text,
          changed: changed,
        ),
        [const Span(6, 14)],
      );
      // Без курсора место правки неоднозначно, и участок пропадает.
      expect(shiftSpans([const Span(5, 13)], before.text, after.text), isEmpty);
    });

    test('Backspace и Delete', () {
      expect(editRange(v('abcd', 2), v('acd', 1)), const Span(1, 2));
      expect(editRange(v('abcd', 2), v('abd', 2)), const Span(2, 3));
    });

    test('замена выделения', () {
      final before = TextEditingValue(
        text: 'abcd',
        selection: const TextSelection(baseOffset: 1, extentOffset: 3),
      );
      expect(editRange(before, v('aXd', 2)), const Span(1, 3));
    });
  });

  group('removeSpans — выбор чипом убирает участок', () {
    test('в начале — вместе с пробелом после', () {
      final r = removeSpans('tomorrow buy milk', [const Span(0, 8)]);
      expect(r.text, 'buy milk');
    });

    test('в конце — вместе с пробелом перед', () {
      final r = removeSpans('buy milk tomorrow', [const Span(9, 17)]);
      expect(r.text, 'buy milk');
    });

    test('два участка; отменённый участок после них сдвигается', () {
      // «buy p1 milk @home friday»: убрать p1 и @home, friday — отменён.
      const text = 'buy p1 milk @home friday';
      final r = removeSpans(
        text,
        [const Span(4, 6), const Span(12, 17)],
        dismissed: [const Span(18, 24)],
      );
      expect(r.text, 'buy milk friday');
      expect(r.dismissed, [const Span(9, 15)]);
      expect(r.text.substring(9, 15), 'friday');
    });
  });

  group('tokenQueryAt — что набирается под курсором', () {
    test('#Wo| → проект «Wo»', () {
      final q = tokenQueryAt('Call #Wo', 8)!;
      expect(
        (q.kind, q.start, q.end, q.query),
        (TokenKind.project, 5, 8, 'Wo'),
      );
    });

    test('% и @ — метка, знак сохраняется', () {
      expect(tokenQueryAt('x %ho', 5)!.sign, '%');
      expect(tokenQueryAt('x @ho', 5)!.kind, TokenKind.label);
    });

    test('после токена — пробел или конец; знак внутри слова — не токен', () {
      expect(tokenQueryAt('Call #Work now', 8), isNull); // курсор внутри
      expect(tokenQueryAt('mail@home', 9), isNull);
      expect(tokenQueryAt('a // note', 4), isNull); // описание, не раздел
    });

    test('один знак без имени — пустой запрос (весь список)', () {
      expect(tokenQueryAt('Call #', 6)!.query, '');
    });
  });
}
