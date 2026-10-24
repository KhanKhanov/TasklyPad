# sync

Адаптеры к packages/oplog_sync: DriftOpStore, SyncFs для Windows (dart:io) и Android (SAF), Mutator — единственная точка записи данных.

- `sync_services.dart` — `startSync`: сборка ядра данных при запуске (reproject, узел, часы, движок, `Mutator`, «Входящие»).
- `mutator.dart` — создать / изменить / удалить / восстановить / выбрать вариант конфликта; слияние поля-объекта `due`.
- `drift_op_store.dart`, `drift_sync_state_store.dart` — журнал, проекции и курсоры в базе.
- `io_sync_fs.dart` — папка синхронизации на диске (Windows); SAF для Android — в M6.
- `folder_sync.dart`, `sync_lease.dart` — один проход синхронизации под арендой (один синхронизатор на базу).
- `node_identity.dart` — id узла и метка вне базы: копия базы получает новый id.
