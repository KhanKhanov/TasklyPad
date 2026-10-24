# data

drift: таблицы, DAO, миграции, репозитории. Таблицы сущностей — проекции op-log; прямые update/delete запрещены, все записи — через `Mutator` (см. docs/SYNC_DESIGN.md, «Инварианты реализации»).

- `app_database.dart` — `AppDatabase`, версия схемы и миграции; снимки схем — `drift_schemas/`. `app_database.steps.dart` — сгенерированные классы схем для шагов миграции (`drift_dev make-migrations`), руками не правится.
- `tables/` — `sync_tables.dart` (журнал, версии полей, конфликты, курсоры, локальные настройки) и `entity_tables.dart` (проекции).
- `projection/` — реестр проекторов: какое поле op в какие колонки ложится; имена полей — `entity_fields.dart`.
- `db_open.dart` и `db_backup.dart` — открытие базы в папке данных приложения и копия перед миграцией.
- `local_meta_dao.dart` — локальные настройки устройства (id узла, часы, версия проектора, папка синхронизации).
- `repositories/` — чтение для интерфейса и логики: `WorkspaceRepository` собирает из таблиц снимок `Workspace` (lib/domain) и пересобирает его при каждом изменении.
