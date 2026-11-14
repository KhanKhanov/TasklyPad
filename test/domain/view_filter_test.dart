import 'package:flutter_test/flutter_test.dart';
import 'package:planner/domain/filter_engine.dart';
import 'package:planner/domain/models.dart';
import 'package:planner/domain/view_filter.dart';
import 'package:planner/domain/workspace.dart';
import 'package:planner/nlp/filter_parser.dart';

import '../features/support/app_commands.dart';
import '../sync/support/devices.dart';

// Фильтр «Отображения» (решения 3А, 5А plans/m5 «Решения M5.3»): выбор ↔
// запрос `filtered_by`, значения дат, подъём подзадач в проекте. Сегодня —
// пятница 2026-11-13.
void main() {
  final now = DateTime.utc(2026, 11, 13, 10);

  group('выбор и запрос', () {
    test('ничего не выбрано — запроса нет, «Display» без числа', () {
      expect(const ViewFilter().query, isNull);
      expect(ViewFilter.parse(null).count, 0);
      expect(ViewFilter.parse('  ').count, 0);
    });

    test('все четыре вида — запрос через «&», читается обратно тем же', () {
      const filter = ViewFilter(
        date: ViewDateChoice.thisWeek,
        deadline: ViewDateChoice.none,
        priority: 2,
        label: 'дом',
      );
      final back = ViewFilter.parse(filter.query);
      expect(back.date, ViewDateChoice.thisWeek);
      expect(back.deadline, ViewDateChoice.none);
      expect(back.priority, 2);
      expect(back.label, 'дом');
      expect(back.extra, isEmpty);
      expect(back.count, 4);
      expect(back.query, filter.query);
    });

    test('имя метки со знаками языка — экранируется и читается обратно', () {
      const name = r'a & b | (c), d! \ e*';
      final query = const ViewFilter(label: name).query!;
      expect(ViewFilter.parse(query).label, name);
      expect(
        () => parseFilterQuery(query, now: now),
        returnsNormally,
        reason: query,
      );
    });

    test('незнакомое условие (импорт) сохраняется и считается; с «|» — в '
        'скобках, повторная запись скобки не множит', () {
      final imported = ViewFilter.parse('!subtask | p1');
      expect(imported.extra, ['!subtask | p1']);
      expect(imported.count, 1);
      final chosen = imported.withPriority(3);
      expect(chosen.query, 'p3 & (!subtask | p1)');
      expect(ViewFilter.parse(chosen.query).query, chosen.query);
      expect(ViewFilter.parse(chosen.query).priority, 3);
    });

    test(
      'регистр и пробелы не важны: «P1», «Today» из импорта — пункты меню',
      () {
        final filter = ViewFilter.parse('P1 &  Today ');
        expect(filter.priority, 1);
        expect(filter.date, ViewDateChoice.today);
        expect(filter.extra, isEmpty);
        expect(filter.withPriority(2).query, 'today & p2');
      },
    );

    test('условие с «,» (несколько списков) при выборе отбрасывается: иначе '
        'запятая разделила бы весь запрос', () {
      final imported = ViewFilter.parse('p1, today');
      expect(imported.count, 1);
      expect(imported.withLabel('дом').query, '%дом');
    });

    test('«Все» снимает только свой вид', () {
      final filter = ViewFilter.parse(
        const ViewFilter(priority: 1, label: 'дом').query,
      ).withPriority(null);
      expect(filter.query, '%дом');
    });
  });

  group('значения дат', () {
    late Workspace ws;
    late Map<String, String> byDate;

    setUpAll(() async {
      final device = await TestDevice.start();
      final app = AppCommands(device);
      byDate = {};
      for (final date in [
        '2026-11-12',
        '2026-11-13',
        '2026-11-15',
        '2026-11-16',
        '2026-11-19',
        '2026-11-20',
        '2026-11-30',
        '2026-12-01',
        '2026-12-12',
        '2026-12-13',
      ]) {
        byDate[await app.tasks.add(
              content: 'срок $date',
              due: Due(date: date),
            )] =
            'срок $date';
        byDate[await app.tasks.add(content: 'дедлайн $date', deadline: date)] =
            'дедлайн $date';
      }
      byDate[await app.tasks.add(content: 'без всего')] = 'без всего';
      ws = await app.read();
      await device.db.close();
    });

    List<String> shown(ViewFilter filter) {
      final test = filterTest(
        ws,
        parseFilterQuery(filter.query!, now: now),
        now: now,
      );
      return [
        for (final t in ws.activeTasks)
          if (test(t)) byDate[t.id]!,
      ]..sort();
    }

    List<String> days(String kind, List<String> dates) =>
        [for (final d in dates) '$kind $d']..sort();

    final cases = {
      ViewDateChoice.today: ['2026-11-13'],
      ViewDateChoice.thisWeek: ['2026-11-13', '2026-11-15'],
      ViewDateChoice.next7Days: [
        '2026-11-13',
        '2026-11-15',
        '2026-11-16',
        '2026-11-19',
      ],
      ViewDateChoice.thisMonth: [
        '2026-11-13',
        '2026-11-15',
        '2026-11-16',
        '2026-11-19',
        '2026-11-20',
        '2026-11-30',
      ],
      ViewDateChoice.next30Days: [
        '2026-11-13',
        '2026-11-15',
        '2026-11-16',
        '2026-11-19',
        '2026-11-20',
        '2026-11-30',
        '2026-12-01',
        '2026-12-12',
      ],
    };

    for (final MapEntry(key: choice, value: dates) in cases.entries) {
      test('«${choice.name}» — дата с сегодня, без просроченных', () {
        expect(shown(ViewFilter(date: choice)), days('срок', dates));
      });
      test('«${choice.name}» — дедлайн с сегодня, без просроченных', () {
        expect(shown(ViewFilter(deadline: choice)), days('дедлайн', dates));
      });
    }

    test('«без даты» и «без дедлайна»', () {
      final noDate = shown(const ViewFilter(date: ViewDateChoice.none));
      expect(noDate, contains('без всего'));
      expect(noDate.where((t) => t.startsWith('срок')), isEmpty);
      final noDeadline = shown(const ViewFilter(deadline: ViewDateChoice.none));
      expect(noDeadline, contains('без всего'));
      expect(noDeadline.where((t) => t.startsWith('дедлайн')), isEmpty);
    });
  });

  test('проект с фильтром: видны подходящие задачи и их предки — дерево '
      'настоящее; неподходящая без подходящих потомков не видна', () async {
    final device = await TestDevice.start();
    final app = AppCommands(device);
    final project = await app.projects.add(name: 'Работа');
    final parent = await app.tasks.add(content: 'Родитель', projectId: project);
    final child = await app.tasks.add(
      content: 'Подзадача',
      parentId: parent,
      priority: 1,
    );
    final other = await app.tasks.add(
      content: 'Другая',
      projectId: project,
      priority: 1,
    );
    await app.tasks.add(content: 'Лишняя', projectId: project);
    final ws = await app.read();
    await device.db.close();

    final filtered = ws.projectView(project, where: (t) => t.priority == 1);
    expect(
      [for (final i in filtered.unsectioned) (i.value.content, i.depth)],
      [('Родитель', 0), ('Подзадача', 1), ('Другая', 0)],
    );
    // Для группировки — те же задачи одним списком, без неподходящего родителя.
    expect(
      ws.projectTasks(project, where: (t) => t.priority == 1).map((t) => t.id),
      [child, other],
    );
    final plain = ws.projectView(project);
    expect(
      [for (final i in plain.unsectioned) (i.value.content, i.depth)],
      [('Родитель', 0), ('Подзадача', 1), ('Другая', 0), ('Лишняя', 0)],
    );
  });
}
