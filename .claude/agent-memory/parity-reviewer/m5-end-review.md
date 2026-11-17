---
name: m5-end-review
description: Сверка конца этапа M5 17.11.2026 — подтверждённые help факты ru/en фильтров, пробелы fixtures, спорные допущения
metadata:
  type: reference
---

Перечитано 17.11.2026 (WebFetch ru+en introduction-to-filters-V98wIH).
- ru help ПОДТВЕРЖДАЕТ: `срок:` / `срок до:` / `срок после:` (= date), `к выполнению:` (= due; в примере «следующая неделя»), `дедлайн:`, `создано:`,
  `без даты`, `просрочено`/`Просроченные`, `подзадача`, `поиск: встреча`, `показать все`, `незавершаемые`, `повторяющиеся`, `без меток`, `Без приоритета`/p4.
  Значит допущение «срок = date, к выполнению = due» — уже факт help (форма «к выполнению до/после» в ru не показана).
- ru: список фильтров на странице — «Фильтры и метки»; заголовок раздела «Мои фильтры» в help нет; диалог «Добавить фильтр»/«Изменить фильтр», поля «Назовите фильтр», «Запрос», «Цвет», «Избранное»; описание — «Описание».
- en: `date: yesterday, today` и `due: yesterday, today` — запятая внутри значения = два списка (есть в help, в fixtures нет); `date before: next week` = до дня «Next week» из настроек;
  `due` берёт дату, а без даты — дедлайн; `search: http` = задачи со ссылками; `p4` = `No priority` (в Quick Add `No priority` не работает).
- Нет в fixtures: `due after:`/`due before: May 5`, `!no time`, `overdue & !no time`, `no time & !recurring`, `!no deadline`, `search: http`, `search: Meeting & today`,
  `deadline after: yesterday & deadline before: in 7 days`, `date: today & date before: today at 2pm`, `date: yesterday, today`, `!/* & !#Inbox`, `(today | overdue) & #Work`.
