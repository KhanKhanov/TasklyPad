# Версии, источники и актуальность

Дом для версий инструментов, правил их обновления и списка официальных источников. Версии пакетов
приложения — в `pubspec.yaml` и `pubspec.lock`; здесь только то, чего lock-файлы не говорят.

## Закреплённое и почему

| Что | Версия | Где закреплено | Почему так |
|---|---|---|---|
| Flutter / Dart | 3.47.7 / 3.13.5 | `C:\src\flutter` и `flutter-version` в `.github/workflows/ci.yml` | CI с «последним stable» сам сменил анализатор и дал предупреждение, которого локально не было. Текущий stable — 3.47.8 (исправление безопасности, 23.10.2026): переход — О-5 |
| build_runner | 2.16.x | `pubspec.yaml` | 2.17 несовместим с riverpod_generator 4.0.9 |
| riverpod_lint | ^3.1.9 | `plugins:` в `analysis_options.yaml` | плагин анализатора ставится вне `pubspec.lock` — версия может смениться сама; следить при проверке актуальности (ниже) |
| GitHub Actions | по SHA коммита | `.github/workflows/*.yml`, рядом версия в комментарии | тег (`@v2`) автор может переписать, SHA — нет; обновляет Dependabot |

## Правила обновления
- Только стабильные версии с живым сопровождением; пакет, помеченный на pub.dev как discontinued, —
  замена (как `flutter_markdown` → `flutter_markdown_plus`).
- Устаревшие (deprecated) API в новом коде не используются; предупреждения анализатора о них — дефект.
- Новая версия пакета — не раньше 7 дней после выхода (`cooldown` в `.github/dependabot.yml`): первые
  ошибки релиза обычно находят в эти дни. Исправления безопасности — без выдержки.
- Flutter обновляется локально и в CI одним коммитом; после обновления — полный прогон проверок
  и `flutter test integration_test -d windows`.
- Новая зависимость, обновление мажорной версии или SDK — решение пользователя (Decision Gate, docs/GLOSSARY.md).

## Как часто проверять
Проверка актуальности — раз в квартал, перед каждым релизом (M9, M12) и когда CI сломался без изменений
в коде. Что проверяется: версии Flutter и Dart, `flutter pub outdated`, discontinued-пакеты, устаревшие
API, плагины анализатора, версии Actions, рекомендации платформ (уведомления, SAF, трей, хоткеи, markdown).
Уязвимости зависимостей — OSV-Scanner еженедельно (`.github/workflows/osv-weekly.yml`).

Последняя проверка: 25.10.2026 — Flutter 3.47.8 вышел (О-5), Actions закреплены по SHA.

## Официальные источники
Сверяться с официальной документацией, а не с памятью: docs.flutter.dev, api.flutter.dev, dart.dev,
pub.dev, drift.simonbinder.eu, riverpod.dev, developer.android.com, learn.microsoft.com (Windows),
docs.github.com (Actions, Dependabot), google.github.io/osv-scanner, todoist.com/help (поведение).
Сайт вне списка — с разрешения пользователя.
