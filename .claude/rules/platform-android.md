---
paths:
  - "android/**"
  - "lib/platform/android/**"
---
# Android

- minSdk 29, targetSdk — актуальный. Нативная часть на Kotlin, только через MethodChannel или Pigeon.
- Напоминания: точные будильники (SCHEDULE_EXACT_ALARM / USE_EXACT_ALARM как у календаря),
  каналы уведомлений «Напоминания» и «Ежедневный обзор»; BootReceiver перепланирует после перезагрузки;
  действия в уведомлении: «Завершить», «Отложить». Подсказка про оптимизацию батареи.
- Папка синхронизации — через SAF с persistable URI permission (Google Drive, Syncthing-папка и т.д.);
  фоновая синхронизация — WorkManager (периодически + при запуске) и при открытии приложения.
- Виджеты (home_widget): список «Сегодня» и кнопка quick add; app shortcuts; share-intent текста → quick add.
- Предиктивный «назад», edge-to-edge, Material 3; на телефоне стековая навигация.
