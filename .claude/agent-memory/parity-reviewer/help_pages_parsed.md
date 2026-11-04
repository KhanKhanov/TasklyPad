---
name: help-pages-parsed
description: Which Todoist help pages were already read (M2 / M2.2 scope facts), confirmed facts with source, and known gaps in help
metadata:
  type: reference
---

Разобрано 2026-10-24 для M2 (todoist.com/help/articles/...): introduction-to-sub-tasks-kMamDo (4 уровня, Ctrl+]/[),
introduction-to-projects-TLTjNftLM (дубликат, архив, лимиты), create-a-sub-project-in-todoist-aTA15C70 (3 уровня подпроектов),
introduction-to-sections-rOrK0aEn (до 20 разделов, удаление с задачами), introduction-to-labels-dSo2eE,
introduction-to-priorities-Wy82Jp, introduction-to-tasks, view-completed-tasks-in-todoist-J19h2s, keyboard-shortcuts-Wyovn2.

Разобрано 2026-10-26 для сверки M2.2 (WebFetch работает и на /ru/help/articles/<slug>-<id>):
- use-keyboard-shortcuts-in-todoist-Wyovn2: Shift+Delete = "Delete selected task(s)" (ru «Удалить выделенные задачи»), K/↑ и J/↓ = фокус
  вверх/вниз, Ctrl+↑/↓ = "Move to task above/below the task currently being edited", Shift+E подзадачи, `.` = «Действия в задаче»,
  t «Выбрать дату», l «Добавить метку», v «Перенести в…», y change priority, Enter «Открыть отображение задачи»,
  Ctrl+Enter в добавлении = сохранить и создать выше, S добавить раздел (таблица Projects), Shift+V раскладка, W меню проекта.
  Таймаут после `g` — в help нет. J/K как «соседняя задача в панели» — в help нет.
- usage-limits-in-todoist-e5rcSY: метка 60 симв., проект 120, раздел 2048, задача 500, описание 16383, фильтр 60/1024, 20 разделов,
  300 активных задач в проекте, 500 меток, 100 меток на задачу. Уровней вложенности там нет.
- introduction-to-labels: пробелы и длина не регламентированы в статье; спецсимволы разрешены; `%` — новый токен метки (`@` будет убран
  к концу 2026); удалённая метка снимается с активных задач, на выполненных остаётся, при возврате задачи создаётся заново с именем на
  момент выполнения. Нет: счётчика задач, содержимого экрана метки, порядка меток.
- developer.todoist.com/api/v1 (Projects): "Archive a project and its descendants"; unarchive — предки не возвращаются, проект становится
  корнем в конце списка; про потомков при unarchive — молчит. Секции Labels/Tasks страница WebFetch не отдаёт (обрезка).
- customize-views-in-todoist-AoHhBxFdZ: кнопка «Display» (ru «Отображение») есть у проекта, метки, фильтра, Сегодня, Предстоящее;
  у метки: раскладка, группировка, фильтр; «Completed tasks» для меток не упомянуто.
- use-sub-tasks-in-todoist-kMamDo: клик по счётчику подзадач сворачивает/раскрывает (Сегодня, Предстоящее, фильтры, метки, поиск);
  «Every task starts collapsed» там; формат счётчика не описан. Блог todoist-new-task-view: в задаче «small pie chart and completion
  number»; окно/боковая панель не описано; в help «chevron icons at the top» — предыдущая/следующая.
- search-for-tasks-by-date-FyFsAgMu: `overdue` — только даты: задачи, просроченные на часы, не включаются (срок со временем сегодня
  не «просрочен» по фильтру). Для цвета/блока «Просрочено» в Сегодня — данных нет.
- Русские термины из help: «Фильтры и метки», «Метки», «Изменить метку», «Удалить метку», «Цвет метки», «Добавить метку» (из задачи, моб.),
  «Подзадачи», «Добавить подзадачу», «Показать выполненные», «Показать выполненные подзадачи», «Скрыть выполненные подзадачи»,
  «Дублировать задачу», «Скопировать ссылку на задачу», «Удалить задачу», «Отображение» (кнопка; в скриншотах 2025 — «Просмотр»),
  «Выполненные задачи», «Только архивные проекты», «Вернуть из архива», «Добавить раздел», «Перенести в…».

Разобрано 2026-10-28 (тема, M2.3 коммит 4): change-color-themes-zD0N5K (en и /ru/). En: путь avatar > Settings > Theme; выбор темы;
"Appearance" Light/Dark/System (iOS: Auto, Android: Automatic); "Sync Theme option"; на web/desktop "Click Update to save"; на
iOS/Android кнопки сохранения нет. Темы: Todoist, Kale, Moonstone, Blueberry, Tangerine, Lavender, Raspberry (Free/Pro), у каждой
светлая и тёмная; Karma "Enlightenment" открывает тайную тему. RU-версия help устарела: нет «Внешний вид», «Светлый/Системный»,
«Обновить»; вместо них переключатель «Темная тема автоматически» и «Синхронизировать тему»; темы по-русски: Todoist, Темный, Лунный
камень, Оранжевый (бесплатные), Кейл, Голубика, Лавандовый, Малиновый (Pro). Пояснения под переключателем в help нет.
use-keyboard-shortcuts: `o p` "Open Productivity" (ru «Открыть раздел продуктивности»), `o s` "Open settings" («Открыть настройки»),
`o t` "Open theme" («Открыть тему»). Русский UI «Настройки» (скриншоты пользователя): разделы Аккаунт, Основное, Подписка, Тема, ...

Разобрано 2026-10-28 (удаление метки): introduction-to-labels-dSo2eE: удаление — "Select Delete label. Click Delete again to confirm."
(текст диалога не приведён); "they'll still appear on completed tasks"; при uncomplete метка создаётся заново, "name it had when the
task was completed"; цвет/избранное/порядок пересозданной метки НЕ описаны; массовое удаление ("Manage labels") только в мобильном
разделе. API v1 "Delete a personal label" (sync label_delete): cascade all/по умолчанию снимает метку с задач, none — остаётся как
shared; про выполненные молчит. Тексты диалога (en/ru) нигде в публичных источниках не найдены (WebSearch).

Разобрано 2026-10-29 (сверка конца M2; WebFetch на /ru/help/articles/<slug> работает):
- introduction-to-sub-tasks-kMamDo: "Todoist supports four indent levels: a sub-task is using indent level 1, and a
  sub-sub-sub-sub-task is using indent level 4" -> буквально 5 ярусов (корень + 4); у нас Limits.taskLevels=4 всего. CSV INDENT: 1 = верхний.
  Для проектов: "sub-projects on three indent levels" (create-a-sub-project-in-todoist-aTA15C70) — тоже двусмысленно. Живой Todoist не проверен.
- introduction-to-sections: архив -> задачи выполнены; "Archived sections are grayed out"; найти их — включить Completed tasks в
  Display; unarchive секции возвращает раздел, задачи остаются выполненными; ru меню: Редактировать, Перенести в..., Дублировать,
  Архивировать, Вернуть из архива, Удалить. Дубликат раздела "Copy of" с теми же задачами.
- introduction-to-projects (ru тоже): дубликат НЕ копирует Избранное, выполненные, архивные разделы, подпроекты, комментарии,
  напоминания; КОПИРУЕТ «Описание проекта», вид, сортировку/группировку/фильтр, активные разделы/задачи. У проекта есть описание
  (у нас поля нет). Архивные проекты (ru web/desktop, статья 115001281549): «Мои проекты» -> переключатель «Только архивные
  проекты»; мобильный: меню «Тип проекта» -> «Архивные проекты». ru-термины: Изменить/Редактировать, Архивировать, Дублировать.
- set-a-task-duration-L1kYkZv8d: максимум 24 ч; задаётся в планировщике: Time -> Duration (пресет ИЛИ ввести своё);
  "Removing a task's date doesn't remove its duration"; убрать — крестик у длительности; Pro/Business.
- introduction-to-deadlines: "No Deadline" (web/desktop/iOS), "No deadline" (Android); вид в списке и просрочка дедлайна в help не описаны.
- use-keyboard-shortcuts (en, 2026-10-29): `e` complete; "Undo only works while the confirmation message with Undo is visible.
  Click Undo or press Ctrl+Z"; Shift+Delete = delete selected; J/K = move focus (вместе со стрелками); "Shortcuts only work with
  QWERTY and QWERTZ layouts"; g a отчёты, g v Фильтры и метки.
- introduction-to-priorities: "Task menu: three-dot next to a task -> pick a level under Priority" (меню строки задачи содержит приоритет).
- customize-views ru: «Отображение», «Раскладка», «Сортировка», «Группировка», «Фильтр»; en кнопка "Display" (у нас en-ключ viewOptions = "View").
- Inbox: ни introduction-to-projects, ни use-the-inbox (360000028960) о запретах не говорят (WebFetch отдаёт навигацию).

Разобрано 2026-10-29 (сверка M2.4):
- en 115001281549: web/desktop — "Click My Projects ..., then turn on the 'Archived projects only' toggle"; три точки -> "Unarchive";
  mobile — Browse > Manage Projects > меню "Project type" -> "Archived projects". Delete: личный — открыть проект, ⋯, Delete (дважды);
  командный — сначала архив, затем toggle -> ⋯ -> Delete. ru-страница с опечатками «Вернуть их архива» (не копировать).
- sections (en+ru): архивные скрыты, пока не включено Display > Completed tasks; "Archived sections are grayed out, and tasks in these
  sections are shown as completed"; меню: Unarchive («Вернуть из архива»); Delete («Удалить») описан как общее действие и стирает
  активные и выполненные задачи без восстановления; порядок архивных относительно активных, «Add task» в архивном, клик-переименование — НЕ описаны.
- keyboard-shortcuts: "Undo only works while the confirmation message with the Undo button is on screen ... including after you move
  a task with drag and drop. Click Undo or press Cmd + Z (Ctrl + Z on Windows) before the message closes." Времени нет.
- Flutter: HardwareKeyboard вызывает ВСЕ handler'ы (не останавливается на первом true) — риск двойной отмены при замене тоста.

Разобрано 2026-10-31 (сверка M3.4, повторяющиеся; WebFetch отдаёт пересказ, не дословный текст — цитаты сверять осторожно):
- complete-a-task-with-a-recurring-date-dmI6SVqdP (en/ru): просроченная ежедневная, выполненная сегодня, уходит на завтра; перенесли и
  выполнили -> "calculated from the completion date", пропущенные вхождения пропадают; пример: yearly 10 дек 2025 просрочена, перенос на
  март 2026, выполнена -> 10 дек 2027 (не воспроизводится ни решением 10А, ни "возврат к расписанию"); Undo "shift back to whatever it was";
  дедлайн: повтор идёт дальше, дедлайн исчезает из вида после даты; "recurrence ends when you specify end date / complete forever";
  выполненное вхождение не открыть заново; "won't appear in project's completed list, every completion is logged in Reporting";
  ru: «Выполнить окончательно».
- reset-a-sub-task-in-todoist-V6SRBGPw0: 30 подзадач, "ignores sub-sub-tasks", порядок не сохраняется; выкл. -> дата сдвигается, подзадачи
  "won't re-add"; "Complete forever" = родитель и все подзадачи; умолчание НЕ названо (формулировка "set it as the default option" — вероятно
  выкл. по умолчанию; не подтверждено); пункт «Complete & reset sub-tasks» (ru «Выполнить и снова добавить подзадачи») — условие показа
  (при выкл. настройке?) не описано; ru: Настройки -> «Основное» -> «Дополнительно».
- set-a-recurring-due-date-YUYVJJAV: Postpone — "next future occurrence", просроченная "to tomorrow"; место в UI не названо; в Сегодня
  просроченные можно перетащить вниз = на завтра; конец серии — только "Set a date for when recurrence ends"; что после последнего
  вхождения — не описано; фиксированные правила "snap back" после выполнения, относительные — от перенесённой даты.

Разобрано 2026-11-01 (сверка M3.6, Quick Add; WebFetch отдаёт пересказ, цитаты сверять осторожно):
- use-task-quick-add-in-todoist-va4Lhpzz (en+ru): "Click Add task or press Q"; "+" в окне открывает действия и описание; ↓ — описание (web/desktop);
  настройка «Show description»; токены `#`, `/` (после проекта), `%` (`@` уйдёт к концу 2026), p1–p3, `!`, `{дедлайн}`; автодополнение: `#` и `%` —
  выбрать существующее или создать, `/` — только выбор; клик по слову делает его текстом. НЕ описано: проект по умолчанию, что после добавления,
  подсветка токенов, вставка строк. ru: «Быстрое добавление», «Добавить задачу».
- product-updates/a-cleaner-simpler-quick-add-june-29-PuIpiLmLh: действия появляются после начала ввода; по умолчанию показаны Проект и Дата
  ("Every task is best with a project and date"); проект в одной строке с остальными полями; `{` открывает выбор дедлайна; Shift+↓ — «Ещё»;
  описание скрыто, ↓ открывает.
- customize-quick-add-in-todoist-eqRRlZJNN: Настройки -> вкладка Quick Add; скрыть/показать приоритет, дату, дедлайн, исполнителя,
  напоминания, метки, местоположение, вложение; Проект скрыть нельзя; «Show description».
- add-or-manage-multiple-tasks-in-todoist-PcPoskdUp (en+ru): "Add X tasks?"; десктоп: Cancel/Add 1 task/Add X tasks; ru «Отмена», «Добавить 1 задачу»,
  «Добавить X задач»; моб.: «Добавить X задач» и «Вставить» без «Отмены»; для подзадач — «Добавить X задач»; Ctrl+Shift+V — вставка как текст.
  Применяется и в Add task, и в Quick Add (поле названия).
- turn-smart-date-recognition-on-or-off-63WfIr (205989121): Settings -> General (ru «Основное») -> "Smart date recognition" (ru «умное распознавание
  даты»; Android «Распознавать сроки в задачах автоматически»); web/desktop кнопка "Update" (ru help — «Изменить»), Android без подтверждения;
  выкл.: "you'll only be able to add or change a task's date or deadline by using the scheduler" (ru пересказ: «повторяющийся срок или дедлайн»);
  снять подсветку: клик, на десктопе "press Delete or Backspace after Todoist highlights" (ru help: «пробел или удалить» — перевод неточный).
- use-keyboard-shortcuts (en+ru): Ctrl+N (Windows) / Cmd+N "Open Task Quick Add" («Открыть быстрое добавление задачи») — в нашем §10 НЕТ;
  Enter сохранить и новая ниже; Shift+Enter сохранить правку и новая ниже; Ctrl+Enter сохранить и новая ВЫШЕ; глобально Ctrl+Space (Windows).

Разобрано 2026-11-01 (сверка M3.7, UI повторений; WebFetch — пересказ):
- introduction-to-recurring-dates-YUYVJJAV (en+ru): планировщик web — Date -> Repeat -> Daily/Weekly/Monthly/Yearly/Custom… (ru «Повторить»,
  «Пользовательский…»; моб. ru «Повтор», «Настроить…»); окно: Based on / Every / On / Ends (описание поля On в тексте НЕТ, только подпись к скриншоту);
  Save («Сохранить»); текст в поле даты меняет ВСЕ будущие вхождения; дата под полем (календарь) и Time — только следующее вхождение, "To change
  the time for all occurrences, type it into the date field"; снять повтор: web "dismiss icon at the bottom of the scheduler" (ru «значок удаления»),
  моб. "No Date"/«Без срока»; Postpone: "automatically move the task to its next future occurrence" (место в UI не названо); быстрых вариантов
  Today/Tomorrow/Weekend/Next week, поля "Type a date", Never/On date/after N в help нет; "everyday for 3 weeks" — в тексте есть, в окне нет.
- introduction-to-dates-and-time-q7VobO: поле "Type a date" (iOS), Time ("Time" web / "Add time" моб.) + Save, "No Date"; ru «Время», «Без срока»,
  «Следующая неделя» и «Выходные» — только в настройках; «На выходных» как пункт планировщика не найдено.
- use-the-task-view-to-manage-tasks-eDeRDO0C: меню ⋯ (web): Duplicate, Copy link, Add comments via email, View activity, Print, Open in new window
  (desktop), Delete; "Recurring-only items... when the task has a recurring date": Complete, Complete & reset sub-tasks, Complete forever
  (Android: "Complete task"). Условия "есть подзадачи" в этой статье нет; в reset-a-sub-task — "recurring parent task with sub-tasks".
- complete-a-task-with-a-recurring-date: "The deadline, however, will disappear from the task view after its specified date"; ru «исчезнет из
  отображения задачи после даты дедлайна»; пример: 15 февраля "deadline is removed from the task view". "Task view" = панель задачи (статья use-the-task-view).
- reset-a-sub-task (ru): «Добавлять подзадачи снова» — web/Windows, iOS, Android («Отметьте» — галочка); «Сбросить подзадачи» — только блок
  iPadOS (по порядку вкладок, не подтверждено); en везде "Reset sub-tasks"; web: Settings > General > Advanced > «Изменить»/Update; умолчание
  не названо; "if reset is off, date moves, sub-tasks aren't re-added"; Android: «Выполнить и снова добавить подзадачи» — в разделе параметров повторяющейся задачи.
- ru-подписи окна Based on/Every/On/Ends в help НЕ найдены (WebSearch тоже).

Разобрано 2026-11-01 (сверка конца M3; WebFetch — пересказ):
- use-keyboard-shortcuts, раздел "Manage tasks" (Web/macOS/Windows): "Complete and archive recurring task" = Shift + Click по чекбоксу (в M3 не
  реализовано, в §10 не записано); Windows: "Edit task" = Ctrl+E и Alt+E (у нас тест "Alt+E — не хоткей"); Enter/Shift+Enter/Ctrl+Enter в редакторе:
  "Save a newly created task and create a new one below" / "Save changes to existing and create new below" / "...create new task above".
- introduction-to-recurring-dates: "If you type a new date directly into the task name, you'll replace the recurring date entirely and lose the
  recurrence" => даты разбираются и при правке названия СУЩЕСТВУЮЩЕЙ задачи (у нас task_dialog `rename` без разбора; в plans/m3 это ошибочно в "Не
  найдено в help"). "Time option only changes the time of the next occurrence". Deadline: "you'll always see its deadline, even when it shifts to the
  next date" (против "disappear from the task view after its specified date" в complete-a-task... — согласуется как "до даты дедлайна").
- complete-a-task-with-a-recurring-date: Undo pop-up "in the bottom-left"; выполненные вхождения видны в Today/Upcoming при Completed tasks и в календаре.
- introduction-to-dates-and-time: цвета срока (фиксированные): красный просрочено, зелёный сегодня до времени, коричневый завтра, фиолетовый 2–7 дней,
  без цвета 8+; "doesn't recognize military time like 1300" (но в таблицах recurring есть "Fri at 1900"); Quick Add принимает "no date" в Today/Upcoming;
  scheduler web: Date -> календарь + поле, Time + Save; кнопок Today/Tomorrow/... в статье нет (только как ввод).
- set-a-task-duration: "with or without a date and time"; пример "Every Monday at 16:00 for 1h15m"; многодневное — "every day starting Aug 25 for 5 days".
- add-or-manage-multiple-tasks: Ctrl+Shift+V (Windows) — вставка без форматирования; про отступы/маркеры/нумерацию в строках и даты в строках статья молчит.

Разобрано 2026-11-02 (сверка fix M3.8; WebFetch — пересказ):
- troubleshoot-syncing-issues-in-todoist-d6dDzzpF (URL с /help/todoist/troubleshooting/): web/Windows — "Click your avatar at the top-left" -> "Sync";
  iOS Browse -> шестерёнка -> Sync; Android Browse -> шестерёнка -> About -> "Sync last completed". use-keyboard-shortcuts: "Manually sync" = Ctrl+S
  (в блоке "only with a mobile keyboard"), "Open Settings" = Ctrl+, там же; `o s`; J/↓ и K/↑ "Move focus down/up" — поведение без фокуса не описано.
- change-languages-in-todoist-EJZMow: "If the selected language isn't available yet, Smart Date recognition will default to English";
  "a date typed in a different language than your app's language won't be recognized"; Czech/Turkish не поддерживаются.
- introduction-to-deadlines-in-todoist-uMqbSLM6U: web — поле дедлайна сверху + календарь, Enter подтверждает, "Select No Deadline to remove";
  быстрые варианты Today/Tomorrow/Next week — только в мобильных шагах. Recurring: "date", не дедлайн.
- recurring: "Every hour starting from now"; Time — "only changes the time of the next occurrence"; снятие времени у часового правила НЕ описано.
  dates-and-time: снятие времени не описано, "Сегодня" по часам устройства/поясу не описано, полночь при открытом окне не описана.

Разобрано 2026-11-02 (подписи карточки «Конфликты», повторная сверка): reset-a-sub-task ru — «Добавлять подзадачи снова»: web/macOS/Windows
(переключатель), iOS (переключатель), Android (флажок); «Сбросить подзадачи» — только iPadOS (+ вводная фраза статьи); пересказ WebFetch, платформы
определены по порядку блоков. smart-date-recognition (en+ru): значения Вкл/Выкл/On/Off как подписи НЕ используются; глаголы "Turn on/off" (ru
«Включите» / «Выключите», на моб. «Отключите»); слова "toggle" нет; Android выкл.: "Detect due dates in tasks automatically" (ru «Распознавать
сроки в задачах автоматически»).

Разобрано 2026-11-02 (сверка 1А–3А M3.8; WebFetch — пересказ): dates-and-time, таблица цветов: красный "Overdue tasks", зелёный "scheduled today but
haven't gone past the due time", коричневый завтра, фиолетовый "next 2-7 days", без цвета "8 days and onwards"; "fixed and can't be customized";
о дедлайне, выполненных, окне задачи, видах — молчит. recurring-dates: "you'll replace the recurring date entirely and lose the recurrence" —
про метки/приоритет/проект при правке существующей задачи молчит. smart-date-recognition: про правку названия существующей задачи молчит.
use-keyboard-shortcuts, "Manage tasks": "Complete and archive recurring task" = Shift+Click the checkbox; в той же таблице "Select multiple
tasks" = Ctrl/Shift+Click (по строке); Shift+Click по чекбоксу обычной задачи — не описан.

Разобрано 2026-11-02 (сверка О-65, «Время» у повторяющейся; WebFetch — пересказ): recurring-dates: "Setting a time with the Time option only
changes the time of the next occurrence"; "After you complete it, the task returns to its usual recurring date and time"; "Both actions only
change the next occurrence – the underlying recurring schedule stays intact" (про Postpone/перенос); "every!: next date is calculated from the day
you complete". Help НЕ описывает: «убрать время» (кроме "No Date" на моб. — снять весь срок), время у `every hour` при смене Time, время
после Postpone, что показывает планировщик после смены времени (текст правила/время серии). complete-a-task-with-a-recurring-date про Postpone,
часовые и время при выполнении молчит. В нашем коде ruleText (lib/nlp/rule_text.dart) не содержит времени — время серии после «Времени» нигде не видно.

Разобрано 2026-11-03 (сверка О-41, имена меток у выполненных; WebFetch — пересказ): introduction-to-labels-dSo2eE: единственная фраза про
переименование — для ОБЩИХ меток: "Their changes will apply to all the active tasks tagged with that label."; для личной метки и выполненных
задач при переименовании help молчит. "they'll still appear on completed tasks" (удалённая метка); "This label will have the name it had when
the task was completed."; регистр и дубли имён не описаны, "no exact match" — только про общие. API: Task.labels = list[str] (Python SDK
models.py, без docstring) — метки на задаче хранятся ИМЕНАМИ; страница api/v1 обрезана до раздела Labels (offset 100000–140000 тоже не дают).
Вывод-вероятность (не подтверждено): раз метки по имени, переименование переписывает имена на активных; выполненные хранят старую строку, и при
возврате старого имени живой метки нет -> по логике help создаётся метка со СТАРЫМ именем (допущение 4 нашего кода, оставляющее живую
переименованную метку, вероятно расходится).

Разобрано 2026-11-03 (до M4.4, сортировка/группировка, Сегодня/Предстоящее; WebFetch — пересказ, кавычки инструмента сверять):
- sort-or-group-tasks-in-todoist-WFWD0hrb (en; тот же текст в 360017135159): группировка — Date, Date added, Deadline, Priority, Label (+ project/assignee/
  workspace в тексте); сортировка — Manual, Name, Date, Date added, Deadline, Priority; "None" / "Manual" / "Reset all" (ru «Сбросить все»); меню направления
  зовётся "Ordering menu" (web/Android) / "Direction menu" (iOS), названия самих пунктов asc/desc НЕ приведены. Подзадачи: "When you sort a project, the sort
  applies to sub-tasks too, in both list and board layouts" (по имени — подзадачи каждого родителя тоже по алфавиту); "When you group tasks, sub-tasks aren't
  shown under their parent task", каждая — в группе по СВОИМ данным (дата/приоритет); "The task view always shows sub-tasks in their manual order". ПРОТИВОРЕЧИЕ: ru
  (www.todoist.com/ru/help/todoist/features/...) в пересказе — «подзадачи сохраняют исходный порядок при группировке и сортировке» — вероятно старая версия. Разделы:
  "Tasks are sorted within their own sections" (P1 последнего раздела — вверху раздела, не проекта). Имя: "ignores logographs" и спецсимволы (å ä ö æ ø); регистр НЕ
  описан. Задачи без даты/дедлайна, порядок групп, метки (несколько на задаче), порядок внутри группы, замена разделов при группировке — НЕ описаны.
  Календарная раскладка: сортировка/группировка недоступны. Группировка выключает перетаскивание.
- default-sorting-order-in-todoist-mqmgerY7: проекты — "in the order in which they were added", внутри раздела; Сегодня/Предстоящее — Date and time (or deadline,
  if no date) → Priority → Deadline → Manual ordering → Task creation date and time; метки и фильтры без дат — Priority → Date and time → Deadline → Project order →
  Task order within project; фильтры с датами — как Сегодня; "Overdue tasks can't be manually sorted" (порядка просроченных нет); общее: критерии по возрастанию,
  кроме Priority (P1→P4); разворот меняет только первичный критерий, вторичные — по умолчанию; "When you sort by Date, tasks without a date appear at the bottom"
  в asc и вверху в desc. Подзадачи в статье не упомянуты.
- plan-your-day-with-the-today-view-UVUXaiSs: "Only tasks with a date appear in Today and Upcoming"; про подзадачи, архивные проекты, дедлайн-без-даты,
  порядок просроченных — молчит; "To see what you've finished today, turn on Completed tasks"; "Postponing an overdue recurring task always moves it to tomorrow";
  перетаскивание вниз = на завтра требует выключенных сортировки/группировки.
- plan-your-week-with-the-upcoming-view-OKOg1mR8: "up to two years in the future"; в list/board — только ближайшее вхождение; тумблер "Future occurrences" (Display) —
  только календарь (Pro); дедлайн-без-даты — только в боковой панели Plan календаря (до 7 дней); Reschedule в метках/фильтрах — только при группировке по Date.
- use-sub-tasks-in-todoist-kMamDo: "If you schedule both the parent task and sub-task to today, they'll both appear in the Today view with the same indent level"
  (родитель и подзадача на сегодня — одинаковый отступ); раскрытие подзадач в Today/Upcoming/фильтрах/метках/поиске; перетаскивание отступа — только без сортировки/группировки;
  подзадача с другой датой, чем у родителя — НЕ описано.
- customize-views AoHhBxFdZ/4407240443282: группировка — "project, label, filter, Inbox, or Today view"; про Upcoming, порядок групп, "No date" — молчит.
- API v1 view_options: view_type today|upcoming|assigned_to_me|project|label|filter|workspace_filter; grouped_by assignee|added_date|due_date|deadline|label|priority|project|
  workspace; sorted_by alphabetically|assignee|added_date|due_date|deadline|label|priority|project|workspace|manual; sort_order asc|desc; show_completed_tasks bool;
  view_mode list|board|calendar|table. day_orders — "Deprecated", замена user_item_orders (order_key на задачу); схема day_orders в видимой части страницы обрезана.

Разобрано 2026-11-03 (сверка M4.5, «Отображение»; WebFetch — пересказ, цитаты ≤125 симв.):
- sort-or-group (en): "Manual sorting is only available in projects and in the Today and Upcoming views."; "Filter and label views always use their
  default sorting order and can't be manually reordered" (буквально — у метки/фильтра порядок вида; можно ли выбрать Name/Date/Priority — НЕ сказано;
  customize-views про сортировку метки молчит, про группировку метки — "project, label, filter, Inbox, or Today view"); меню направления: iOS "Ordering
  menu", Android "Direction menu", скрывается при Manual; web-шаги направление не описывают; ru: «Меню упорядочивания» (web/macOS, по пересказу) / «Меню
  направления» (моб.); "Reset all": "remove all sorting and grouping options" (ru «Сбросить все»), про Completed tasks молчит; индикатор «Display: N» в help НЕТ
  (только "applied options are shown at the top"); "Add task" внизу каждой группы; "doesn't appear when tasks are grouped by assignee, workspace, or date
  added" и нет у «Overdue» и групп без значения (Android: в list-раскладке в группы добавлять нельзя); календарь: сортировки/группировки нет.
  ru-списки: группировка Срок / Дата добавления / Дедлайн / Приоритет / Метка; сортировка Вручную («Вручную (по умолчанию)») / Название / Срок / Дата
  добавления / Дедлайн / Приоритет; «Нет (по умолчанию)» у группировки. У нас ru «Имя» и «Дата» — расходятся с ru help («Название», «Срок»).
- use-keyboard-shortcuts «Sort tasks» (Web/macOS/Windows): D "Sort by date", P "Sort by priority", N "Sort by name", R "Sort by assignee"; iOS Option+буква;
  set или toggle и направление — НЕ описано.
- view-completed-tasks: Display -> "Completed tasks" есть у проекта, Today, Upcoming (web/desktop); у меток "No separate toggle" (только группировка по метке);
  фильтры — завершённые в запрос не включить; Reset all и «запоминается ли на вид» — не описано.
- default-sorting-order: у Today/Upcoming "You can turn on Manual sorting to freely reorder" — Manual отдельный выбор, умолчание — умная сортировка; проекты — "order in
  which they were added" (не названо Manual; в ru sort-or-group «Вручную (по умолчанию)»).
- introduction-to-projects (дубликат): копируются "Chosen view", "Chosen sorting, grouping, or filtering options"; не копируются "Completed tasks and archived sections"
  (про настройку «Выполненные задачи» — молчит). customize-views: Reset all снимает оранжевую точку у общего проекта (возврат к сохранённому виду, Save for everyone).
- Upcoming: help (sort-or-group, upcoming) НЕ говорит, что группировки/сортировки там нет; "нет группировки у Upcoming" в нашем плане — вывод, не цитата.

**Help НЕ говорит:** что с подзадачами при завершении/удалении родителя; ограничения Входящих; список цветов (hex);
счётчик «2/5»; что с подпроектами при разархивации; секунды тоста Undo; задачи архивного проекта (только просмотр или нет);
русские названия цветов; число задач у метки; подтверждение удаления по Shift+Delete; окно/панель задачи; порядок меток.
Цвета: SDK colors.ts (raw.githubusercontent.com/Doist/todoist-sdk-typescript/main/src/utils/colors.ts) — официальный список hex.
**Why:** не тратить время на повторный поиск. **How to apply:** помечать «не подтверждено».
WebFetch на угаданные ID статей возвращает навигацию — искать URL через WebSearch.
