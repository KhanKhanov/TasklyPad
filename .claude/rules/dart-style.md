---
paths:
  - "**/*.dart"
---
# Стиль Dart

- `dart format`; analysis_options: flutter_lints + strict-casts, strict-inference, strict-raw-types.
- Нет `dynamic` в публичных API. Модели — freezed; варианты — `sealed` + исчерпывающий `switch`.
- Riverpod: только `@riverpod`-кодоген; бизнес-логика в Notifier и репозиториях, не в `StateProvider`.
- Ошибки не глотать: `Result<T>` из core/result.dart или rethrow с контекстом; логировать через `logger`, не `print`.
- В domain/data/sync запрещены `DateTime.now()` и случайные ID напрямую — только инжектируемые `Clock` и `IdGenerator`.
- Тексты UI — через l10n (ARB: ru по умолчанию, en). Хардкод строк в виджетах запрещён.
- Файл виджета ≤ 300 строк; выделяй подвиджеты. Имена файлов snake_case, провайдеры `xxxProvider`, DAO `XxxDao`.
- Публичные классы domain/sync/nlp — с кратким `///` doc-комментарием по-русски.
