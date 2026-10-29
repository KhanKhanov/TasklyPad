# Архитектура

## Слои (feature-first, монорепозиторий)
```
packages/
  oplog_sync/  чистый Dart, без Flutter: Op, Hlc, MergeEngine, интерфейсы OpStore и SyncFs,
               FolderTransport, LanTransport, снапшоты, компакция. Свои unit-тесты (dart test).
lib/
  app/         bootstrap, router (go_router), тема, DI
  core/        ids.dart (UUIDv7), fractional_index.dart, clock.dart
  domain/      сущности (freezed, immutable), value objects, политики (recurrence, karma)
  data/        drift: таблицы, DAO, миграции, репозитории; проекции op-log
  sync/        адаптеры к oplog_sync: DriftOpStore, SyncFs для Windows (dart:io) и Android (SAF), Mutator
  nlp/         парсеры: quick add, даты (ru/en), повторения, язык фильтров
  features/    tasks, projects, sections, labels, filters, quick_add, views (inbox/today/upcoming),
               reminders, search, karma, templates, import_export, settings
               <feature>/{ui,state,logic}
  platform/    notifications, home widgets, tray, hotkeys, saf, share — через интерфейсы
test/          зеркалит lib/; test/sync — двухузловые сценарии; test/fixtures — примеры Todoist
```

## Правила
- `packages/oplog_sync` не зависит от Flutter и drift: только `dart:core`, `dart:async`, `dart:convert`,
  `package:meta` и `package:crypto` (SHA-256 для детерминированных id; решение 23.10.2026).
  Всё платформенное приходит через интерфейсы. Это позволяет гонять тысячи сценариев слияния
  обычным `dart test` и однажды опубликовать пакет отдельно.
- UI не трогает drift напрямую: только провайдеры → репозитории. Виджеты без бизнес-логики.
- Логика фич (`features/*/logic`) импортирует `data/projection/entity_fields.dart` только ради имён
  типов и полей ops — допустимо (решение 4 M2.4 в plans/m2), и `data/local_meta_dao.dart` — для
  локальных настроек устройства, которые не синхронизируются (тема); остального из lib/data не трогает.
- Корни провайдеров — lib/app; features читают их, но lib/app не импортирует логику фич, кроме
  регистрации экранов в router и провайдеров команд.
- Все мутации идут через `Mutator` (lib/sync/mutator.dart), который пишет ops и обновляет
  проекции в одной транзакции. Прямой `update`/`delete` в таблицах сущностей запрещён.
- ID — UUIDv7 строки. Время — UTC ISO-8601; срок задачи различает «дата» и «дата+время»
  (как в Todoist): хранить `due_date`, `due_time?`, `due_tz`.
- Порядок элементов — fractional index (`order_key` строка), не целые числа.
- Платформенные API — только через интерфейсы в lib/platform с фейками для тестов.
- Состояние: Riverpod 3 с `@riverpod`-кодогеном; потоки из drift (`watch`) → UI.
- Навигация: go_router, маршруты в app/router.dart, deep links для уведомлений и виджетов.
- Пакеты для платформы (проверять актуальность на pub.dev при добавлении):
  уведомления flutter_local_notifications (Windows: нет periodicallyShow — планируем сами);
  Android-виджеты home_widget; трей tray_manager; окно window_manager; хоткей hotkey_manager;
  SAF-папка — актуальный пакет с persistable URI permission; mDNS — bonsoir; RRULE — rrule;
  markdown — flutter_markdown_plus или markdown_widget (flutter_markdown закрыт); графики fl_chart.
