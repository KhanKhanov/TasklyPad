import 'package:flutter_test/flutter_test.dart';
import 'package:planner/data/projection/entity_fields.dart';
import 'package:planner/domain/models.dart';
import 'package:planner/domain/rules.dart';

import '../../sync/support/devices.dart';
import '../support/app_commands.dart';

Matcher _rejected(RejectReason reason) =>
    throwsA(isA<CommandRejected>().having((e) => e.reason, 'reason', reason));

void main() {
  late TestDevice device;
  late AppCommands app;

  setUp(() async {
    device = await TestDevice.start();
    app = AppCommands(device);
  });

  Future<List<String>> inboxOrder() async {
    final ws = await app.read();
    return [
      for (final item in ws.projectView(inboxProjectId).unsectioned)
        item.value.content,
    ];
  }

  test('add — во «Входящие» в конец, с датой добавления; atTop и afterId '
      'ставят на место', () async {
    await app.tasks.add(content: '  Б  ');
    final first = await app.tasks.add(content: 'А', atTop: true);
    await app.tasks.add(content: 'А2', afterId: first);
    expect(await inboxOrder(), ['А', 'А2', 'Б']);
    final task = (await app.read()).task(first)!;
    expect(task.projectId, inboxProjectId);
    expect(task.addedAt, testStart.toIso8601String());
  });

  test('add — поля срока, дедлайна, длительности и метки', () async {
    final label = await app.labels.add(name: 'дом');
    final id = await app.tasks.add(
      content: 'Отчёт',
      priority: 1,
      due: const Due(date: '2026-10-30', time: '10:00'),
      deadline: '2026-10-31',
      duration: const TaskDuration(amount: 30, unit: 'minute'),
      labelIds: {label},
    );
    final task = (await app.read()).task(id)!;
    expect(task.priority, 1);
    expect(task.due, const Due(date: '2026-10-30', time: '10:00'));
    expect(task.deadline, '2026-10-31');
    expect(task.duration, const TaskDuration(amount: 30, unit: 'minute'));
    expect(task.labelIds, [label]);
  });

  const weekly = Due(
    date: '2026-10-26',
    time: '07:00',
    string: 'каждый пн в 7:00',
    lang: 'ru',
    rule: RecurrenceRule(rrule: ['FREQ=WEEKLY;BYDAY=MO'], fromCompletion: true),
  );

  test('add — срок с правилом читается обратно целиком, задача '
      'повторяющаяся; duplicate копирует правило', () async {
    final id = await app.tasks.add(content: 'Зарядка', due: weekly);
    final task = (await app.read()).task(id)!;
    expect(task.due, weekly);
    expect(task.due!.isRecurring, isTrue);

    final copy = await app.tasks.duplicate(id);
    expect((await app.read()).task(copy)!.due, weekly);
  });

  test('setDue — срок без правила снимает повтор, «Отменить» возвращает '
      'правило', () async {
    final id = await app.tasks.add(content: 'Зарядка', due: weekly);
    final undo = await app.tasks.setDue(id, const Due(date: '2026-11-02'));
    expect((await app.read()).task(id)!.due, const Due(date: '2026-11-02'));

    await undo();
    expect((await app.read()).task(id)!.due, weekly);
  });

  test('add — пустое название и пятый уровень подзадач отклоняются', () async {
    expect(app.tasks.add(content: '   '), _rejected(RejectReason.emptyName));
    var parent = await app.tasks.add(content: '1');
    for (var level = 2; level <= 4; level++) {
      parent = await app.tasks.add(content: '$level', parentId: parent);
    }
    expect(
      app.tasks.add(content: '5', parentId: parent),
      _rejected(RejectReason.tooDeep),
    );
  });

  test('подзадача получает проект и раздел родителя', () async {
    final project = await app.projects.add(name: 'Работа');
    final section = await app.sections.add(project, name: 'Неделя');
    final parent = await app.tasks.add(
      content: 'Родитель',
      projectId: project,
      sectionId: section,
    );
    final child = await app.tasks.add(content: 'Ребёнок', parentId: parent);
    final task = (await app.read()).task(child)!;
    expect((task.projectId, task.sectionId), (project, section));
  });

  test('complete — завершает с незавершёнными подзадачами; отмена '
      'возвращает как было', () async {
    final parent = await app.tasks.add(content: 'Родитель');
    final open = await app.tasks.add(content: 'Открытая', parentId: parent);
    final done = await app.tasks.add(content: 'Готовая', parentId: parent);
    await app.tasks.complete(done);
    device.advance(const Duration(minutes: 5));
    final doneAt = (await app.read()).task(done)!.completedAt;

    final undo = await app.tasks.complete(parent);
    var ws = await app.read();
    expect(ws.task(parent)!.isCompleted, isTrue);
    expect(ws.task(open)!.isCompleted, isTrue);
    expect(ws.task(done)!.completedAt, doneAt);

    await undo();
    ws = await app.read();
    expect(ws.task(parent)!.isCompleted, isFalse);
    expect(ws.task(parent)!.completedAt, isNull);
    expect(ws.task(open)!.isCompleted, isFalse);
    expect(ws.task(done)!.isCompleted, isTrue);
  });

  test(
    'uncomplete подзадачи возвращает в работу и завершённых предков',
    () async {
      final parent = await app.tasks.add(content: 'Родитель');
      final child = await app.tasks.add(content: 'Ребёнок', parentId: parent);
      await app.tasks.complete(parent);
      await app.tasks.uncomplete(child);
      final ws = await app.read();
      expect(ws.task(parent)!.isCompleted, isFalse);
      expect(ws.task(child)!.isCompleted, isFalse);
    },
  );

  test('uncomplete — возвращённая задача встаёт в конец незавершённых '
      '(item_uncomplete в Todoist API)', () async {
    final a = await app.tasks.add(content: 'a');
    await app.tasks.add(content: 'b');
    await app.tasks.add(content: 'c');
    await app.tasks.complete(a);
    await app.tasks.uncomplete(a);
    expect(await inboxOrder(), ['b', 'c', 'a']);
  });

  test('uncomplete — архивный раздел корневой задачи возвращается и встаёт '
      'в конец разделов; отмена возвращает как было', () async {
    final p = await app.projects.add(name: 'Работа');
    final s1 = await app.sections.add(p, name: 'Старое');
    await app.sections.add(p, name: 'Неделя');
    final t = await app.tasks.add(content: 't', projectId: p, sectionId: s1);
    final other = await app.tasks.add(
      content: 'другая',
      projectId: p,
      sectionId: s1,
    );
    await app.sections.archive(s1);
    var ws = await app.read();
    final before = (
      section: ws.section(s1)!.orderKey,
      task: ws.task(t)!.orderKey,
      completedAt: ws.task(t)!.completedAt,
    );

    final undo = await app.tasks.uncomplete(t);
    ws = await app.read();
    expect([for (final s in ws.sectionsOf(p)) s.name], ['Неделя', 'Старое']);
    expect(ws.task(t)!.isCompleted, isFalse);
    // Возвращается только эта задача: остальные задачи архивного раздела
    // остались завершёнными (help «Introduction to sections»).
    expect(ws.task(other)!.isCompleted, isTrue);

    await undo();
    ws = await app.read();
    expect(ws.section(s1)!.isArchived, isTrue);
    expect(ws.section(s1)!.orderKey, before.section);
    expect(ws.task(t)!.isCompleted, isTrue);
    expect(ws.task(t)!.orderKey, before.task);
    expect(ws.task(t)!.completedAt, before.completedAt);
  });

  test('uncomplete подзадачи — завершённый родитель встаёт в конец своих '
      'незавершённых соседей', () async {
    final parent = await app.tasks.add(content: 'Родитель');
    final child = await app.tasks.add(content: 'Ребёнок', parentId: parent);
    await app.tasks.add(content: 'b');
    await app.tasks.complete(parent);
    await app.tasks.uncomplete(child);
    expect(await inboxOrder(), ['b', 'Родитель', 'Ребёнок']);
  });

  test('uncomplete незавершённой задачи — ни одной op, раздел из архива не '
      'возвращается', () async {
    final p = await app.projects.add(name: 'Работа');
    final s = await app.sections.add(p, name: 'Старое');
    final t = await app.tasks.add(content: 't', projectId: p, sectionId: s);
    await app.sections.archive(s);
    // Задача завершена архивом; вернём её и снова отправим раздел в архив
    // без задач, чтобы получить незавершённую задачу в архивном разделе.
    await app.tasks.uncomplete(t);
    await device.services.mutator.update(EntityTypes.section, s, {
      SectionFields.isArchived: true,
    });
    final opsBefore = (await device.ownOps()).length;
    await app.tasks.uncomplete(t);
    expect((await device.ownOps()).length, opsBefore);
    expect((await app.read()).section(s)!.isArchived, isTrue);
  });

  test(
    'move — поддерево переезжает в другой проект; отмена возвращает',
    () async {
      final project = await app.projects.add(name: 'Работа');
      final parent = await app.tasks.add(content: 'Родитель');
      final child = await app.tasks.add(content: 'Ребёнок', parentId: parent);

      final undo = await app.tasks.move(parent, projectId: project);
      var ws = await app.read();
      expect(ws.rootProjectOf(child), project);
      expect(ws.projectView(inboxProjectId).unsectioned, isEmpty);
      expect(ws.projectView(project).unsectioned.length, 2);

      await undo();
      ws = await app.read();
      expect(ws.rootProjectOf(parent), inboxProjectId);
      expect(ws.rootProjectOf(child), inboxProjectId);
    },
  );

  test(
    'move — в собственного потомка нельзя, глубже 4 уровней нельзя',
    () async {
      final a = await app.tasks.add(content: 'a');
      final b = await app.tasks.add(content: 'b', parentId: a);
      expect(app.tasks.move(a, parentId: b), _rejected(RejectReason.cycle));

      final deep = await app.tasks.add(content: 'x');
      final deep2 = await app.tasks.add(content: 'y', parentId: deep);
      await app.tasks.add(content: 'z', parentId: deep2);
      // Цепочка a→b (2 уровня) под z (3-й уровень) дала бы 5.
      final z = (await app.read()).children(deep2).single.id;
      expect(app.tasks.move(a, parentId: z), _rejected(RejectReason.tooDeep));
    },
  );

  test('indent и outdent — Ctrl+] и Ctrl+[', () async {
    final a = await app.tasks.add(content: 'a');
    final b = await app.tasks.add(content: 'b');
    final c = await app.tasks.add(content: 'c');
    expect(await app.tasks.indent(a), isNull);

    await app.tasks.indent(b);
    await app.tasks.indent(c);
    var ws = await app.read();
    expect(ws.taskParent(b), a);
    expect(ws.taskParent(c), a);
    expect([for (final t in ws.children(a)) t.id], [b, c]);

    await app.tasks.outdent(b);
    ws = await app.read();
    expect(ws.taskParent(b), isNull);
    expect(await inboxOrder(), ['a', 'c', 'b']);
  });

  test('moveUp / moveDown — Ctrl+↑ / Ctrl+↓', () async {
    await app.tasks.add(content: 'a');
    final b = await app.tasks.add(content: 'b');
    await app.tasks.add(content: 'c');
    expect(await app.tasks.moveUp(b), isTrue);
    expect(await inboxOrder(), ['b', 'a', 'c']);
    expect(await app.tasks.moveUp(b), isFalse);
    await app.tasks.moveDown(b);
    await app.tasks.moveDown(b);
    expect(await inboxOrder(), ['a', 'c', 'b']);
    expect(await app.tasks.moveDown(b), isFalse);
  });

  test(
    'delete — задача и подзадачи скрыты, строки и журнал остались',
    () async {
      final parent = await app.tasks.add(content: 'Родитель');
      final child = await app.tasks.add(content: 'Ребёнок', parentId: parent);
      await app.tasks.delete(parent);
      final ws = await app.read();
      expect(ws.task(parent), isNull);
      expect(ws.task(child), isNull);
      expect((await device.taskRow(child))!.deleted, isFalse);
    },
  );

  test('duplicate — копия сразу после, с незавершёнными подзадачами и '
      'метками', () async {
    final label = await app.labels.add(name: 'дом');
    final a = await app.tasks.add(content: 'a', labelIds: {label});
    await app.tasks.add(content: 'b');
    await app.tasks.add(content: 'a1', parentId: a);
    final done = await app.tasks.add(content: 'a2', parentId: a);
    await app.tasks.complete(done);

    final copy = await app.tasks.duplicate(a);
    final ws = await app.read();
    expect(await inboxOrder(), ['a', 'a1', 'a', 'a1', 'b']);
    expect(ws.task(copy)!.labelIds, [label]);
    expect([for (final t in ws.children(copy)) t.content], ['a1']);
  });

  test('setLabels — ставит недостающие и снимает лишние; связь — один id на '
      'пару', () async {
    final x = await app.labels.add(name: 'x');
    final y = await app.labels.add(name: 'y');
    final id = await app.tasks.add(content: 't', labelIds: {x});
    await app.tasks.setLabels(id, {y});
    expect((await app.read()).task(id)!.labelIds, [y]);
    final link = await device.entity(EntityTypes.taskLabel, taskLabelId(id, x));
    expect(link?[TaskLabelFields.deleted], isTrue);
  });

  test('setDue — отмена возвращает прежний срок со временем', () async {
    final id = await app.tasks.add(
      content: 't',
      due: const Due(date: '2026-10-30', time: '10:00'),
    );
    final undo = await app.tasks.setDue(id, const Due(date: '2026-11-02'));
    expect((await app.read()).task(id)!.due, const Due(date: '2026-11-02'));
    await undo();
    expect(
      (await app.read()).task(id)!.due,
      const Due(date: '2026-10-30', time: '10:00'),
    );
  });

  test(
    'add — раздел задаёт проект; раздел чужого проекта отклоняется',
    () async {
      final p = await app.projects.add(name: 'Работа');
      final s = await app.sections.add(p, name: 'Неделя');
      final id = await app.tasks.add(content: 't', sectionId: s);
      expect((await app.read()).task(id)!.projectId, p);
      expect(
        app.tasks.add(content: 'x', projectId: inboxProjectId, sectionId: s),
        _rejected(RejectReason.notFound),
      );
    },
  );

  test('moveUp при совпавших ключах соседей (параллельные вставки) — задача '
      'действительно поднимается', () async {
    final a = await app.tasks.add(content: 'a');
    final b = await app.tasks.add(content: 'b');
    final c = await app.tasks.add(content: 'c');
    final key = (await app.read()).task(a)!.orderKey;
    for (final id in [b, c]) {
      await device.services.mutator.update(EntityTypes.task, id, {
        TaskFields.orderKey: key,
      });
    }
    final before = await inboxOrder();
    expect(await app.tasks.moveUp(before.last == 'c' ? c : b), isTrue);
    final after = await inboxOrder();
    expect(after, isNot(before));
    expect(after.indexOf(before.last), before.length - 2);
  });
}
