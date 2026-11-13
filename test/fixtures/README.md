# Fixtures — табличные примеры синтаксиса Todoist

Парсеры (quick add, даты, повторения, фильтры) тестируются не вручную написанными
`expect`, а таблицами примеров: один JSON-файл → один тест, который прогоняет все строки.
Новая форма синтаксиса из help Todoist сначала попадает сюда, потом в код.

```
quick_add.json     "Купить молоко завтра в 17:00 #Дом @срочно p1"  → поля задачи
dates.json         "следующая пятница", "Jan 15", "через 3 дня"    → дата/время
recurrence.json    "каждый 3-й пт", "every! 3 days"                 → RRULE + from_completion
recurrence_next.json  срок с правилом + момент выполнения          → следующий срок
durations.json     "1ч 30м", "90", "1:30"                           → минуты своей длительности
filters.json       "today & p1 | overdue"                          → AST / список задач
```

Каждая запись несёт `source`: страница help Todoist или `"допущение О-57"`, если help молчит
(docs/OBLIGATIONS.md). В `recurrence_next.json`: `input` — срок {date, time?, tz?, rule}, `now` — момент
выполнения со смещением пояса срока (функция получает его стенное время), `postpone: true` — «Отложить»,
`"expect": { "ended": true }` — серия закончилась.

Формат записи:
```json
{
  "input": "Отчёт завтра в 17:00 #Работа p1",
  "lang": "ru",
  "now": "2026-01-15T10:00:00+03:00",
  "expect": {
    "title": "Отчёт",
    "due_date": "2026-01-16",
    "due_time": "17:00",
    "project": "Работа",
    "priority": 1
  }
}
```

- `now` обязателен: относительные даты («завтра») считаются от него, тест детерминирован. Цифры до
  смещения — стенное время, от которого считает разбор.
- `lang` — `ru` или `en`; язык влияет на разбор дат и ключевых слов.
- `expect` содержит только поля, которые проверяются; остальные не сравниваются.
- Ожидаемая ошибка: `"expect": { "error": { "position": 7 } }`.

Файлы разбора (lib/nlp):
- `dates.json` и `recurrence.json` — `input` целиком является датой: в названии ничего не остаётся,
  подсвечен весь `input`. `expect`: `date`, `time` (нет ключа — срок без времени), `rrule` и
  `from_completion` (нет — срок не повторяется), `no_date: true` — «без срока», `none: true` — дата
  не распознана и `input` остаётся названием. `"mode": "field"` — строка поля срока планировщика, а не
  названия задачи (там распознаётся и число без слова).
- `quick_add.json` — `expect.title` обязателен; остальное по ключам результата: `due` (`null` — срока
  нет; объект сравнивается по своим ключам, `time` и `rrule` — как выше), `project`, `section`,
  `labels`, `priority`, `deadline`, `duration` {amount, unit}, `description`, `no_date`, `highlights` —
  список {text, kind} по порядку в строке. `dismissed` — подстроки, подсветку которых пользователь
  отменил; `"smart_dates": false` — выключено «Умное распознавание дат».
- `durations.json` — строка поля длительности (lib/nlp/duration_text.dart); `lang` и `now` не нужны.
  `expect`: `minutes` или `none: true`; `in_range` — результат `Limits.durationInRange` (диапазон общий с
  быстрым добавлением и командами).
- `filters.json` — запрос фильтра (lib/nlp/filter_parser.dart) в момент `now` снимка
  `filter_workspace.json`; `lang` не нужен — ключевые слова обоих языков работают всегда. `expect`: `ast` — запись
  узлов каждой части через `,` (`toString` узлов lib/domain/filter_query.dart), `titles` — заголовки списков,
  `tasks` — видимые названия задач каждого списка по порядку (lib/domain/filter_engine.dart), `error` —
  `{kind, start, end}` (`FilterErrorKind`, участок запроса).
- `filter_workspace.json` — снимок для `filters.json`: проекты, разделы, метки и задачи с полями по умолчанию
  (порядок `a0`, P4, без срока); выполненная задача и задача архивного проекта не должны попадать ни в один список.
- Каждое правило из `recurrence.json` проходит `nextOccurrence` (lib/domain/recurrence.dart), а текст
  правила, разобранный обратно, даёт то же правило.

Полный справочник синтаксиса — `docs/TODOIST_SYNTAX.md`.
