import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:planner/domain/markdown_text.dart';

// Разбор markdown названия и описания (help «Format text in a Todoist task»;
// решения 6А, 7А плана M4).
void main() {
  group('видимый текст названия — без знаков разметки', () {
    const rows = {
      'Plain text': 'Plain text',
      '**Bold** task': 'Bold task',
      '*Italic* and _also_': 'Italic and also',
      'Run `npm test`': 'Run npm test',
      '~~Old~~ new': 'Old new',
      '~5 min~ left': '~5 min~ left',
      'Read [the docs](https://example.com)': 'Read the docs',
      'See https://example.com/a?b=1': 'See https://example.com/a?b=1',
      r'Price \*50\*': 'Price *50*',
      '![logo](https://example.com/a.png) alt': 'logo alt',
      '<b>tag</b> stays': '<b>tag</b> stays',
      '# not a heading': '# not a heading',
      '**Жирный** и _курсив_': 'Жирный и курсив',
    };
    for (final MapEntry(key: input, value: plain) in rows.entries) {
      test('«$input» → «$plain»', () => expect(plainText(input), plain));
    }
  });

  test('дерево названия: теги жирного, курсива, кода, зачёркнутого и '
      'ссылки с адресом', () {
    final nodes = parseInlineMarkdown(
      '**b** *i* `c` ~~d~~ [l](https://x.com) www.example.com',
    );
    final tags = [
      for (final n in nodes)
        if (n is md.Element) n.tag,
    ];
    expect(tags, ['strong', 'em', 'code', 'del', 'a', 'a']);
    final links = [
      for (final n in nodes)
        if (n is md.Element && n.tag == 'a') n.attributes['href'],
    ];
    expect(links, ['https://x.com', 'http://www.example.com']);
  });

  test('адрес в обратных кавычках — код, не ссылка (help)', () {
    final nodes = parseInlineMarkdown('`https://example.com`');
    expect((nodes.single as md.Element).tag, 'code');
  });

  test('есть ли разметка: обычный текст — нет, знаки разметки — да', () {
    expect(hasInlineMarkup('Купить молоко'), isFalse);
    expect(hasInlineMarkup('Price 5 * 3'), isFalse);
    expect(hasInlineMarkup('**Купить**'), isTrue);
    expect(hasInlineMarkup('https://example.com'), isTrue);
    expect(hasInlineMarkup(r'a \* b'), isTrue);
  });

  test('описание: блоки — тоже разметка', () {
    expect(hasDescriptionMarkup('Строка\nвторая'), isFalse);
    expect(hasDescriptionMarkup('# Заголовок'), isTrue);
    expect(hasDescriptionMarkup('- пункт'), isTrue);
    expect(hasDescriptionMarkup('1. пункт'), isTrue);
    expect(hasDescriptionMarkup('> цитата'), isTrue);
    expect(hasDescriptionMarkup('```\ncode\n```'), isTrue);
  });

  test('строки описания без знаков блоков и оград кода, пустые — прочь', () {
    expect(
      descriptionLines('# Заголовок\n\n- **пункт**\n```\nx = 1\n```\n> цитата'),
      ['Заголовок', '**пункт**', 'x = 1', 'цитата'],
    );
  });
}
