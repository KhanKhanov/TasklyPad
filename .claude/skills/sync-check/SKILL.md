---
name: sync-check
description: Прогоняет все проверки синхронизации — тесты пакета oplog_sync, тесты слияния в приложении, двухузловые сценарии через временную папку, rebuildFromOps — и даёт короткий отчёт. Использовать после любых изменений в packages/oplog_sync, lib/sync или lib/data и перед релизом.
allowed-tools: Bash(flutter test*), Bash(dart *)
---
## Текущие изменения в слое данных

!`git diff --stat HEAD -- packages/oplog_sync lib/sync lib/data test/sync test/data`

## Инструкции

1. `dart test` в packages/oplog_sync — покажи итог и каждый упавший тест целиком.
2. `dart run build_runner build -d` (если менялись таблицы или модели).
3. `flutter test test/sync test/data test/core` — то же.
4. `flutter test integration_test/sync_two_nodes_test.dart -d windows` — если файл существует и есть
   Windows-устройство; иначе отметь «пропущено» с причиной.
5. Сверь diff выше с инвариантами .claude/rules/sync-crdt.md: новое поле → есть в ops, миграции,
   тесте; формат не менялся без версии; нет прямых update/delete вне Mutator; логика слияния не ушла
   из пакета в адаптеры.

Отчёт: таблица «проверка → результат», затем список нарушений инвариантов (файл:строка) или «нарушений нет».
