import 'package:flutter_test/flutter_test.dart';
import 'package:planner/domain/workspace.dart';
import 'package:planner/features/filters/logic/filter_add_values.dart';
import 'package:planner/nlp/filter_parser.dart';

import '../../sync/support/devices.dart';
import '../support/app_commands.dart';

// «Добавить задачу» на экране фильтра — значения из части запроса (решение
// 1А plans/m5 «Решения M5.3»). Сегодня — 2026-11-13.
void main() {
  late Workspace ws;
  late String work, meetings, home, office, inbox;

  setUpAll(() async {
    final device = await TestDevice.start();
    final app = AppCommands(device);
    work = await app.projects.add(name: 'Работа');
    meetings = await app.sections.add(work, name: 'Встречи');
    await app.projects.add(name: 'Дубль');
    await app.projects.add(name: 'дубль');
    home = await app.labels.add(name: 'дом');
    office = await app.labels.add(name: 'офис');
    ws = await app.read();
    inbox = ws.inbox!.id;
    await device.db.close();
  });

  FilterAddValues values(String query) => filterAddValues(
    ws,
    parseFilterQuery(
      query,
      now: DateTime.utc(2026, 11, 13, 10),
    ).parts.single.node,
  );

  test('проект, раздел, метки, приоритет, срок и дедлайн через «&» — все '
      'подставляются', () {
    final v = values(
      '#Работа & /Встречи & %дом & @офис & p2 & today & deadline: Nov 20',
    );
    expect(v.projectId, work);
    expect(v.sectionId, meetings);
    expect(v.labelIds, {home, office});
    expect(v.priority, 2);
    expect(v.due?.date, '2026-11-13');
    expect(v.due?.time, isNull);
    expect(v.deadline, '2026-11-20');
  });

  test('регистр и «ё» не важны; «##» — сам проект; «#Inbox» и «#Входящие» — '
      '«Входящие»', () {
    expect(values('#работа').projectId, work);
    expect(values('##Работа').projectId, work);
    expect(values('#Inbox').projectId, inbox);
    expect(values('#Входящие').projectId, inbox);
  });

  test('«due:» и «date:» на один день — срок; со временем — только дата', () {
    expect(values('due: tomorrow').due?.date, '2026-11-14');
    expect(values('date: today at 2pm').due?.date, '2026-11-13');
    expect(values('date: today at 2pm').due?.time, isNull);
  });

  for (final (query, why) in [
    ('#Работа | p1', 'под «|»'),
    ('!#Работа', 'под «!»'),
    ('#Раб*', 'подстановка «*»'),
    ('#Нет такого', 'проекта нет'),
    ('#Дубль', 'два проекта с этим именем'),
    ('date before: today', 'диапазон'),
    ('7 days', 'диапазон «N days»'),
    ('overdue', 'без значения'),
    ('/Встречи', 'раздел без проекта'),
  ]) {
    test('«$query» — ничего не подставляется: $why', () {
      final v = values(query);
      expect(v.projectId, isNull);
      expect(v.sectionId, isNull);
      expect(v.labelIds, isEmpty);
      expect(v.priority, isNull);
      expect(v.due, isNull);
      expect(v.deadline, isNull);
    });
  }

  test(
    'разные значения одного поля — поле не подставляется, остальные — да',
    () {
      final v = values('p1 & p2 & #Работа');
      expect(v.priority, isNull);
      expect(v.projectId, work);
      expect(values('#Работа & #Inbox').projectId, isNull);
      expect(values('p1 & p1').priority, 1);
    },
  );

  test(
    '«&» внутри скобок — тоже верхний уровень части; «|» рядом не мешает',
    () {
      final v = values('(#Работа & p3) & (today | overdue)');
      expect(v.projectId, work);
      expect(v.priority, 3);
      expect(v.due, isNull);
    },
  );

  test('несуществующая метка пропускается, остальные остаются', () {
    expect(values('%дом & %нет').labelIds, {home});
  });
}
