---
name: m5-filters-search-help
description: Факты help Todoist для M5 (язык фильтров, сохранённые фильтры, поиск, Quick Find Ctrl+K), сверка 2026-11-13, с пробелами и расхождениями с TODOIST_SYNTAX §4
metadata:
  type: reference
---

Разобрано 2026-11-13 (WebFetch — пересказ, цитаты ≤15 слов сверять осторожно).
Страницы: introduction-to-filters-V98wIH (en + /ru/help/articles/...), introduction-to-search-fAfiDSAp, usage-limits-in-todoist-e5rcSY,
add-a-project-label-or-filter-to-favorites-in-todoist-zezDfvSK, search-for-tasks-by-date-FyFsAgMu, default-sorting-order-in-todoist-mqmgerY7,
use-keyboard-shortcuts-in-todoist-Wyovn2, customize-the-sidebar-in-todoist-S9JLTYqZV, inspiration/todoist-command-menu-keyboard-shortcuts.
Все под https://www.todoist.com/help/articles/<slug> (работает и /help/todoist/features/<slug>).

## 1. Язык фильтров (introduction-to-filters)
Символы: `|` OR, `&` AND, `!` NOT, `%` метка, `()` группировка, `,` — "separate lists", `\` — экранирование. Пример: `(today | overdue) & #Work`.
- Текст: `search: Meeting`, `search: Meeting & today`, `search: send email`, `search: http`.
- Подзадачи: `subtask`, `!subtask` (только родительские).
- Даты: `date: Jan 3`, `date before: May 5`, `date after: May 5`, `date before: +4 hours`, `date before: next week`, `date before: sat`,
  `date before: first day`, `date: yesterday, today`, `no date`, `!no date`, `!no time`, `date: today & date before: today at 2pm`,
  `overdue` (= `over due` = `od`), `overdue & !no time`.
- Дедлайн: `no deadline`, `!no deadline`, `deadline: today`, `deadline before: today`, `deadline after: yesterday & deadline before: in 7 days`.
- Due (дата ИЛИ дедлайн, search-for-tasks-by-date: "`due before/after` covers either a date or a deadline"): `due before: May 5`, `due after: May 5`,
  `due: yesterday, today`, `due before: next week`, `5 days` / `next 5 days`, `recurring`, `!recurring`, `no time & !recurring`.
  `date` и `due` НЕ эквивалентны (у нас в §4 — "эквивалентны": неверно).
- Приоритет: `p1`..`p4`, `No priority`; "p4 and No priority are equivalent".
- Метки: `%email`, `no labels`; `@` пока работает, уберут к концу 2026.
- Проекты: `#Work`, `##Work` (с подпроектами), `##School & !#Science`.
- Разделы: `/Meetings` (во всех проектах), `#Work & /Meetings`, `!/*` (без раздела), `!/* & !#Inbox`. Ключевого слова `no section` в help НЕТ (у нас в §4 есть).
- Подстановка `*`: `%home*`, `#*Work`, `/*Work*`, `#Welcome *` (замена эмодзи), `assigned to: m* smith`.
- Создано: `created: Jan 3 2023`, `created before: -365 days`, `created after: -365 days`, `created: today`.
- Прочее: `view all` ("all active tasks"), `uncompletable` (в нашем §4 нет).
- Вне scope: `assigned to:`, `assigned by:`, `assigned`, `!assigned`, `shared`, `added by: me|<имя>`, `workspace:`, `##<папка>`.
- Не поддерживается (help): фильтры по комментариям, выполненным задачам, "assigned to: nobody" (→ `!assigned`). "you can only filter for active tasks".
- Встроенные Today, Upcoming, Priority — "can't be edited with filter queries".
- Пробелы в именах: `#Shopping\ list` (экранирование `\`), кавычек в help нет — наш `#"Два слова"` для фильтров не подтверждён.
- Результат считается при открытии: "Todoist calculates a filter's results when you open it"; относительные даты не добавляют новые задачи, пока открыт.
- Переименование проекта ломает фильтры, где старое имя: "update them manually". Сообщений об ошибке синтаксиса, регистра, несуществующего
  проекта/метки в help НЕТ. Приоритет операторов: только "() filters for queries inside a parenthesis first"; & над | не описан.
- Дата-запросы (search-for-tasks-by-date): `overdue` — "only refers to dates" (просрочка на часы не входит); `(today | overdue)` — overdue отдельно от today
  (т.е. `today` НЕ включает просроченные); `14 days` = "next 14 days"; `-5 days` = предыдущие 5 дней; `tuesday` = ближайший вторник;
  `due before: sat`; `today at 11am`; `date after: in 90 days`. НЕ описано: включает ли `N days` сегодня/границы, `date: today` (но есть в intro-to-filters).

### Русские ключевые слова (ru-версия introduction-to-filters, пересказ WebFetch)
Локализованные слова ЕСТЬ в ru help: `поиск:`; `срок:`, `срок до:`, `срок после:` (= `date`/`due` в ru-тексте перепутаны: заголовок «Срок» и «К выполнению»),
`без даты`, `без времени`, `просрочено` / `просроченные`, `сегодня`, `завтра`, `вчера`; `дедлайн:`, `дедлайн до:`, `дедлайн после:`, `без дедлайна`;
`к выполнению:` (+ до/после) — вероятно перевод `due`; `без приоритета`; `без меток`; `подзадача`; `создано:`, `создано до:`, `создано после:`;
`повторяющиеся`; `показать все`; `незавершаемые` (uncompletable); `добавил:`; `назначено для:`, `назначил:`, `назначено`, `общие`; `рабочее пространство:`.
Единицы: `-365 дней`, `+4 часа`, `через 7 дней`, `следующие 5 дней`, `следующая неделя`. `p1`..`p4` не переводятся. `%`, `#`, `##`, `/`, `!/*` как есть.
Примеры ru: `сегодня & %email`, `(сегодня | просрочено) & #Работа`, `#Работа & /Встречи`, `!подзадача`, `p1 & просрочено, p4 & сегодня`, `!без даты & !без времени`.
Оговорка: пересказ инструмента; точную форму `срок до:` vs `к выполнению до:` сверить прямым чтением страницы/живым Todoist. Нет подтверждения, что ru-слова
работают при английском интерфейсе (в change-languages: Smart date — только язык приложения). Нет `no section` по-русски (есть `!/*`).

## 2. Сохранённые фильтры
- Создание (web/desktop): «Фильтры и метки» → значок «Добавить» рядом с «Фильтры» → имя, цвет (по желанию), запрос → «Добавить». Моб.: ещё «Избранное».
  ru-поля: «Назовите фильтр», «Запрос», «Описание», «Цвет», «Избранное».
- Описание фильтра — НОВОЕ: добавляется только у существующего ("Add a description" под именем, затем Save); показывается под именем над результатами.
  (в нашем TODOIST_PARITY не отмечено).
- Правка: карандаш рядом с именем (web); моб. ⋯ → «Изменить фильтр». Удаление: правый клик или ⋯ → «Удалить» (web); моб. «Удалить фильтр». Подтверждение — не описано.
- Порядок: на моб. перетаскиванием; web в intro-to-filters не описан, но favorites-страница: "Drag a filter to a new position in that list" (тот же способ для всех платформ).
- Избранное: web «Фильтры и метки» → сердечко у фильтра; удалить — правый клик в «Избранном» → "Remove from favorites". Порядок избранного = порядок списка;
  категории в избранном всегда: проекты, метки, фильтры.
- Лимиты (usage-limits): имя фильтра 60, запрос 1024; число: Beginner 3, Pro 150 (наше «150» верно, 3 — тарифный, вне scope). Комментарий 15000 симв., 1 вложение (5 МБ Beginner/100 МБ Business).
- Раскладки результата: список, доска, календарь (Pro). «Отображение» у фильтра — customize-views (см. help_pages_parsed).
- Запятая: "p1 & overdue, p4 & today displays two separate lists". Заголовки секций/имена списков — НЕ описаны.
- Порядок по умолчанию (default-sorting-order): фильтры без дат — Priority → Date and time → Deadline → Project order → Task order within project;
  фильтры с датами — Date and time (or deadline, if no date) → Priority → Deadline → Manual → Creation date; "Overdue tasks can't be manually sorted".
  "Filter and label views always use their default sorting order and can't be manually reordered" (sort-or-group).
- Дубликат фильтра, предпросмотр результата при редактировании, добавление задачи из фильтра (какие значения ставятся), счётчик у фильтра — в help НЕТ.
  Поиск по help (add task in filter view) ничего не дал.
- API v1: Filter-секции Sync (поля, order_key, "Update multiple filter orders") страница WebFetch не отдаёт (обрезка на ~150000 симв.). Из поиска (не прямой чтение):
  filter-reorder команда deprecated, порядок — order_key через filter_update; Get Tasks By Filter не поддерживает запятую `,` (из пересказа поисковика — не подтверждено прямым чтением).

## 3. Поиск (introduction-to-search-fAfiDSAp)
- Открыть: web/desktop «Поиск» в сайдбаре или `/`; моб. «Поиск» внизу. Ни `f`, ни Ctrl+F на странице нет.
- Ищется: tasks, task descriptions, comments, projects, sections, labels, filters (фильтры в выдаче — точно на моб.; на web статья не уточняет).
- Выдача: сначала блок "Top" лучших совпадений; вкладки по типам. До ввода: недавно просмотренные задачи/проекты/виды и подсказки хоткеев.
  Недавние запросы: "up to five recent keywords", можно очистить все или по одному.
- Выполненные: "Search completed tasks" внизу выдачи; активные идут первыми; архивные проекты не ищутся; частичные слова выполненные НЕ находят;
  только имена и описания (не метки).
- Операторы фильтров работают в поиске (`today & p1`, `overdue`, `#Work`, `/Bills`, `created after:` …); `sky*` — подстановка по словам; "Pro and Business users can save useful searches as filters".
- Хоткеи (use-keyboard-shortcuts): `/` или `F` = "Search" (web/macOS/Windows); Ctrl+F = "Open Search" ТОЛЬКО в блоке "mobile keyboard"; `Ctrl+K` = "Open Quick Find"
  (Windows, общие); `g v` = "Open Filters & Labels"; Ctrl+Shift+F = "Create a new filter" (блок mobile keyboard); Alt+P = новый проект (общие, Windows).
  Строк "go to filter" нет.

## 4. Командное меню Ctrl+K
- В help называется Quick Find ("Open Quick Find"); в блоге Todoist — command menu: "central hub of actions", навигация, добавление и правка задач без мыши;
  примеры в скриншоте: Quick Add, Go to home view, Go to Inbox, Go to Today. Категорий, способа поиска в меню, полного состава — НЕ описаны.
  `/` — поиск, `Ctrl+K` — команды (раздельно); `?` — окно хоткеев (39 штук по блогу). customize-the-sidebar: скрытый вид открывается через Ctrl+K → выбрать вид.
  Поиск (`/`) и командное меню — разные окна.

## 5. По платформам
- Ctrl+F и Ctrl+Shift+F (поиск, новый фильтр) — блок "mobile keyboard" (клавиатура у телефона/планшета), не desktop. Ctrl+K — только web/desktop. Карандаш/правый клик — web.
  Порядок избранного/сердечко: web — сердечко в «Фильтры и метки»; моб. — свайп в Browse; фильтр как вкладка навбара — iOS/Android. Calendar layout — Pro.

## 6. НЕ найдено в help (будущие допущения)
Регистр ключевых слов и имён; кавычки (только `\`); приоритет `&` над `|`; сообщение и позиция ошибки синтаксиса; несуществующий проект/метка/раздел;
`no section` как слово; включает ли `today` просроченное (по `(today | overdue)` — нет); границы `N days`; заголовки секций при запятой; дубликат фильтра;
предпросмотр при правке; добавление задачи из фильтра (проект/срок по умолчанию); счётчик у фильтра; подтверждение удаления; состав и поиск в Ctrl+K;
сортировка выдачи поиска; поиск по выполненным разделам/фильтрам; недавние: что именно хранится (ключевые слова, до 5).
