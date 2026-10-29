# domain

Сущности (freezed, неизменяемые), value objects, политики: повторения, карма. Без Flutter, без drift, без DateTime.now().

- `models.dart`, `workspace.dart`, `tree.dart`, `rules.dart` — сущности, снимок данных для экранов, деревья и правила команд.
- `undo.dart` — отмена действия для тоста «Отменить» (запись — `Undo` в lib/sync).
- `conflicts.dart` — карточки конфликтов для экрана «Конфликты».
- `sync_status.dart` — устройства в папке, итог смены папки и ошибки синхронизации, которые показывает интерфейс.
- `theme_settings.dart` — тема оформления.
