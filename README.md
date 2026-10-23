# TasklyPad — личный клон Todoist (Windows 10 + Android, без сервера)

[![CI](https://github.com/KhanKhanov/TasklyPad/actions/workflows/ci.yml/badge.svg)](https://github.com/KhanKhanov/TasklyPad/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Flutter-проект `planner` (рабочее имя кода; репозиторий — TasklyPad) + чистый Dart-пакет `packages/oplog_sync` (ядро синхронизации).
Проверки: `flutter analyze`, `flutter test`, `dart test` (в packages/oplog_sync), `flutter build windows`.

```
lib/                      приложение: app, core, domain, data, sync, nlp, features, platform
                          (README.md в каждом слое; схема — .claude/rules/architecture.md)
packages/oplog_sync/      ядро синхронизации — чистый Dart-пакет: Hlc, Op, MergeEngine, SyncFs
test/                     зеркалит lib/; test/core — ядро; test/fixtures — таблицы примеров Todoist
CLAUDE.md                 роль, стек, команды, процесс — читается каждую сессию
.claude/rules/            правила: архитектура, синк, стиль Dart, тесты, Windows, Android, паритет,
                          обучение (teaching.md — объяснять термины и решения)
.claude/agents/           architect, sync-engineer, flutter-ui, platform-integrator, qa-tester,
                          parity-reviewer, code-reviewer
.claude/skills/           /bootstrap, /feature, /sync-check, /release, todoist-syntax (справочник)
.claude/hooks/            guard-generated.ps1 (блок правок *.g.dart), format-dart.ps1 (dart format)
.claude/settings.json     разрешения и хуки
docs/TODOIST_PARITY.md    ТЗ — чек-лист функций Todoist со статусами
docs/SYNC_DESIGN.md       дизайн синхронизации (op-log CRDT, папка, LAN)
docs/ROADMAP.md           этапы M0–M12
docs/GLOSSARY.md          глоссарий терминов проекта (пополняется по ходу работы)
```

Порядок: `/feature <пункт из TODOIST_PARITY>` по этапам ROADMAP → `/sync-check` → `/release`.
