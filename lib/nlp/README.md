# nlp

Разбор текста — чистый Dart без Flutter, зависит только от lib/domain. Формы — docs/TODOIST_SYNTAX.md,
тесты — таблицы из test/fixtures (test/nlp).

- `quick_add.dart` — строка быстрого добавления: токены §1, срок, подсветка; `parseDueText` — поле срока.
- `date_grammar.dart` — грамматика дат и повторений (§2, §3), одна на ru и en.
- `lexicon.dart`, `lexicon_ru.dart`, `lexicon_en.dart` — словари языков.
- `rule_text.dart` — текст правила повторения ru/en.
- `scanner.dart`, `calendar.dart`, `parse_context.dart` — токены, календарь, «сейчас» и язык.

Язык фильтров (§4) — M5.
