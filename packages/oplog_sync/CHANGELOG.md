## Не выпущено

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

## 0.1.0

- Hlc, Op, MergeEngine с in-memory OpStore, интерфейс SyncFs. FolderTransport — заглушка (M1).
