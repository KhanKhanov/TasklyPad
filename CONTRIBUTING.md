# Как участвовать

Это личный проект одного человека, но issue и PR приветствуются.

- **Эталон — Todoist.** Поведение, термины и синтаксис копируем точно, не «улучшаем».
  Перед фичей найдите её пункт в [docs/TODOIST_PARITY.md](docs/TODOIST_PARITY.md);
  синтаксис quick add, повторений и фильтров — [docs/TODOIST_SYNTAX.md](docs/TODOIST_SYNTAX.md).
- **Сохранность данных важнее всего.** Любое новое поле или таблица проходит через op-log,
  миграцию drift и тест слияния ([docs/SYNC_DESIGN.md](docs/SYNC_DESIGN.md), раздел «Инварианты реализации»).
- **Слои.** Назначение каждой папки `lib/` — в её README.md; UI не трогает drift напрямую,
  все мутации идут через `Mutator` (lib/sync), время и ID — через инжектируемые `Clock` и `IdGenerator`.
- **Сгенерированные файлы** (`*.g.dart`, `*.freezed.dart`, `*.drift.dart`) руками не правим:
  правим источник и запускаем `dart run build_runner build -d`.
- **Язык:** комментарии, документация и тексты UI — по-русски (через l10n, en — второй язык),
  идентификаторы — английские.
- **Коммиты** в формате Conventional Commits: `feat(quick-add): парсер дат`. Одна фича — один коммит.

## Чек-лист «Готово»

- `flutter analyze` без warnings
- `dart format .`
- `flutter test` и `dart test` в `packages/oplog_sync` зелёные (CI прогоняет то же самое)
- новое поле/таблица прошли через op-log, миграцию drift и тест слияния
- для UI — запуск на Windows и скриншот
- статус пункта в docs/TODOIST_PARITY.md обновлён, новые термины — в docs/GLOSSARY.md
