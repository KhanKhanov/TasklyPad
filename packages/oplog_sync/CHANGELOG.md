## Не выпущено

- `uuidV8(parts)` — детерминированный id (SHA-256 → UUID версии 8); на нём `conflictId`, значения прежние.
- `Op.base` — макс. HLC ops сущности от других узлов, известных автору.
- Детекция конфликтов: `findConflicts` (попарная чистая функция от набора ops), `Conflict` с
  детерминированным id (`conflictId`, SHA-256 → UUIDv8), виды `edit` и `delete`; `MergeEngine.silentFields`.
- `MergeEngine.resolveConflict`, `ApplyReport.conflicts` (только неразрешённые); `rebuild` пересчитывает конфликты.
- `OpStore`: `opsForEntity`, `putConflict`, `conflicts`. Зависимость `crypto`.
- `FolderTransport.sync` — обмен через общую папку: неизменяемые чанки со строкой `{"end": N}`, курсоры
  по узлам, `format.json` с `v` и `folder_id`; отчёт `FolderSyncReport` с `ChunkIssue`
  (missing / incomplete / malformed / rejected / io), `SyncFormatException`.
- `SyncStateStore` + `MemorySyncStateStore` (курсоры и водяной знак выгрузки, привязаны к `folder_id`),
  `OpStore.opsOfNodeAfter`.
- `Hlc.parse` проверяет диапазоны wall и counter (строки приходят из чужих файлов).
- `package:oplog_sync/testing.dart` — контрактные сценарии `OpStore` и `SyncStateStore` для любых
  реализаций (`opStoreScenarios`, `syncStateScenarios`, `OpStoreProbe`, `ScenarioNode`, `check`).
- `MemoryOpStore` ведёт себя как база: `transaction` откатывает изменения своего уровня вложенности и
  выполняет внешние транзакции по одной; значения проходят через JSON (не-JSON — ошибка);
  повторный `appendOp` с тем же `op_id` не заменяет запись.
- `SyncFs.writeStringIfAbsent` (атомарно, только если файла нет): через него `FolderTransport` пишет чанки
  (занятый номер → следующий) и `format.json` (чужой — берётся его `folder_id`).
- `MergeEngine.mutate` подтягивает часы к последней известной op сущности: правка позже всего известного,
  даже если приложение не восстановило часы.
- `MergeEngine.adopt` — переиздать от нового id невыгруженные ops-победители прежнего id (копия базы) с их
  исходным временем: порядок LWW не меняется.
- `FolderTransport`: сбой записи `info.json` — `ChunkIssue.io` в отчёте, а не исключение;
  `MemorySyncFs.writeStringIfAbsent` атомарен.
- `testing.dart`: контракт `SyncFs` (`syncFsScenarios`) и сценарии синхронизации через папку
  (`folderSyncScenarios`, `FolderSyncEnv`, `ScenarioPeer`, `syncRounds`, `checkConverged`).

## 0.1.0

- Hlc, Op, MergeEngine с in-memory OpStore, интерфейс SyncFs. FolderTransport — заглушка (M1).
