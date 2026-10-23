---
paths:
  - "windows/**"
  - "lib/platform/windows/**"
---
# Windows

- Минимум Windows 10 x64. Сборка: Visual Studio, workload «Desktop development with C++».
  Дистрибуция: MSIX (пакет msix) с self-signed сертификатом для личного использования.
- Трей (tray_manager): закрытие окна = свернуть в трей (настройка); пункты «Быстрое добавление», «Открыть», «Выход».
- Глобальный хоткей quick add (hotkey_manager), по умолчанию Ctrl+Alt+A, настраиваемый.
- Уведомления: toast через flutter_local_notifications; повторяющихся нет (`periodicallyShow`
  бросает `UnsupportedError`) — планировщик напоминаний в lib/features/reminders сам ставит следующее
  одноразовое. Действия: «Завершить», «Отложить 10 мин». Без package identity (не-MSIX сборка,
  `flutter run`) `cancel()` ничего не делает и `getActiveNotifications()` пуст — в отладке это
  норма, не баг; проверять отмену только в MSIX-сборке.
- Автозапуск — ключ HKCU\...\Run, только по явной настройке. Запоминать размер и положение окна.
- Макет desktop (≥ 900 px): сайдбар · список · панель задачи. Клавиатура — приоритет, хоткеи как в Todoist.
