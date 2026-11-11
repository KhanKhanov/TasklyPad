---
name: help-manual-review-nov11
description: Факты help по замечаниям ручной проверки 2026-11-11 (redo, назад/вперёд, Add section, оранжевая точка Display, виджеты, show completed sub-tasks)
metadata:
  type: reference
---

Разобрано 2026-11-11 (WebFetch — пересказ):
- use-keyboard-shortcuts: redo НЕТ (только Ctrl+Z, пока виден тост); Windows "Alt + ←/→" назад/вперёд (macOS Cmd+[ / Cmd+]); Esc = "Dismiss/Cancel", в панели
  задачи "Close task view"; глобально Ctrl+Space "Open Quick Add" (Win), работает при свёрнутом приложении; кнопки «назад» мышью в help нет.
- use-sub-tasks / use-the-task-view: "Click Show completed" в панели; запоминание переключателя НЕ описано; сжатая анимация панели НЕ описана;
  при перетаскивании отступа вид (призрак) НЕ описан, порог сдвига не дан — "Drag it again from left to right to adjust its sub-task level".
- introduction-to-sections: "Add section" — при наведении к верху/низу списка ("Bring your cursor over to the top or bottom of the task list"), красная
  надпись на всю ширину; не появляется при группировке. Между задачами — в help не сказано.
- customize-views: у Display "an orange dot" при отличии от сохранённого вида (контекст — общие проекты, исчезает по "Save for everyone"/"Reset all").
  Для личных проектов точка/цифра не описаны.
- today-view: про перетаскивание в умолчанию и предупреждение — молчит; upcoming: про бросок на дату в недельной полосе — молчит (мобильно: touch and hold на дате
  в week picker = добавить задачу).
- Uncomplete: позиция возврата НЕ описана (help complete-or-uncomplete-a-task); подзадачу возврат — родитель тоже возвращается; завершённые остаются в своём разделе.
- Сверка M4.10a (2026-11-11, по коду): Alt+←/→ в shell_keys совпадает с help; состав и порядок меню строки (Редактировать, Срок, Приоритет, Перенести в…, Метки,
  Дублировать, Удалить) прежние; «Новый раздел» (9Б) — в ru help только «Добавить раздел»; расхождений вне решений пользователя не найдено, кроме мелочей в отчёте.
- Quick Add (va4Lhpzz) и troubleshoot-quick-add-issues-KRZBCdvWO: положение окна не описано; Windows-виджета в help нет; Android: виджеты "Add task shortcut"
  (открывает Quick Add), "Task list", Productivity (в 206408179 / 632pZA), новее — Ramble (AI, вне scope).
