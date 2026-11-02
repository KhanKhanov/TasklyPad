import 'package:flutter/widgets.dart';

import '../../../core/clock.dart';
import '../../../nlp/parse_context.dart';
import '../../../nlp/quick_add.dart';
import '../../../nlp/scanner.dart';
import '../../quick_add/logic/spans.dart';
import '../../quick_add/state/edit_range.dart';
import '../../quick_add/state/highlight_text.dart';

/// Поле названия существующей задачи: набранная в нём дата подсвечивается и
/// при сохранении становится сроком (решение 1А конца M3). Клик по
/// подсветке, Backspace после даты и Delete перед ней оставляют её текстом,
/// как в быстром добавлении.
///
/// Даты, которые уже стоят в названии из базы ([reset]), — часть названия,
/// а не новый срок: открыть задачу и закрыть без правки не должно менять
/// срок (в help не описано — допущение О-57).
class TitleDateController extends TextEditingController {
  TitleDateController({required this._clock});

  final AppClock _clock;
  String _lang = 'en';
  bool _smartDates = true;
  List<Span> _dismissed = const [];
  TitleDue? _parsed;

  /// Язык разбора и «Умное распознавание даты» (выключено — даты в названии
  /// не ищутся, help «Turn smart date recognition on or off»); вызывается
  /// при каждой сборке окна.
  void configure({required String lang, required bool smartDates}) {
    final code = ParseContext.languageFor(lang);
    if (code == _lang && smartDates == _smartDates) return;
    final languageChanged = code != _lang;
    _lang = code;
    _smartDates = smartDates;
    // Новый язык нашёл бы в названии даты, которых прежний не видел, и
    // уход из поля переписал бы срок без действия пользователя: все даты в
    // тексте — текст, как у названия из базы.
    if (languageChanged) {
      _dismissed = _datesIn(text);
      _parsed = null;
    } else {
      _parsed = _parse(text);
    }
  }

  /// Дата, набранная в названии; `null` — нет или распознавание выключено.
  TitleDue? get parsed => _parsed;

  /// Название из базы: его даты остаются текстом.
  void reset(String text) {
    _dismissed = _datesIn(text);
    _parsed = null;
    super.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  /// Разобрать заново — перед записью: «завтра», набранное до полуночи,
  /// после неё — уже другой день.
  void refresh() => _parsed = _parse(text);

  /// Клик по подсветке: дата остаётся текстом названия.
  void dismiss(Span span) {
    _dismissed = [..._dismissed, span];
    _parsed = _parse(text);
    notifyListeners();
  }

  @override
  set value(TextEditingValue newValue) {
    final old = value;
    final date = _parsed;
    final deleted = date == null
        ? null
        : dateDismissedByDelete(old, newValue, [date.highlight.span]);
    if (deleted != null) return dismiss(deleted);
    _dismissed = shiftSpans(
      _dismissed,
      old.text,
      newValue.text,
      changed: editRange(old, newValue),
    );
    _parsed = _parse(newValue.text);
    super.value = newValue;
  }

  /// Все даты строки [text] — участки, которые остаются текстом.
  List<Span> _datesIn(String text) {
    final found = <Span>[];
    for (;;) {
      final date = parseTitleDue(text, _context(), dismissed: found);
      if (date == null) return found;
      found.add(date.highlight.span);
    }
  }

  ParseContext _context() => ParseContext(now: _clock.nowWall(), lang: _lang);

  TitleDue? _parse(String text) => _smartDates
      ? parseTitleDue(text, _context(), dismissed: _dismissed)
      : null;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final date = _parsed;
    // Пока IME собирает слово, рисует Flutter: иначе сломалось бы
    // подчёркивание набора.
    if (withComposing && value.isComposingRangeValid || date == null) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    return highlightedTextSpan(context, text, [date.highlight.span], style);
  }
}
