import 'package:flutter_test/flutter_test.dart';
import 'package:planner/core/clock.dart';
import 'package:planner/data/app_database.dart';
import 'package:planner/data/projection/entity_fields.dart';
import 'package:planner/domain/models.dart';
import 'package:planner/domain/rules.dart';
import 'package:planner/features/tasks/logic/due_dates.dart';

import '../../sync/support/devices.dart';
import '../support/app_commands.dart';

// Команды повторяющейся задачи (план M3, шаг M3.4). Часы устройства —
// понедельник 26.10.2026, 10:00 по стенным часам (+03:00).

RecurrenceRule _rule(String line, {bool fromCompletion = false}) =>
    RecurrenceRule(rrule: [line], fromCompletion: fromCompletion);

Due _due(
  String date,
  String line, {
  String? time,
  bool fromCompletion = false,
}) => Due(
  date: date,
  time: time,
  string: 'каждый раз',
  lang: 'ru',
  rule: _rule(line, fromCompletion: fromCompletion),
);

Matcher _rejected(RejectReason reason) =>
    throwsA(isA<CommandRejected>().having((e) => e.reason, 'reason', reason));

void main() {
  late TestDevice device;
  late AppCommands app;
  final completedAt = DateTime.utc(2026, 10, 26, 7);

  setUp(() async {
    device = await TestDevice.start(
      clock: FixedClock(completedAt, wallOffset: const Duration(hours: 3)),
    );
    app = AppCommands(device);
  });

  Future<Task> task(String id) async => (await app.read()).task(id)!;
  Future<void> setReset(bool on) => device.services.mutator.update(
    EntityTypes.settings,
    settingsEntityId,
    {SettingsFields.resetRecurringSubtasks: on},
  );
  Future<List<CompletionRow>> completions() =>
      device.db.select(device.db.completions).get();

  group('выполнение вхождения', () {
    test('every day — следующий срок, задача в работе, одна запись о '
        'выполнении с id из (задача, вхождение)', () async {
      final due = _due('2026-10-26', 'FREQ=DAILY');
      final id = await app.tasks.add(content: 'Зарядка', due: due);

      await app.tasks.complete(id);

      final t = await task(id);
      expect(t.isCompleted, isFalse);
      expect(t.due, due.copyWith(date: '2026-10-27'));
      final rows = await completions();
      expect(
        rows.map((c) => (c.id, c.taskId, c.dueWas, c.completedAt, c.deleted)),
        [
          (
            completionId(id, '2026-10-26'),
            id,
            '2026-10-26',
            completedAt.toIso8601String(),
            false,
          ),
        ],
      );
    });

    test(
      'every! 3 days — от дня выполнения по стенным часам устройства',
      () async {
        final due = _due(
          '2026-10-20',
          'FREQ=DAILY;INTERVAL=3',
          fromCompletion: true,
        );
        final id = await app.tasks.add(content: 'Полить цветы', due: due);

        await app.tasks.complete(id);

        expect((await task(id)).due, due.copyWith(date: '2026-10-29'));
      },
    );

    test('срок со временем — вхождение в записи с временем, новый срок с тем '
        'же временем', () async {
      final due = _due('2026-10-26', 'FREQ=DAILY', time: '09:00');
      final id = await app.tasks.add(content: 'Таблетки', due: due);

      await app.tasks.complete(id);

      expect((await task(id)).due, due.copyWith(date: '2026-10-27'));
      expect((await completions()).single.dueWas, '2026-10-26T09:00');
    });

    test('последнее вхождение (UNTIL позади) — задача завершена навсегда, '
        'срок и правило те же, записи о выполнении нет', () async {
      final due = _due('2026-10-26', 'FREQ=DAILY;UNTIL=20261026');
      final id = await app.tasks.add(content: 'Курс', due: due);

      await app.tasks.complete(id);

      final t = await task(id);
      expect(t.isCompleted, isTrue);
      expect(t.due, due);
      expect(await completions(), isEmpty);
    });

    test('битое правило — отказ, данные не изменены', () async {
      final due = _due('2026-10-26', 'FREQ=SECONDLY');
      final id = await app.tasks.add(content: 'x', due: due);

      await expectLater(
        app.tasks.complete(id),
        _rejected(RejectReason.brokenRecurrence),
      );
      expect((await task(id)).due, due);
      expect(await completions(), isEmpty);
    });

    test('«Отменить» — прежний срок, запись удалена; повторное выполнение '
        'возвращает её', () async {
      final due = _due('2026-10-26', 'FREQ=DAILY');
      final id = await app.tasks.add(content: 'Зарядка', due: due);

      final undo = await app.tasks.complete(id);
      await undo();

      expect((await task(id)).due, due);
      expect((await completions()).single.deleted, isTrue);

      await app.tasks.complete(id);
      expect((await completions()).single.deleted, isFalse);
      expect((await task(id)).due!.date, '2026-10-27');
    });
  });

  group('«Завершить навсегда»', () {
    test('задача и незавершённые подзадачи завершены, срок и правило те же, '
        'записи о выполнении нет', () async {
      final due = _due('2026-10-26', 'FREQ=DAILY');
      final id = await app.tasks.add(content: 'Зарядка', due: due);
      final sub = await app.tasks.add(content: 'Разминка', parentId: id);

      await app.tasks.completeForever(id);

      final ws = await app.read();
      expect(ws.task(id)!.isCompleted, isTrue);
      expect(ws.task(sub)!.isCompleted, isTrue);
      expect(ws.task(id)!.due, due);
      expect(await completions(), isEmpty);
    });
  });

  group('подзадачи повторяющейся задачи (решение 6А)', () {
    Future<(String, List<String>, String, String)> parentWithSubtasks() async {
      final id = await app.tasks.add(
        content: 'Уборка',
        due: _due('2026-10-26', 'FREQ=WEEKLY;BYDAY=MO'),
      );
      final done = <String>[];
      for (var i = 0; i < 31; i++) {
        done.add(await app.tasks.add(content: 'Шаг $i', parentId: id));
      }
      final grandchild = await app.tasks.add(
        content: 'Вложенная',
        parentId: done.first,
      );
      final open = await app.tasks.add(content: 'Не начата', parentId: id);
      for (final s in done) {
        await app.tasks.complete(s);
      }
      return (id, done, grandchild, open);
    }

    test('«Сбрасывать подзадачи» включено — первые 30 выполненных прямых '
        'подзадач в работе, 31-я и вложенная — выполнены, незавершённая — '
        'как была', () async {
      final (id, done, grandchild, open) = await parentWithSubtasks();
      await setReset(true);

      await app.tasks.complete(id);

      final ws = await app.read();
      expect(
        [for (final s in done) ws.task(s)!.isCompleted],
        [...List.filled(30, false), true],
      );
      expect(ws.task(done.first)!.completedAt, isNull);
      expect(ws.task(grandchild)!.isCompleted, isTrue);
      expect(ws.task(open)!.isCompleted, isFalse);
      expect(ws.task(id)!.due!.date, '2026-11-02');
    });

    test('«Сбрасывать подзадачи» выключено — выполненные подзадачи остаются '
        'выполненными', () async {
      final (id, done, _, _) = await parentWithSubtasks();
      await setReset(true);
      await setReset(false);

      await app.tasks.complete(id);

      final ws = await app.read();
      expect(done.every((s) => ws.task(s)!.isCompleted), isTrue);
    });

    test('настройку не трогали — выключено (решение 1А «Ход M3.4»): '
        'выполненные подзадачи остаются выполненными', () async {
      final (id, done, _, _) = await parentWithSubtasks();

      await app.tasks.complete(id);

      final ws = await app.read();
      expect(done.every((s) => ws.task(s)!.isCompleted), isTrue);
    });

    test(
      '«Отменить» возвращает сброшенным подзадачам прежнее состояние',
      () async {
        final (id, done, _, _) = await parentWithSubtasks();
        await setReset(true);
        final before = (await task(done.first)).completedAt;

        final undo = await app.tasks.complete(id);
        await undo();

        final ws = await app.read();
        expect(done.every((s) => ws.task(s)!.isCompleted), isTrue);
        expect(ws.task(done.first)!.completedAt, before);
      },
    );
  });

  group('«Отложить»', () {
    test('every! 3 days — на следующее вхождение после срока, без записи '
        'о выполнении', () async {
      final due = _due(
        '2026-11-05',
        'FREQ=DAILY;INTERVAL=3',
        fromCompletion: true,
      );
      final id = await app.tasks.add(content: 'x', due: due);

      await app.tasks.postpone(id);

      expect((await task(id)).due, due.copyWith(date: '2026-11-08'));
      expect(await completions(), isEmpty);
    });

    test('просроченная — на завтра, время и правило те же', () async {
      final due = _due('2026-10-20', 'FREQ=WEEKLY;BYDAY=TU', time: '08:00');
      final id = await app.tasks.add(content: 'x', due: due);

      final undo = await app.tasks.postpone(id);

      expect((await task(id)).due, due.copyWith(date: '2026-10-27'));
      await undo();
      expect((await task(id)).due, due);
    });

    test(
      'срок со временем сегодня, время прошло — просрочена: на завтра',
      () async {
        final due = _due('2026-10-26', 'FREQ=WEEKLY;BYDAY=MO', time: '09:00');
        final id = await app.tasks.add(content: 'x', due: due);

        await app.tasks.postpone(id);

        expect((await task(id)).due, due.copyWith(date: '2026-10-27'));
      },
    );

    test('обычная задача — отказ', () async {
      final id = await app.tasks.add(
        content: 'x',
        due: const Due(date: '2026-10-26'),
      );

      await expectLater(
        app.tasks.postpone(id),
        _rejected(RejectReason.notRecurring),
      );
    });
  });

  group('срок повторяющейся задачи', () {
    test(
      'дата из планировщика переносит только вхождение — правило то же',
      () async {
        final due = _due('2026-10-26', 'FREQ=WEEKLY;BYDAY=MO');
        final id = await app.tasks.add(content: 'x', due: due);

        await app.tasks.setDue(id, dueOnDate(due, '2026-10-28'));

        expect((await task(id)).due, due.copyWith(date: '2026-10-28'));
      },
    );

    test('правка правила и снятие правила сроком без него', () async {
      final id = await app.tasks.add(
        content: 'x',
        due: _due('2026-10-26', 'FREQ=DAILY'),
      );
      final weekly = _due('2026-10-26', 'FREQ=WEEKLY;BYDAY=MO');

      await app.tasks.setDue(id, weekly);
      expect((await task(id)).due, weekly);

      await app.tasks.setDue(id, const Due(date: '2026-10-26'));
      expect((await task(id)).due!.isRecurring, isFalse);
    });
  });

  group('О-19: повторяющаяся задача в группе завершается навсегда', () {
    test('архив раздела — повторяющаяся задача раздела завершена, срок и '
        'правило те же, записи о выполнении нет', () async {
      final section = await app.sections.add(inboxProjectId, name: 'Утро');
      final due = _due('2026-10-26', 'FREQ=DAILY');
      final id = await app.tasks.add(
        content: 'Зарядка',
        sectionId: section,
        due: due,
      );

      await app.sections.archive(section);

      final t = await task(id);
      expect(t.isCompleted, isTrue);
      expect(t.due, due);
      expect(await completions(), isEmpty);
    });

    test('завершение обычного родителя — повторяющаяся подзадача завершена '
        'навсегда (допущение О-57)', () async {
      final parent = await app.tasks.add(content: 'Проект');
      final due = _due('2026-10-26', 'FREQ=DAILY');
      final sub = await app.tasks.add(
        content: 'Ежедневно',
        parentId: parent,
        due: due,
      );

      await app.tasks.complete(parent);

      final t = await task(sub);
      expect(t.isCompleted, isTrue);
      expect(t.due, due);
      expect(await completions(), isEmpty);
    });
  });

  group('по ревью M3.4', () {
    test('«Выполнить и снова добавить подзадачи» — сброс и при выключенной '
        'настройке', () async {
      final id = await app.tasks.add(
        content: 'Уборка',
        due: _due('2026-10-26', 'FREQ=DAILY'),
      );
      final sub = await app.tasks.add(content: 'Шаг', parentId: id);
      await app.tasks.complete(sub);
      await device.services.mutator.update(
        EntityTypes.settings,
        settingsEntityId,
        {SettingsFields.resetRecurringSubtasks: false},
      );

      await app.tasks.complete(id, resetSubtasks: true);

      expect((await task(sub)).isCompleted, isFalse);
    });

    test('сброшенная подзадача получает удалённую метку заново, как при '
        '«Вернуть в работу»', () async {
      final id = await app.tasks.add(
        content: 'Уборка',
        due: _due('2026-10-26', 'FREQ=DAILY'),
      );
      final label = await app.labels.add(name: 'дом');
      final sub = await app.tasks.add(
        content: 'Шаг',
        parentId: id,
        labelIds: {label},
      );
      await app.tasks.complete(sub);
      await app.labels.delete(label);
      await setReset(true);

      await app.tasks.complete(id);

      final ws = await app.read();
      final labels = [for (final l in ws.task(sub)!.labelIds) ws.label(l)!];
      expect(labels.map((l) => l.name), ['дом']);
    });

    test('«Отменить» не удаляет запись о выполнении, пришедшую раньше с '
        'другого устройства, а возвращает её время', () async {
      final due = _due('2026-10-26', 'FREQ=DAILY');
      final id = await app.tasks.add(content: 'Зарядка', due: due);
      final record = completionId(id, '2026-10-26');
      // Телефон уже отметил это вхождение, срок по LWW остался прежним.
      await device.services.mutator.update(EntityTypes.completion, record, {
        CompletionFields.taskId: id,
        CompletionFields.dueWas: '2026-10-26',
        CompletionFields.completedAt: '2026-10-26T05:00:00.000Z',
      });

      final undo = await app.tasks.complete(id);
      await undo();

      final row = (await completions()).single;
      expect(
        (row.deleted, row.completedAt),
        (false, '2026-10-26T05:00:00.000Z'),
      );
      expect((await task(id)).due, due);
    });

    test('«Отложить» срок со временем сегодня, время впереди — на следующее '
        'вхождение, не на сегодня', () async {
      final due = _due('2026-10-26', 'FREQ=DAILY', time: '18:00');
      final id = await app.tasks.add(content: 'x', due: due);

      await app.tasks.postpone(id);

      expect((await task(id)).due, due.copyWith(date: '2026-10-27'));
    });

    test('«Отложить» просроченной задачи, чья серия закончилась, — срок не '
        'меняется', () async {
      final due = _due('2026-10-20', 'FREQ=DAILY;UNTIL=20261022');
      final id = await app.tasks.add(content: 'x', due: due);

      final undo = await app.tasks.postpone(id);

      expect(undo.isEmpty, isTrue);
      expect((await task(id)).due, due);
    });

    test(
      '«Отложить» выполненной навсегда задачи — ничего не меняется',
      () async {
        final due = _due('2026-10-26', 'FREQ=DAILY');
        final id = await app.tasks.add(content: 'x', due: due);
        await app.tasks.completeForever(id);

        final undo = await app.tasks.postpone(id);

        expect(undo.isEmpty, isTrue);
        expect((await task(id)).due, due);
      },
    );

    test(
      'повторяющаяся подзадача — своё вхождение, родитель не тронут',
      () async {
        final parent = await app.tasks.add(content: 'Здоровье');
        final due = _due('2026-10-26', 'FREQ=DAILY');
        final sub = await app.tasks.add(
          content: 'Зарядка',
          parentId: parent,
          due: due,
        );

        await app.tasks.complete(sub);

        final ws = await app.read();
        expect(ws.task(sub)!.due, due.copyWith(date: '2026-10-27'));
        expect(ws.task(sub)!.isCompleted, isFalse);
        expect(ws.task(parent)!.isCompleted, isFalse);
      },
    );

    test('повторяющийся родитель с незавершённой повторяющейся подзадачей — '
        'подзадача как была (решение 3А)', () async {
      final due = _due('2026-10-26', 'FREQ=WEEKLY;BYDAY=MO');
      final parent = await app.tasks.add(content: 'Неделя', due: due);
      final subDue = _due('2026-10-26', 'FREQ=DAILY');
      final sub = await app.tasks.add(
        content: 'Каждый день',
        parentId: parent,
        due: subDue,
      );

      await app.tasks.complete(parent);

      final ws = await app.read();
      expect(ws.task(parent)!.due, due.copyWith(date: '2026-11-02'));
      expect((ws.task(sub)!.isCompleted, ws.task(sub)!.due), (false, subDue));
    });

    test('выполненная навсегда повторяющаяся задача — «Завершить» ничего не '
        'меняет', () async {
      final due = _due('2026-10-26', 'FREQ=DAILY');
      final id = await app.tasks.add(content: 'x', due: due);
      await app.tasks.completeForever(id);

      final undo = await app.tasks.complete(id);

      expect(undo.isEmpty, isTrue);
      expect((await task(id)).due, due);
      expect(await completions(), isEmpty);
    });
  });
}
