---
name: help-m4-stage-end
description: Сверка конца M4 (2026-11-12) - хоткеи Upcoming (Home, Shift+стрелки), ответы help на допущения О-69
metadata:
  type: reference
---

Разобрано 2026-11-12 (WebFetch - пересказ):
- use-keyboard-shortcuts, раздел "Upcoming view": "Go to today" = Home; Next/previous week = Shift+→ / Shift+←. В код M4.6 не вошло,
  в TODOIST_PARITY §10 и plans/m4 не записано (grep). Там же "Keyboard-only (Windows)": Ctrl+N, Ctrl+1/2/3, Ctrl+4 проекты, Ctrl+5 метки/фильтры,
  Ctrl+Shift+N "новая задача вверху списка"; Ctrl+4/5, Ctrl+Home/End, Ctrl+E/Alt+E, Ctrl+Shift+N - не реализованы (не M4-пункты). Форматирования Ctrl+B/I в help нет.
- today-view: "Only tasks with a date appear in Today and Upcoming" (дедлайн-без-даты не показывать - подтверждено); "To see what you've finished
  today, turn on Completed tasks" (подтверждает допущение «выполненные сегодня»); Reschedule справа от Overdue, переносит все; счётчика в статье нет.
- upcoming-view: стрелки недели и кнопка Today справа вверху; "click Add task to create a task for that selected day"; про пустые дни, счётчик,
  группировку - молчит.
