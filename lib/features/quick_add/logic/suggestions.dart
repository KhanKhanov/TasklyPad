import 'quick_add_draft.dart';

/// Что набирается токеном под курсором.
enum TokenKind { project, section, label }

/// Токен, который пользователь набирает: от знака `#`, `/`, `%` или `@` до
/// курсора — его дополняет список (help «Use Task Quick Add»).
final class TokenQuery {
  const TokenQuery(this.kind, this.start, this.end, this.query, this.sign);

  final TokenKind kind;

  /// Участок токена со знаком: [start] — знак, [end] — курсор.
  final int start;
  final int end;

  /// Набранное после знака.
  final String query;

  /// Знак, как набран: у метки `%` или `@` (help: `@` — до конца 2026).
  final String sign;
}

/// Токен под курсором [cursor] строки [text] или `null`. Знак — в начале
/// слова, как в разборе (lib/nlp/quick_add.dart); после курсора — пробел
/// или конец строки.
TokenQuery? tokenQueryAt(String text, int cursor) {
  if (cursor < 1 || cursor > text.length) return null;
  if (cursor < text.length && text[cursor].trim().isNotEmpty) return null;
  var start = cursor;
  while (start > 0 && text[start - 1].trim().isNotEmpty) {
    start--;
  }
  if (start == cursor) return null;
  final kind = switch (text[start]) {
    '#' => TokenKind.project,
    '/' => TokenKind.section,
    '%' || '@' => TokenKind.label,
    _ => null,
  };
  if (kind == null) return null;
  final query = text.substring(start + 1, cursor);
  // `#"имя` — ещё не закрытое имя в кавычках; закрытое `#"имя"` уже токен.
  if (query.startsWith('"')) return null;
  // `//` — описание, а не раздел.
  if (kind == TokenKind.section && query.startsWith('/')) return null;
  return TokenQuery(kind, start, cursor, query, text[start]);
}

/// Пункт списка: существующее имя или «Создать …».
final class Suggestion {
  const Suggestion({
    required this.name,
    required this.insert,
    this.id,
    this.color,
    this.create = false,
  });

  /// Имя для показа.
  final String name;

  /// Текст токена, который встаёт на место набранного (со знаком).
  final String insert;
  final String? id;
  final String? color;

  /// Создать проект или метку с именем [name] вместе с задачей.
  final bool create;
}

/// Подсказки для [q]: имена, в которых есть набранное (без учёта регистра),
/// по порядку сайдбара; в конце — «Создать», если такого имени нет (для
/// проекта и метки; раздел help создавать не предлагает). [inboxTitle] —
/// «Входящие» на языке интерфейса. Имя, которое токеном не записать
/// (раздел и метка с пробелом), не предлагается.
List<Suggestion> suggestionsFor(
  TokenQuery q,
  QuickAddResolver resolver, {
  required String inboxTitle,
  required String sectionProjectId,
}) {
  final ws = resolver.ws;
  final lower = q.query.toLowerCase();
  bool matches(String name) => name.toLowerCase().contains(lower);
  final mark = q.sign;
  final out = <Suggestion>[];
  switch (q.kind) {
    case TokenKind.project:
      final inbox = ws.inbox;
      if (inbox != null && matches(inboxTitle)) {
        out.add(
          Suggestion(
            name: inboxTitle,
            insert: _project(inboxTitle),
            id: inbox.id,
          ),
        );
      }
      for (final item in ws.projectTree(expandCollapsed: true)) {
        final p = item.value;
        if (!matches(p.name)) continue;
        out.add(
          Suggestion(
            name: p.name,
            insert: _project(p.name),
            id: p.id,
            color: p.color,
          ),
        );
      }
      if (q.query.trim().isNotEmpty &&
          findProject(ws, q.query, inboxNames: resolver.inboxNames) == null) {
        out.add(
          Suggestion(name: q.query, insert: _project(q.query), create: true),
        );
      }
    case TokenKind.section:
      for (final s in ws.sectionsOf(sectionProjectId)) {
        if (!matches(s.name) || _hasSpace(s.name)) continue;
        out.add(Suggestion(name: s.name, insert: '/${s.name}', id: s.id));
      }
    case TokenKind.label:
      for (final l in ws.labels) {
        if (!matches(l.name) || _hasSpace(l.name)) continue;
        out.add(
          Suggestion(
            name: l.name,
            insert: '$mark${l.name}',
            id: l.id,
            color: l.color,
          ),
        );
      }
      if (q.query.isNotEmpty && findLabel(ws, q.query) == null) {
        out.add(
          Suggestion(name: q.query, insert: '$mark${q.query}', create: true),
        );
      }
  }
  return out;
}

/// Имя проекта токеном: с пробелом — в кавычках.
String _project(String name) => _hasSpace(name) ? '#"$name"' : '#$name';

bool _hasSpace(String name) => name.contains(RegExp(r'\s'));
