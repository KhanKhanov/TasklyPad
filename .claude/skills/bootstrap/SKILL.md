---
name: bootstrap
description: Создаёт Flutter-проект планера с нуля в текущей папке — платформы windows и android, пакет packages/oplog_sync, зависимости, analysis_options, l10n, скелет слоёв, базовые core-модули, первый коммит. Запускать один раз в пустом проекте.
disable-model-invocation: true
allowed-tools: Bash(flutter *), Bash(dart *), Bash(git *)
---
Создай проект планера в текущей папке. Если `pubspec.yaml` уже есть — остановись и спроси.
(Этап M0 в этом репозитории уже выполнен; скилл хранится как инструкция для повторного развёртывания.)
Пользователь учится: каждый шаг сопровождай одной-двумя фразами, что это и зачем (правило teaching.md).

1. `flutter doctor -v` — убедись, что есть Windows toolchain (Visual Studio с C++) и Android SDK.
   Нет чего-то — скажи, что установить, и остановись.
2. `flutter create --platforms=windows,android --org dev.local --project-name planner .`
3. `dart create -t package packages/oplog_sync` — чистый Dart-пакет ядра синхронизации (без Flutter).
   В нём: `lib/src/hlc.dart` (Hlc: parse/toString/compareTo/tick/receive), `op.dart`, `merge_engine.dart`
   (интерфейс OpStore + in-memory реализация), `fs.dart` (интерфейс SyncFs + in-memory реализация),
   `folder_transport.dart` (заглушка с TODO), `lib/oplog_sync.dart` экспорт. Тесты на Hlc и merge
   (два in-memory узла). `dart test` в пакете зелёный.
4. pubspec.yaml приложения — добавь зависимости (последние стабильные версии с pub.dev, проверь каждую):
   runtime: oplog_sync (path: packages/oplog_sync), flutter_riverpod, riverpod_annotation, go_router, drift,
   drift_flutter (sqlite3 ^3 сам несёт нативную библиотеку; sqlite3_flutter_libs помечен EOL — не добавлять),
   freezed_annotation, json_annotation, rrule, intl, clock, logger, path_provider, path,
   flutter_local_notifications, home_widget, window_manager, tray_manager, hotkey_manager,
   shared_preferences, flutter_localizations (sdk).
   dev: build_runner, riverpod_generator, drift_dev, freezed, json_serializable, flutter_lints,
   flutter_test, integration_test (sdk), fake_async. riverpod_lint в pubspec НЕ нужен (см. шаг 5).
5. analysis_options.yaml (в приложении и в пакете): flutter_lints/lints + `language: strict-casts,
   strict-inference, strict-raw-types`, исключить `**/*.g.dart`, `**/*.freezed.dart`, `**/*.drift.dart`.
   В приложении riverpod_lint подключается через новую систему плагинов анализатора (Dart ≥ 3.10):
   верхнеуровневый ключ `plugins:` → `riverpod_lint: ^<версия с pub.dev>`; custom_lint не используется.
6. l10n: `l10n.yaml` (arb-dir lib/l10n, template app_ru.arb), файлы app_ru.arb и app_en.arb с 3 строками.
   В pubspec: `flutter: generate: true`.
7. Скелет папок по .claude/rules/architecture.md с файлами-заглушками `README.md` в каждом слое.
   core: `ids.dart` (UUIDv7), `fractional_index.dart` (between(a, b)), `clock.dart` —
   каждый с unit-тестом в test/core.
8. Минимальное приложение: MaterialApp.router с одним экраном «Входящие» (пусто) и l10n.
9. test/fixtures/README.md с описанием формата таблиц для парсеров. docs/GLOSSARY.md — дополни
   терминами, которые встретились на этом шаге.
10. `.gitignore` для Flutter + `build/`, `*.pfx`, `android/key.properties`, `.claude/settings.local.json`,
    `CLAUDE.local.md`. Отслеживать ли `CLAUDE.md` и `.claude/` — спросить пользователя.
11. `flutter pub get` → `dart run build_runner build -d` → `flutter analyze` → `flutter test` →
    `dart test` в packages/oplog_sync → `flutter build windows`. Всё зелёное; покажи вывод.
12. `git init` (если нет). Первый коммит `chore: bootstrap flutter project` делает пользователь —
    покажи команды одним блоком.

В конце выведи дерево проекта (2 уровня), блок «Что мы сделали и почему» и напомни про следующий шаг:
`/feature Ядро синхронизации` (M1 в docs/ROADMAP.md).
