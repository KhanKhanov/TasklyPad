# Как участвовать

Это личный проект одного человека, но issue и PR приветствуются.

- **Эталон — Todoist.** Поведение, термины и синтаксис копируем точно, не «улучшаем».
  Перед фичей найдите её пункт в [docs/TODOIST_PARITY.md](docs/TODOIST_PARITY.md).
- **Сохранность данных важнее всего.** Любое новое поле или таблица проходит через op-log,
  миграцию drift и тест слияния ([.claude/rules/sync-crdt.md](.claude/rules/sync-crdt.md)).
- **Проверки перед PR:** `flutter analyze` без warnings, `dart format .`, `flutter test`,
  `dart test` в `packages/oplog_sync`. CI прогоняет то же самое.
- **Коммиты** в формате Conventional Commits: `feat(quick-add): парсер дат`. Одна фича — один коммит.
- **Сгенерированные файлы** (`*.g.dart`, `*.freezed.dart`, `*.drift.dart`) руками не правим.
- **Язык:** комментарии, документация и тексты UI — по-русски, идентификаторы — английские.

Подробнее о слоях и правилах: [CLAUDE.md](CLAUDE.md) и [.claude/rules/](.claude/rules/).
