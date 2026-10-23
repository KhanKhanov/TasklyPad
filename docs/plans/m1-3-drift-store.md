# План M1.3 — схема drift и `DriftOpStore`

Утверждён 23.10.2026. Часть этапа M1 (docs/plans/m1-sync-core.md). UI нет — только база, адаптеры и тесты.

## Ключевые решения
1. **`field_versions` — обобщённая проекция «поле → (hlc, значение)».** Типизированные `tasks`/`projects` —
   быстрое представление поверх неё; инвариант: `tasks` = проектор(`field_versions`).
   Альтернативы: колонки `<поле>_hlc` в каждой таблице (вдвое больше колонок и миграций, неизвестным полям
   некуда деться); `MAX(hlc)` из `ops` (ломает `rebuild`: после `clearProjections` `fieldHlc` обязан быть null).
2. **Прямая совместимость.** Op с неизвестным полем или типом (от более новой версии на другом устройстве)
   сохраняется в `ops` и `field_versions`, типизированные таблицы не трогает. После обновления приложения
   `projectorVersion` в коде ≠ `local_meta.projector_version` → `reproject()` перекладывает `field_versions`
   через новый реестр в одной транзакции. LWW и конфликты не пересчитываются.
   Альтернатива: полный `engine.rebuild()` — нужен движок при открытии базы, лишний пересчёт конфликтов.
3. **Реестр проекторов с белым списком.** Колонки — ключи Dart-карты, значения пишутся типизированными
   companion drift; имён колонок из данных и динамического SQL нет. Альтернативы: динамический SQL по
   белому списку (без проверки типов), одна JSON-колонка `data` (неудобные запросы и индексы).
4. **Контрактные сценарии — в `packages/oplog_sync/lib/testing.dart` без `package:test`.** Сценарий —
   функция от фабрики хранилища; помощник `check` бросает `ContractFailure` «что: ожидал …, получил …».
5. **Бэкап перед миграцией — `VACUUM INTO`**, а не копия файла (при WAL файлы `-wal`/`-shm` копируются
   несогласованно). База и бэкапы — в `getApplicationSupportDirectory()` (AppData), а не в «Документах»
   (часто под OneDrive; живой SQLite под облачным клиентом может испортиться).

## Схема (schemaVersion 1)
HLC — TEXT `Hlc.toString()`. В SQL сравниваются только HLC одного узла (`opsOfNodeAfter`): при одинаковом
узле порядок строк совпадает с числовым. HLC разных узлов сравнивает только Dart (`compareTo`).
Значение op — `value_json` TEXT NOT NULL (`null` хранится как `'null'`).

| Таблица | Колонки | Ключ / индексы |
|---|---|---|
| `ops` | op_id, node_id, hlc, base?, entity_type, entity_id, field, value_json | PK op_id; `(entity_type, entity_id, field)`; `(node_id, hlc)` |
| `field_versions` | entity_type, entity_id, field, hlc, value_json | PK `(entity_type, entity_id, field)`, WITHOUT ROWID |
| `conflicts` | id, kind (`edit`/`delete`), entity_type, entity_id, field, older_op_id, newer_op_id | PK id |
| `sync_cursors` | node_id, seq | PK node_id |
| `local_meta` | key, value | PK key: `node_id`, `hlc`, `projector_version`, `sync.folder_id`, `sync.uploaded_up_to` |
| `projects` | id, name `''`, color `'charcoal'`, parent_id?, order_key `''`, is_favorite/is_archived/is_inbox `false`, view_style `'list'`, deleted `false` | PK id |
| `tasks` | id, content `''`, description `''`, project_id?, section_id?, parent_id?, order_key `''`, priority `4`, due_date?, due_time?, due_tz?, is_completed `false`, completed_at?, added_at?, deleted `false` | PK id; `(project_id, order_key)`; `(due_date)` |

- Нет NOT NULL без default и нет FOREIGN KEY: ops приходят в любом порядке.
- Имена полей op — как в Todoist API v1 (для импорта в M11), кроме `order_key` (fractional index),
  `deleted` (tombstone пакета), `is_completed`.
- **`priority`: 1 = P1 (высший), по умолчанию 4** — как в UI и фильтрах `p1`. В API Todoist шкала обратная
  (4 = P1): перевод при импорте; зафиксировать в doc-комментарии поля.
- **`due` — одно поле-объект** `{date, time?, tz?, …}`: параллельная правка срока — один конфликт `due`.
  Проектор раскладывает его на 3 колонки, остальные ключи остаются в op и `field_versions`.
- `order_key` — в `silentFields`. Локальные: `local_meta`, `sync_cursors`. Производные: `field_versions`, `conflicts`.

## `DriftOpStore`
- `appendOp` — insert or ignore; `containsOp` — по PK; `opsForEntity` — по типу и id; `opsOfNodeAfter` — `ORDER BY hlc`.
- `writeField` — upsert `field_versions`, затем, если тип и поле есть в реестре, upsert строки проекции только
  колонками этого поля. HLC не сравнивает — это делает движок. Tombstone — обычное поле `deleted`.
- `putConflict` — insert, если записи нет (`resolved` из аргумента не пишется); `conflicts()` берёт `resolved`
  из `field_versions('conflict', id, 'resolved')` — не зависит от того, что пришло раньше.
- `clearProjections` — таблицы реестра, `field_versions`, `conflicts`; `ops`, `local_meta`, `sync_cursors` не трогает.
- `transaction` — `db.transaction`: вложенный вызов — savepoint, исключение откатывает только его уровень.
- `DriftSyncStateStore`: курсоры в `sync_cursors`, `folderId` и `uploadedUpTo` в `local_meta`; `resetForFolder` — одна транзакция.

## Автобэкап
В `setup` drift_flutter, до миграций, по `PRAGMA user_version`: 0 или = цели — ничего; меньше цели —
`VACUUM INTO backups/pre-migration-v{v}-{время}.sqlite` и ротация до 14; больше цели — `SchemaTooNewException`.
Сбой бэкапа отменяет открытие. Логика — в `prepareForOpen(db, target, BackupStore, nowUtc)` без ФС,
`BackupStore` подменяется фейком.

## Коммит 1 — `test(oplog_sync): контрактные сценарии OpStore и SyncStateStore`
- `MemoryOpStore.transaction` — настоящий откат на каждом уровне вложенности (сейчас просто `action()`).
- `MemoryOpStore` нормализует значения через JSON, как будет делать drift: не-JSON значение — ошибка.
- `lib/testing.dart` (не экспортируется из `oplog_sync.dart`): `OpStoreProbe` (store, `entity`, `alive`,
  `checkConsistency`), `ContractScenario`, списки `opStoreScenarios` и `syncStateScenarios`, `ScenarioNode`,
  помощники `check`, `checkThat`, `checkThrows`. test/support/test_node.dart остаётся для
  `folder_transport_test.dart` — его перенос на `ScenarioNode` вместе с test/sync в M1.4.
- Сделано: 103 → 130 тестов (38 перенесены в сценарии, 27 новых); со старой заглушкой `transaction`
  падают 5 сценариев отката — сценарии ловят именно эту ошибку.
- Тесты `merge_engine_test.dart` и `conflict_test.dart`, зависящие от хранилища, переезжают в сценарии;
  число тестов `dart test` после переноса — не меньше, чем до.
- Новые сценарии: дедупликация, op туда-обратно (base, null/bool/int/double/юникод/вложенные), не-JSON
  значение, `writeField` не сравнивает HLC и не пишет в журнал, `opsForEntity` не смешивает типы,
  `opsOfNodeAfter`, `putConflict`, `clearProjections`, откат транзакций (вложенный и внешний), неизвестные
  тип и поле, tombstone, `applyAll` с ошибкой посреди пакета не применяется частично.

## Коммит 2 — `feat(data): схема drift, DriftOpStore, автобэкап перед миграцией`
1. Таблицы, `AppDatabase`, `build.yaml` (`schema_dir: drift_schemas/`), `make-migrations`, зависимость `sqlite3`.
2. `db_backup.dart`, `db_open.dart` + `db_backup_test` (0→1, 1→1, 1→2, 3→2, ротация, сбой копии, реальный `VACUUM INTO`).
3. Проекторы и реестр + `projector_test` (каждая колонка покрыта реестром, частичный upsert, неверный тип, `due`).
4. `DriftOpStore`, `DriftSyncStateStore`, `LocalMetaDao` + контрактные сценарии на in-memory базе,
   `reproject_test`, `rebuild_equivalence_test` (два узла + 50 случайных журналов с фиксированным seed).
5. `dart format .`, `flutter analyze`, `flutter test`; SYNC_DESIGN «Проекции», статус в m1-sync-core.md, глоссарий;
   формулировка `base` в правилах инвариантов (макс. HLC чужих ops сущности, а не HLC поля).

## Итог коммита 2 (23.10.2026)
- Приложение: 161 тест (63 контрактных на drift, 12 проектора, 3 reproject, 51 rebuild-эквивалентность,
  11 бэкапа); пакет: 130. Проверка поломкой: без проекции одного поля при пошаговой записи падают 46 тестов
  (сверка с `reproject` в конце каждого сценария), без проекции поля вообще — 6.
- По ревью: проектор получает значение после JSON (как `reproject`) — иначе срок из `Map<dynamic, dynamic>`
  или объекта с `toJson` терял дату; имя копии с миллисекундами; ротация сохраняет новейшую копию каждой
  версии схемы; `setup` собирается верхнеуровневой фабрикой `backupBeforeMigration`; `conflicts()` по id.
  Остальное (Android-бэкап и `node_id` копии, Входящие, Roaming AppData) — в плане M1.4.
- Отличия от плана: реестр — `lib/data/projection/default_registry.dart`; `onUpgrade` пока бросает
  ошибку (шагов миграции нет до версии 2, `stepByStep` появится вместе с ней); тесты миграций
  `make-migrations` для одной версии не генерируются — только снимок `drift_schemas/…/drift_schema_v1.json`;
  ограничение `kind` у `conflicts` — `CHECK` через `customConstraint`.

## Перенесено в M1.4
- Вызов `reproject` при запуске (bootstrap).
- `Mutator` при правке объектного поля (`due`) сливает объект с текущим значением из `field_versions`,
  чтобы не стереть ключи, которых не знает (например, повторение).

## Риски и ограничения
- `rebuild` загружает весь журнал в память — до компакции в M12.
- Копия базы, восстановленная на другом ПК, несёт тот же `node_id` — учесть в M11 вместе с бэкапами.
- Разные версии приложения с разными `silentFields` видят разные наборы конфликтов; на данные не влияет.
- В M2 «Входящие» — фиксированный id и имя через l10n, иначе два узла создадут по своим «Входящим».
