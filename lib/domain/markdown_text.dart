import 'package:markdown/markdown.dart' as md;

// Markdown в названии и описании (help «Format text in a Todoist task»;
// решения 6А, 7А плана M4). Хранится исходный текст с символами разметки,
// как в API Todoist; здесь — разбор в дерево (AST) и видимый текст для
// сортировки и подписей. Рисует дерево lib/features/common/ui.

/// Разметка названия: жирный, курсив, код, ссылка, зачёркнутый `~~`, адрес
/// без скобок — ссылкой (help: «Wrap a URL in backticks … to stop it from
/// becoming a link»). Без HTML: тег в названии — просто текст.
final md.ExtensionSet titleSyntax = md.ExtensionSet(const [], [
  _DoubleTilde(),
  md.AutolinkExtensionSyntax(),
]);

/// Разметка описания: всё, что в названии, и блоки — заголовки, цитаты,
/// блоки кода (в том числе ```), списки.
final md.ExtensionSet descriptionSyntax = md.ExtensionSet(
  const [md.FencedCodeBlockSyntax()],
  [_DoubleTilde(), md.AutolinkExtensionSyntax()],
);

/// Строчная разметка [text] деревом: `strong`, `em`, `code`, `del`, `a`
/// (адрес — `href`), `img` (подпись — `alt`), текст — [md.Text].
List<md.Node> parseInlineMarkdown(String text) =>
    md.Document(extensionSet: titleSyntax, encodeHtml: false).parseInline(text);

/// Видимый текст строки [text] без символов разметки: у ссылки — её текст,
/// у картинки — подпись. Для сортировки по имени и подписей без разметки.
String plainText(String text) => _plain(parseInlineMarkdown(text));

String _plain(List<md.Node> nodes) {
  final out = StringBuffer();
  for (final node in nodes) {
    switch (node) {
      case md.Text(:final text):
        out.write(text);
      case md.Element(tag: 'img', :final attributes):
        out.write(attributes['alt'] ?? '');
      case md.Element(tag: 'br'):
        out.write(' ');
      case md.Element(:final children):
        out.write(_plain(children ?? const []));
      default:
        out.write(node.textContent);
    }
  }
  return out.toString();
}

/// В строке [text] есть строчная разметка: отрисованный текст отличается от
/// исходного.
bool hasInlineMarkup(String text) {
  final nodes = parseInlineMarkdown(text);
  return nodes.any((n) => n is md.Element) || _plain(nodes) != text;
}

/// Начало строки-блока: заголовок, цитата, пункт списка, ограда кода.
final RegExp _blockMarker = RegExp(
  r'^\s{0,3}(?:#{1,6}\s+|>\s?|[-*+]\s+|\d{1,9}[.)]\s+)',
);
final RegExp _fence = RegExp(r'^\s{0,3}(?:```|~~~)');

/// В описании [text] есть разметка — строчная или блоков.
bool hasDescriptionMarkup(String text) =>
    text
        .split('\n')
        .any((l) => _blockMarker.hasMatch(l) || _fence.hasMatch(l)) ||
    hasInlineMarkup(text);

/// Строки описания без знаков блоков (`# `, `> `, `- `, `1. `, ограды кода)
/// — для краткого показа одной строкой: строчная разметка остаётся.
List<String> descriptionLines(String text) => [
  for (final line in text.split('\n'))
    if (!_fence.hasMatch(line))
      if (line.replaceFirst(_blockMarker, '').trimRight() case final l
          when l.trim().isNotEmpty)
        l,
];

/// Зачёркнутый — только двумя тильдами `~~` (help: «wrapped in two tildes»);
/// одна тильда (`~5 мин`) — текст. `StrikethroughSyntax` пакета по GFM
/// зачёркивает и одной.
class _DoubleTilde extends md.DelimiterSyntax {
  _DoubleTilde()
    : super(
        '~+',
        requiresDelimiterRun: true,
        allowIntraWord: true,
        startCharacter: 0x7E,
        tags: [md.DelimiterTag('del', 2)],
      );
}
