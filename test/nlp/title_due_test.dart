import 'package:flutter_test/flutter_test.dart';
import 'package:planner/domain/models.dart';
import 'package:planner/nlp/parse_context.dart';
import 'package:planner/nlp/quick_add.dart';
import 'package:planner/nlp/scanner.dart';

// Дата в названии существующей задачи (решение 1А конца M3): только срок,
// прочие токены — текст. Пт 23.10.2026 09:00.
void main() {
  final now = DateTime.utc(2026, 10, 23, 9);
  TitleDue? parse(String text, {String lang = 'ru', List<Span>? dismissed}) =>
      parseTitleDue(
        text,
        ParseContext(now: now, lang: lang),
        dismissed: dismissed ?? const [],
      );

  test('дата уходит из названия и становится сроком с текстом и языком', () {
    final d = parse('Позвонить маме завтра в 10')!;
    expect(d.title, 'Позвонить маме');
    expect(
      d.due,
      const Due(
        date: '2026-10-24',
        time: '10:00',
        string: 'завтра в 10',
        lang: 'ru',
      ),
    );
    expect((d.highlight.start, d.highlight.end), (15, 26));
  });

  test('прочие токены остаются текстом, дата внутри них не ищется', () {
    final d = parse('p1 #Работа отчёт @дом пятница')!;
    expect(d.title, 'p1 #Работа отчёт @дом');
    expect(d.due!.date, '2026-10-30');
    expect(parse('купить #завтра'), isNull);
    expect(parse('созвон {завтра}'), isNull, reason: 'дедлайн — не срок');
  });

  test('повторение — правило с первым вхождением; «без срока» — noDate', () {
    final d = parse('Планёрка every mon', lang: 'en')!;
    expect(d.title, 'Планёрка');
    expect(d.due!.rule!.rrule, ['FREQ=WEEKLY;BYDAY=MO']);
    expect(d.due!.date, '2026-10-26');
    final none = parse('Отчёт без срока')!;
    expect((none.title, none.noDate, none.due), ('Отчёт', true, null));
  });

  test('отрезок времени — длительность, а не дата; отменённая дата — '
      'текст, следующая разбирается', () {
    expect(parse('Встреча 9:30-10:00'), isNull);
    final first = parse('завтра или пятница')!;
    expect(first.due!.date, '2026-10-24');
    final next = parse(
      'завтра или пятница',
      dismissed: [first.highlight.span],
    )!;
    expect((next.title, next.due!.date), ('завтра или', '2026-10-30'));
  });
}
