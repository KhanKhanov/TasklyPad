# platform

Интерфейсы к платформе с фейками для тестов; реализации — в подпапках windows/ и android/. Экраны и логика знают только интерфейс, реализацию выбирает lib/app по платформе.

- `conflict_notifier.dart` — системное уведомление о конфликте синхронизации; `windows/toast_conflict_notifier.dart` — toast Windows (Android — О-35).
- `link_opener.dart` — открыть ссылку из названия или описания и список схем, которые можно открыть (`http`, `https`, `mailto`); `url_link_opener.dart` — пакет `url_launcher`, одна реализация для Windows и Android.
- `folder_picker.dart` — выбор папки синхронизации; `windows/file_selector_folder_picker.dart` — системный диалог Windows (Android, SAF — О-30).

Когда появятся остальные интеграции — docs/ROADMAP.md.
