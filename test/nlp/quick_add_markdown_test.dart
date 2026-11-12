import 'package:flutter_test/flutter_test.dart';
import 'package:planner/nlp/parse_context.dart';
import 'package:planner/nlp/quick_add.dart';

// Токены быстрого добавления рядом с markdown (план M4 «Риски»; решение 6А):
// разметка вокруг слова не мешает токенам, а внутри кода, ссылки и адреса
// токены и даты не ищутся (допущение О-69).
void main() {
  final ctx = ParseContext(now: DateTime.utc(2026, 11, 12, 10), lang: 'en');
  final ru = ParseContext(now: DateTime.utc(2026, 11, 12, 10), lang: 'ru');

  test(
    'жирный и курсив рядом с токенами — токены разобраны, разметка цела',
    () {
      final r = parseQuickAdd('**Report** tomorrow #Work p1 _draft_', ctx);
      expect(r.title, '**Report** _draft_');
      expect(r.due?.date, '2026-11-13');
      expect(r.project, 'Work');
      expect(r.priority, 1);
    },
  );

  test('зачёркнутый и код — разметка остаётся в названии', () {
    final r = parseQuickAdd('~~old~~ `cfg` завтра @дом', ru);
    expect(r.title, '~~old~~ `cfg`');
    expect(r.due?.date, '2026-11-13');
    expect(r.labels, ['дом']);
  });

  test('в адресе ссылки дата и знаки токенов не разбираются', () {
    final r = parseQuickAdd(
      'Read [docs](https://x.com/today#Work?p=1) tomorrow',
      ctx,
    );
    expect(r.title, 'Read [docs](https://x.com/today#Work?p=1)');
    expect(r.due?.date, '2026-11-13');
    expect(r.project, isNull);
  });

  test('в тексте ссылки дата не разбирается — ссылка не рвётся', () {
    final r = parseQuickAdd('[Report today](https://x.com) p2', ctx);
    expect(r.title, '[Report today](https://x.com)');
    expect(r.due, isNull);
    expect(r.priority, 2);
  });

  test('адрес без скобок — целиком текст', () {
    final r = parseQuickAdd('See https://x.com/tomorrow/p1 @web', ctx);
    expect(r.title, 'See https://x.com/tomorrow/p1');
    expect(r.due, isNull);
    expect(r.labels, ['web']);
    expect(r.priority, 4);
  });

  test('внутри кода дата и токены не разбираются', () {
    final r = parseQuickAdd('Run `deploy today #prod` now', ctx);
    expect(r.title, 'Run `deploy today #prod` now');
    expect(r.due, isNull);
    expect(r.project, isNull);
  });

  test('дата в названии существующей задачи — не внутри ссылки', () {
    expect(parseTitleDue('[Report today](https://x.com)', ctx), isNull);
    final r = parseTitleDue('[Report](https://x.com/today) tomorrow', ctx)!;
    expect(r.title, '[Report](https://x.com/today)');
    expect(r.due?.date, '2026-11-13');
  });

  test('дата внутри жирного — разметка не рвётся', () {
    expect(parseQuickAdd('**Report tomorrow**', ctx).title, '**Report**');
    expect(parseQuickAdd('Do **tomorrow report**', ctx).title, 'Do **report**');
    expect(
      parseQuickAdd('Report tomorrow **urgent**', ctx).title,
      'Report **urgent**',
    );
    expect(
      parseTitleDue('**Позвонить в пятницу**', ru)!.title,
      '**Позвонить**',
    );
  });

  test('описание после `//` — и со ссылкой, адресом или кодом в нём', () {
    final r = parseQuickAdd('Прочитать статью // https://habr.com/x', ru);
    expect(r.title, 'Прочитать статью');
    expect(r.description, 'https://habr.com/x');
    final c = parseQuickAdd('Деплой // команда `make`', ru);
    expect(c.title, 'Деплой');
    expect(c.description, 'команда `make`');
  });

  test('`//` внутри адреса — не описание, следующий `//` — описание', () {
    final r = parseQuickAdd('See https://x.com // notes', ctx);
    expect(r.title, 'See https://x.com');
    expect(r.description, 'notes');
  });
}
