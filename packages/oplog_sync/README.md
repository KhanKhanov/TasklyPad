# oplog_sync

Ядро синхронизации планера без сервера: журнал операций (op-log) с правилом
«последняя запись побеждает» (LWW) по каждому полю и гибридными логическими часами (HLC).

Чистый Dart: не зависит от Flutter, drift или файловой системы. Всё платформенное
приходит через интерфейсы `OpStore` и `SyncFs`, поэтому тысячи сценариев слияния
гоняются обычным `dart test` за секунды.

Дизайн и инварианты: `../../docs/SYNC_DESIGN.md`.

```
lib/src/hlc.dart              Hlc — метка времени: wall ms : counter : node
lib/src/op.dart               Op — одна неизменяемая операция «поле X сущности Y стало Z»
lib/src/merge_engine.dart     OpStore (интерфейс) + MemoryOpStore + MergeEngine (apply / mutate / resolveConflict / rebuild)
lib/src/conflict.dart         Conflict, findConflicts — детекция параллельных правок, conflictId (SHA-256 → UUIDv8)
lib/src/fs.dart               SyncFs (интерфейс) + MemorySyncFs для тестов
lib/src/sync_state.dart       SyncStateStore (интерфейс) + MemorySyncStateStore — курсоры чтения и водяной знак выгрузки
lib/src/folder_transport.dart FolderTransport — обмен через общую папку: неизменяемые чанки, курсоры по узлам
```

Проверка: `dart test` из этой папки.
