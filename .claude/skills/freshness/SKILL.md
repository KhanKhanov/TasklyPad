---
name: freshness
description: Проверяет актуальность версий Flutter и Dart, пакетов pub, плагинов анализатора, GitHub Actions и рекомендаций платформ по официальным источникам и сообщает расхождения. Использовать раз в квартал, перед релизом и когда CI сломался без изменений в коде.
disable-model-invocation: true
allowed-tools: Bash(flutter --version), Bash(flutter pub outdated*), Bash(flutter analyze*), Bash(dart --version), Bash(git log*), Read, Grep, Glob, WebFetch
---
Только чтение. Ничего не правь: обновление версий — отдельная задача после решения пользователя.

Опора — docs/VERSIONS.md (что закреплено и почему, правила обновления, список официальных источников).
Сверяйся с официальными сайтами (WebFetch), а не с памятью.

1. **SDK.** `flutter --version` локально и `flutter-version` в `.github/workflows/ci.yml` — совпадают ли.
   Текущий stable: https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json
   (поле `current_release.stable`) и заметки к релизу на docs.flutter.dev — нет ли исправлений
   безопасности, ломающих изменений, конца поддержки.
2. **Пакеты.** `flutter pub outdated` в корне и в packages/oplog_sync. Для каждого отставания: что
   нового (changelog на pub.dev), есть ли breaking changes, держит ли нас что-то (как build_runner 2.16 —
   причина в VERSIONS). Пакеты с пометкой discontinued на pub.dev — отдельной строкой.
3. **Плагины анализатора.** Версия riverpod_lint в `analysis_options.yaml` против pub.dev; работает ли
   плагин локально: временно нарушь правило (например, `runApp` без `ProviderScope`) в копии файла и
   убедись, что `flutter analyze` его видит; верни файл.
4. **Устаревшие API.** `flutter analyze` — предупреждения `deprecated_member_use`; поиск deprecated в
   lib/ и packages/.
5. **GitHub Actions.** Закреплённые SHA в `.github/workflows/*.yml` против последних релизов (версия — в
   комментарии рядом с SHA); открытые PR Dependabot.
6. **Рекомендации платформ** из `.claude/rules/platform-*.md` и architecture.md (пакеты уведомлений,
   SAF, трей, хоткеи, markdown) — не устарели ли по их официальной документации.
7. **Уязвимости.** Последний прогон «OSV-Scanner еженедельно» в Actions — есть ли находки.

Отчёт — таблица: что | сейчас в проекте | актуально по источнику (ссылка) | риск | предложение.
Затем: что обновлять сейчас (исправления безопасности), что — плановой задачей, что ждёт (и чего ждёт).
Новые обязательства — строками для docs/OBLIGATIONS.md (предложи, не записывай). Дату проверки и итог
пользователь вносит в раздел «Как часто проверять» docs/VERSIONS.md вместе с решением.
