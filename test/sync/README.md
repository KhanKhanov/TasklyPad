# test/sync

Двухузловые сценарии синхронизации на уровне приложения: drift в памяти, временная папка на диске. Запуск: `flutter test test/sync`

- `folder_scenarios_test.dart` — сценарии «Инвариантов реализации» из `package:oplog_sync/testing.dart` на drift и `IoSyncFs`.
- `io_sync_fs_test.dart` — контракт `SyncFs` на настоящем диске, атомарность и очередь записи.
- `mutator_test.dart` — `Mutator`: правки, слияние срока, часы в одной транзакции с правкой.
- `sync_services_test.dart` — запуск: узел и копия базы, восстановление часов, reproject, «Входящие».
- `sync_lease_test.dart` — аренда синхронизации и `FolderSync`.
- `two_devices_test.dart` — «ПК + телефон» сквозным путём: `Mutator` → журнал → папка → другая база.
- `support/devices.dart` — `TestDevice`: база в памяти, управляемые часы, ядро данных через `startSync`.

Открытие настоящего файла базы (фоновый изолят drift) — `flutter test integration_test -d windows`.
