import 'package:flutter_test/flutter_test.dart';
import 'package:planner/data/projection/entity_fields.dart';
import 'package:planner/domain/models.dart';
import 'package:planner/domain/rules.dart';

import '../../sync/support/devices.dart';
import '../support/app_commands.dart';

// Действия над выделенными задачами (решение 9 плана M4, решение 1А
// «Ход M4.8»): одна транзакция, одно «Отменить» на все задачи.
void main() {
  late TestDevice device;
  late AppCommands app;

  setUp(() async {
    device = await TestDevice.start();
    app = AppCommands(device);
  });

  const weekly = Due(
    date: '2026-10-19',
    time: '08:00',
    tz: 'Europe/Moscow',
    string: 'каждый пн',
    lang: 'ru',
    rule: RecurrenceRule(
      rrule: ['FREQ=WEEKLY;BYDAY=MO'],
      fromCompletion: false,
    ),
  );

  test(
    '«Дата» — только дата: у каждой задачи время и правило остаются, у '
    'повторяющейся меняется вхождение; «Отменить» возвращает все сроки',
    () async {
      final plain = await app.tasks.add(content: 'Отчёт');
      final timed = await app.tasks.add(
        content: 'Звонок',
        due: const Due(date: '2026-10-21', time: '15:30'),
      );
      final recurring = await app.tasks.add(content: 'Зарядка', due: weekly);

      final undo = await app.bulk.setDue([
        plain,
        timed,
        recurring,
      ], const Due(date: '2026-10-25'));
      var ws = await app.read();
      expect(ws.task(plain)!.due, const Due(date: '2026-10-25'));
      expect(ws.task(timed)!.due, const Due(date: '2026-10-25', time: '15:30'));
      expect(ws.task(recurring)!.due, weekly.copyWith(date: '2026-10-25'));

      await undo();
      ws = await app.read();
      expect(ws.task(plain)!.due, isNull);
      expect(ws.task(timed)!.due, const Due(date: '2026-10-21', time: '15:30'));
      expect(ws.task(recurring)!.due, weekly);
    },
  );

  test('«Дата» со временем или текстом — этот срок целиком у всех, правило '
      'повторяющейся снимается', () async {
    final timed = await app.tasks.add(
      content: 'Звонок',
      due: const Due(date: '2026-10-21', time: '15:30'),
    );
    final recurring = await app.tasks.add(content: 'Зарядка', due: weekly);
    const at9 = Due(date: '2026-10-24', time: '09:00');
    await app.bulk.setDue([timed, recurring], at9);
    var ws = await app.read();
    expect(ws.task(timed)!.due, at9);
    expect(ws.task(recurring)!.due, at9);

    const typed = Due(date: '2026-10-24', string: 'завтра', lang: 'ru');
    await app.bulk.setDue([timed, recurring], typed);
    ws = await app.read();
    expect(ws.task(timed)!.due, typed);
    expect(ws.task(recurring)!.due, typed);
  });

  test(
    '«Без срока» снимает срок у всех; удалённая задача пропускается',
    () async {
      final a = await app.tasks.add(
        content: 'А',
        due: const Due(date: '2026-10-20'),
      );
      final b = await app.tasks.add(content: 'Б', due: weekly);
      final gone = await app.tasks.add(content: 'В');
      await app.tasks.delete(gone);

      await app.bulk.setDue([a, b, gone], null);
      final ws = await app.read();
      expect(ws.task(a)!.due, isNull);
      expect(ws.task(b)!.due, isNull);
    },
  );

  test('«Перенести в…» — в конец проекта в порядке выделения; выделенная '
      'подзадача выделенного родителя остаётся под ним; «Отменить» '
      'возвращает места', () async {
    final work = await app.projects.add(name: 'Работа');
    final inbox = (await app.read()).inbox!.id;
    final parent = await app.tasks.add(content: 'Родитель');
    final child = await app.tasks.add(content: 'Подзадача', parentId: parent);
    final other = await app.tasks.add(content: 'Другая');

    final undo = await app.bulk.move([other, parent, child], work, null);
    var ws = await app.read();
    expect(
      [for (final t in ws.children(null, projectId: work)) t.id],
      [other, parent],
    );
    expect(ws.taskParent(child), parent);
    expect(ws.rootProjectOf(child), work);

    await undo();
    ws = await app.read();
    for (final id in [parent, child, other]) {
      expect(ws.rootProjectOf(id), inbox);
    }
    expect(ws.taskParent(child), parent);
  });

  test(
    '«Метки» добавляют к своим меткам каждой задачи и ничего не снимают',
    () async {
      final home = await app.labels.add(name: 'дом');
      final work = await app.labels.add(name: 'работа');
      final a = await app.tasks.add(content: 'А', labelIds: {home});
      final b = await app.tasks.add(content: 'Б');

      await app.bulk.addLabels([a, b], {work});
      final ws = await app.read();
      expect(ws.task(a)!.labelIds.toSet(), {home, work});
      expect(ws.task(b)!.labelIds, [work]);
    },
  );

  test('«Метки»: у задачи стало бы больше 100 меток — отказ, не меняется ни '
      'одна задача', () async {
    final labels = [
      for (var i = 0; i < Limits.labelsPerTask; i++)
        await app.labels.add(name: 'м$i'),
    ];
    final extra = await app.labels.add(name: 'лишняя');
    final full = await app.tasks.add(
      content: 'Полная',
      labelIds: labels.toSet(),
    );
    final empty = await app.tasks.add(content: 'Пустая');

    await expectLater(
      app.bulk.addLabels([empty, full], {extra}),
      throwsA(
        isA<CommandRejected>().having(
          (e) => e.reason,
          'reason',
          RejectReason.tooManyLabels,
        ),
      ),
    );
    final ws = await app.read();
    expect(ws.task(empty)!.labelIds, isEmpty);
    expect(ws.task(full)!.labelIds, hasLength(Limits.labelsPerTask));
  });

  test('«Приоритет» и «Дедлайн» — у всех выделенных, в том числе у '
      'подзадачи', () async {
    final parent = await app.tasks.add(content: 'Родитель');
    final child = await app.tasks.add(content: 'Подзадача', parentId: parent);

    await app.bulk.setPriority([parent, child], 1);
    await app.bulk.setDeadline([parent, child], '2026-11-01');
    var ws = await app.read();
    for (final id in [parent, child]) {
      expect(ws.task(id)!.priority, 1);
      expect(ws.task(id)!.deadline, '2026-11-01');
    }
    await app.bulk.setDeadline([parent, child], null);
    ws = await app.read();
    expect(ws.task(child)!.deadline, isNull);
  });

  test(
    '«Выполнить»: обычная — выполнена с подзадачами, повторяющаяся — '
    'следующий срок, выполненная не трогается; «Отменить» возвращает все',
    () async {
      final parent = await app.tasks.add(content: 'Родитель');
      final child = await app.tasks.add(content: 'Подзадача', parentId: parent);
      final recurring = await app.tasks.add(content: 'Зарядка', due: weekly);
      final done = await app.tasks.add(content: 'Готово');
      await app.tasks.complete(done);
      final doneAt = (await app.read()).task(done)!.completedAt;
      device.advance(const Duration(minutes: 1));

      final undo = await app.bulk.complete([child, parent, recurring, done]);
      var ws = await app.read();
      expect(ws.task(parent)!.isCompleted, isTrue);
      expect(ws.task(child)!.isCompleted, isTrue);
      expect(ws.task(recurring)!.isCompleted, isFalse);
      expect(ws.task(recurring)!.due!.date, '2026-10-26');
      expect(ws.task(done)!.completedAt, doneAt);

      await undo();
      ws = await app.read();
      expect(ws.task(parent)!.isCompleted, isFalse);
      expect(ws.task(child)!.isCompleted, isFalse);
      expect(ws.task(recurring)!.due, weekly);
      expect(
        [
          for (final c in await device.db.select(device.db.completions).get())
            c.deleted,
        ],
        [true],
      );
      expect(ws.task(done)!.isCompleted, isTrue);
    },
  );

  test('«Вернуть» — только выполненные', () async {
    final a = await app.tasks.add(content: 'А');
    final b = await app.tasks.add(content: 'Б');
    await app.tasks.complete(a);
    await app.tasks.complete(b);

    await app.bulk.uncomplete([a, b]);
    final ws = await app.read();
    expect(ws.task(a)!.isCompleted, isFalse);
    expect(ws.task(b)!.isCompleted, isFalse);
  });

  test('«Дублировать»: выделенные родитель и подзадача — одна копия '
      'родителя с подзадачей, сразу после оригинала', () async {
    final parent = await app.tasks.add(content: 'Родитель');
    await app.tasks.add(content: 'Подзадача', parentId: parent);
    final child = (await app.read()).children(parent).single.id;
    final last = await app.tasks.add(content: 'Последняя');

    await app.bulk.duplicate([parent, child]);
    final ws = await app.read();
    final top = ws.children(null, projectId: ws.inbox!.id);
    expect(
      [for (final t in top) t.content],
      ['Родитель', 'Родитель', 'Последняя'],
    );
    expect(top[1].id, isNot(parent));
    expect([for (final t in ws.children(top[1].id)) t.content], ['Подзадача']);
    expect(top.last.id, last);
    expect([for (final t in ws.children(parent)) t.id], [child]);
  });

  test('«Удалить» — выделенные с подзадачами', () async {
    final parent = await app.tasks.add(content: 'Родитель');
    final child = await app.tasks.add(content: 'Подзадача', parentId: parent);
    final kept = await app.tasks.add(content: 'Остаётся');

    await app.bulk.delete([parent, child]);
    final ws = await app.read();
    expect(ws.task(parent), isNull);
    expect(ws.task(child), isNull);
    expect(ws.task(kept), isNotNull);
  });

  test('отказ на одной задаче — действие отменено целиком: срок не изменился '
      'ни у одной', () async {
    final a = await app.tasks.add(content: 'А');
    final b = await app.tasks.add(
      content: 'Б',
      due: const Due(date: '2026-10-20'),
    );
    const broken = Due(
      date: '2026-10-21',
      string: 'every second',
      rule: RecurrenceRule(rrule: ['FREQ=SECONDLY'], fromCompletion: false),
    );
    final c = await app.tasks.add(content: 'В', due: broken);

    await expectLater(
      app.bulk.setDue([a, b, c], const Due(date: '2026-10-25')),
      throwsA(
        isA<CommandRejected>().having(
          (e) => e.reason,
          'reason',
          RejectReason.brokenRecurrence,
        ),
      ),
    );
    final ws = await app.read();
    expect(ws.task(a)!.due, isNull);
    expect(ws.task(b)!.due, const Due(date: '2026-10-20'));
    expect(ws.task(c)!.due, broken);
  });

  test('«Выполнить»: подзадача повторяющегося родителя выделена вместе с ним '
      '— родитель получает следующий срок, подзадача выполнена', () async {
    final parent = await app.tasks.add(content: 'Обзор', due: weekly);
    final child = await app.tasks.add(content: 'Почта', parentId: parent);

    await app.bulk.complete([parent, child]);
    final ws = await app.read();
    expect(ws.task(parent)!.isCompleted, isFalse);
    expect(ws.task(parent)!.due!.date, '2026-10-26');
    expect(ws.task(child)!.isCompleted, isTrue);
  });

  test('«Выполнить»: выполненный родитель и его незавершённая подзадача — '
      'подзадача выполнена', () async {
    final parent = await app.tasks.add(content: 'Родитель');
    await app.tasks.complete(parent);
    // Подзадачу добавили к выполненному родителю (как с другого устройства).
    final child = await app.tasks.add(content: 'Новая', parentId: parent);

    await app.bulk.complete([parent, child]);
    expect((await app.read()).task(child)!.isCompleted, isTrue);
  });

  test('«Метки»: у задачи уже все добавляемые метки — лимит её не касается, даже если меток больше 100 (пришли с другого устройства)', () async {
    final labels = [
      for (var i = 0; i <= Limits.labelsPerTask; i++)
        await app.labels.add(name: 'м$i'),
    ];
    final full = await app.tasks.add(
      content: 'Полная',
      labelIds: labels.toSet(),
    );
    final empty = await app.tasks.add(content: 'Пустая');

    await app.bulk.addLabels([full, empty], {labels.first});
    final ws = await app.read();
    expect(ws.task(empty)!.labelIds, [labels.first]);
    expect(ws.task(full)!.labelIds, hasLength(Limits.labelsPerTask + 1));
  });

  test('«Вернуть» двух выполненных с одинаковым ключом → ключи разные, у '
      'соседа ключ прежний (решение 4А «M4.10a»)', () async {
    final a = await app.tasks.add(content: 'a');
    final b = await app.tasks.add(content: 'b');
    final c = await app.tasks.add(content: 'c');
    await app.bulk.complete([b, c]);
    // Другое устройство поставило «c» на ключ «b».
    final key = (await app.read()).task(b)!.orderKey;
    await device.services.mutator.update(EntityTypes.task, c, {
      TaskFields.orderKey: key,
    });
    final aKey = (await app.read()).task(a)!.orderKey;

    await app.bulk.uncomplete([b, c]);
    final ws = await app.read();
    expect(ws.task(b)!.isCompleted, isFalse);
    expect(ws.task(c)!.isCompleted, isFalse);
    expect(ws.task(b)!.orderKey, isNot(ws.task(c)!.orderKey));
    expect(ws.task(a)!.orderKey, aKey);
  });
}
