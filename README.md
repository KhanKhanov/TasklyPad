# TasklyPad — личный таск-менеджер (Windows 10 + Android, без сервера)

[![CI](https://github.com/KhanKhanov/TasklyPad/actions/workflows/ci.yml/badge.svg)](https://github.com/KhanKhanov/TasklyPad/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Flutter-проект `planner` (рабочее имя кода; репозиторий — TasklyPad) + чистый Dart-пакет `packages/oplog_sync` (ядро синхронизации).
Проверки: `flutter analyze`, `flutter test`, `dart test` (в packages/oplog_sync), `flutter build windows`.

```
lib/                      приложение: app, core, domain, data, sync, nlp, features, platform
                          (назначение слоя — README.md в каждой папке)
packages/oplog_sync/      ядро синхронизации — чистый Dart-пакет: Hlc, Op, MergeEngine, SyncFs
test/                     зеркалит lib/; test/core — ядро; test/fixtures — таблицы примеров Todoist
docs/TODOIST_PARITY.md    ТЗ — чек-лист функций Todoist со статусами
docs/TODOIST_SYNTAX.md    справочник синтаксиса Todoist для парсеров (quick add, повторения, фильтры)
docs/SYNC_DESIGN.md       дизайн синхронизации (op-log CRDT, папка, LAN) и инварианты реализации
docs/ROADMAP.md           этапы M0–M12
docs/GLOSSARY.md          глоссарий терминов проекта (пополняется по ходу работы)
CONTRIBUTING.md           правила разработки и чек-лист «Готово»
```

Порядок работы: фича по пункту docs/TODOIST_PARITY.md в рамках этапа из ROADMAP → проверки
синхронизации (тесты пакета и двухузловые сценарии) → релиз (MSIX + APK).
