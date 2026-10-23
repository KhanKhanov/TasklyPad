## Не выпущено

- `Op.base` — макс. HLC ops сущности от других узлов, известных автору.
- Детекция конфликтов: `findConflicts` (попарная чистая функция от набора ops), `Conflict` с
  детерминированным id (`conflictId`, SHA-256 → UUIDv8), виды `edit` и `delete`; `MergeEngine.silentFields`.
- `MergeEngine.resolveConflict`, `ApplyReport.conflicts` (только неразрешённые); `rebuild` пересчитывает конфликты.
- `OpStore`: `opsForEntity`, `putConflict`, `conflicts`. Зависимость `crypto`.

## 0.1.0

- Hlc, Op, MergeEngine с in-memory OpStore, интерфейс SyncFs. FolderTransport — заглушка (M1).
