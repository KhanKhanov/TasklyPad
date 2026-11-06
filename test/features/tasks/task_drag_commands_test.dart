import 'package:flutter_test/flutter_test.dart';
import 'package:planner/data/projection/entity_fields.dart';
import 'package:planner/domain/models.dart';
import 'package:planner/domain/rules.dart';
import 'package:planner/domain/view_options.dart';
import 'package:planner/domain/view_order.dart';
import 'package:planner/domain/workspace.dart';

import '../../sync/support/devices.dart';
import '../support/app_commands.dart';

// Команды перетаскивания (решение 8 плана M4, решения «Ход M4.9»): перенос на
// место, порядок дня, О-8 (равные ключи), О-71 (смена дня снимает ключ).
void main() {
  late TestDevice device;
  late AppCommands app;

  setUp(() async {
    device = await TestDevice.start();
    app = AppCommands(device);
  });

  List<String> top(Workspace ws) => [
    for (final t in ws.children(null, projectId: ws.inbox!.id)) t.content,
  ];

  Future<List<String>> addAll(List<String> names, {Due? due}) async => [
    for (final name in names) await app.tasks.add(content: name, due: due),
  ];

  /// Дать задачам одинаковый ключ — как после вставок на двух устройствах.
  Future<void> sameKey(List<String> ids, String key) async {
    for (final id in ids) {
      await device.services.mutator.update(EntityTypes.task, id, {
        TaskFields.orderKey: key,
      });
    }
  }

  group('перенос на место', () {
    test('после соседа — и обратно через «Отменить»', () async {
      final ids = await addAll(['А', 'Б', 'В']);
      final undo = await app.tasks.placeAll([ids[2]], afterId: ids[0]);
      expect(top(await app.read()), ['А', 'В', 'Б']);

      await undo();
      expect(top(await app.read()), ['А', 'Б', 'В']);
    });

    test('О-8: равные ключи соседей — можно встать между ними, и «Отменить» '
        'возвращает им прежние ключи', () async {
      final ids = await addAll(['А', 'Б', 'В']);
      await sameKey([ids[0], ids[1]], 'V');
      final before = (await app.read()).children(
        null,
        projectId: (await app.read()).inbox!.id,
      );
      final first = before[0];
      final second = before[1];

      final undo = await app.tasks.placeAll([ids[2]], afterId: first.id);
      final after = await app.read();
      expect(
        [
          for (final t in after.children(null, projectId: after.inbox!.id))
            t.id,
        ],
        [first.id, ids[2], second.id],
      );

      await undo();
      final back = await app.read();
      expect(back.task(first.id)!.orderKey, 'V');
      expect(back.task(second.id)!.orderKey, 'V');
    });

    test('задача уже на месте — пустая отмена, ничего не записано', () async {
      final ids = await addAll(['А', 'Б']);
      final key = (await app.read()).task(ids[1])!.orderKey;
      final undo = await app.tasks.placeAll([ids[1]], afterId: ids[0]);
      expect(undo.isEmpty, isTrue);
      expect((await app.read()).task(ids[1])!.orderKey, key);
    });

    test('скрытая выполненная между соседями не сдвигает место', () async {
      final ids = await addAll(['А', 'готово', 'Б', 'В']);
      await app.tasks.complete(ids[1]);
      await app.tasks.placeAll([ids[3]], afterId: ids[0]);
      final ws = await app.read();
      final order = [
        for (final t in ws.children(null, projectId: ws.inbox!.id))
          if (!t.isCompleted) t.content,
      ];
      expect(order, ['А', 'В', 'Б']);
    });

    test(
      'в подзадачу и обратно: родитель и место меняются одной правкой',
      () async {
        final ids = await addAll(['А', 'Б']);
        await app.tasks.placeAll([ids[1]], parentId: ids[0], atTop: true);
        var ws = await app.read();
        expect(ws.taskParent(ids[1]), ids[0]);

        await app.tasks.placeAll([ids[1]], afterId: ids[0]);
        ws = await app.read();
        expect(ws.taskParent(ids[1]), isNull);
        expect(top(ws), ['А', 'Б']);
      },
    );

    test('перестановка подзадачи на месте не трогает её устаревшие проект и '
        'раздел', () async {
      final work = await app.projects.add(name: 'Работа');
      final parent = await app.tasks.add(content: 'Родитель');
      final a = await app.tasks.add(content: 'А', parentId: parent);
      final b = await app.tasks.add(content: 'Б', parentId: parent);
      await app.tasks.move(parent, projectId: work);
      final stale = (await device.taskRow(a))!.projectId;
      expect(stale, isNot(work));

      await app.tasks.placeAll([b], parentId: parent, atTop: true);
      expect((await device.taskRow(b))!.projectId, stale);
      final ws = await app.read();
      expect([for (final t in ws.children(parent)) t.id], [b, a]);
      expect(ws.rootProjectOf(b), work);
    });

    test('цикл и предел уровней — отказ', () async {
      final ids = await addAll(['1', '2', '3', '4', '5']);
      await app.tasks.placeAll([ids[1]], parentId: ids[0], atTop: true);
      await app.tasks.placeAll([ids[2]], parentId: ids[1], atTop: true);
      await app.tasks.placeAll([ids[3]], parentId: ids[2], atTop: true);

      Matcher rejected(RejectReason reason) => throwsA(
        isA<CommandRejected>().having((e) => e.reason, 'reason', reason),
      );
      await expectLater(
        app.tasks.placeAll([ids[0]], parentId: ids[3], atTop: true),
        rejected(RejectReason.cycle),
      );
      await expectLater(
        app.tasks.placeAll([ids[4]], parentId: ids[3], atTop: true),
        rejected(RejectReason.tooDeep),
      );
    });

    test('несколько выделенных — подряд в порядке выделения, подзадача '
        'выделенного родителя остаётся под ним, отмена одна', () async {
      final ids = await addAll(['А', 'Б', 'В', 'Г']);
      final child = await app.tasks.add(content: 'под Б', parentId: ids[1]);

      final undo = await app.bulk.moveMany([
        ids[3],
        ids[1],
        child,
      ], atTop: true);
      var ws = await app.read();
      expect(top(ws), ['Г', 'Б', 'А', 'В']);
      expect(ws.taskParent(child), ids[1]);

      await undo();
      ws = await app.read();
      expect(top(ws), ['А', 'Б', 'В', 'Г']);
    });
  });

  group('порядок дня', () {
    const today = '2026-10-23';
    const due = Due(date: today);

    List<String> day(Workspace ws, {Sorting sorting = Sorting.byDefault}) => [
      for (final t in ws.todayTasks(
        today,
        order: ws.taskOrder(DefaultOrder.smart, sorting: sorting),
      ))
        t.content,
    ];

    test('три задачи без ключа: третья между первой и второй — ключ у первой '
        'и третьей, вторая без записи', () async {
      final ids = await addAll(['А', 'Б', 'В'], due: due);
      await app.tasks.reorderInDay(ids[2], today, afterId: ids[0]);
      final ws = await app.read();
      expect(day(ws), ['А', 'В', 'Б']);
      expect(ws.task(ids[0])!.dayOrderKey, isNotEmpty);
      expect(ws.task(ids[2])!.dayOrderKey, isNotEmpty);
      expect(ws.task(ids[1])!.dayOrderKey, isEmpty);
    });

    test('«Умная»: только среди равных по сроку, приоритету и дедлайну; '
        'задача другого приоритета не встаёт выше', () async {
      final p1 = await app.tasks.add(content: 'P1', due: due, priority: 1);
      final a = await app.tasks.add(content: 'А', due: due);
      final b = await app.tasks.add(content: 'Б', due: due);
      await app.tasks.reorderInDay(b, today);
      final ws = await app.read();
      expect(day(ws), ['P1', 'Б', 'А']);
      expect(ws.task(p1)!.dayOrderKey, isEmpty);
      expect(ws.task(a)!.dayOrderKey, isEmpty);
    });

    test('«Умная»: ключи получают только задачи своей группы — задача другого '
        'приоритета выше места остаётся без записи', () async {
      final p1 = await app.tasks.add(content: 'P1', due: due, priority: 1);
      final a = await app.tasks.add(content: 'А', due: due);
      await app.tasks.add(content: 'Б', due: due);
      final c = await app.tasks.add(content: 'В', due: due);

      await app.tasks.reorderInDay(c, today, afterId: a);
      final ws = await app.read();
      expect(day(ws), ['P1', 'А', 'В', 'Б']);
      expect(ws.task(p1)!.dayOrderKey, isEmpty);
      expect(ws.task(a)!.dayOrderKey, isNotEmpty);
    });

    test('«Вручную»: можно встать выше задачи с большим приоритетом', () async {
      await app.tasks.add(content: 'P1', due: due, priority: 1);
      final b = await app.tasks.add(content: 'Б', due: due);
      await app.tasks.reorderInDay(b, today, sorting: Sorting.manual);
      expect(day(await app.read(), sorting: Sorting.manual), ['Б', 'P1']);
    });

    test('на другой день с позицией: дата, время и правило вхождения, одна '
        'отмена', () async {
      const rule = RecurrenceRule(rrule: ['FREQ=DAILY'], fromCompletion: false);
      const recurring = Due(
        date: '2026-10-22',
        time: '07:30',
        string: 'every day at 7:30',
        rule: rule,
      );
      final id = await app.tasks.add(content: 'Бег', due: recurring);
      final other = await app.tasks.add(
        content: 'Другая',
        due: const Due(date: today, time: '07:30'),
      );

      final undo = await app.tasks.reorderInDay(id, today, afterId: other);
      var moved = (await app.read()).task(id)!;
      expect(moved.due, recurring.copyWith(date: today));
      expect(moved.dayOrderKey, isNotEmpty);

      await undo();
      moved = (await app.read()).task(id)!;
      expect(moved.due, recurring);
      expect(moved.dayOrderKey, isEmpty);
    });

    test('«Умная»: строка над местом — из группы выше: первой в своей группе; '
        'из группы ниже: последней; сама задача: без записи', () async {
      final p1 = await app.tasks.add(content: 'P1', due: due, priority: 1);
      final a = await app.tasks.add(content: 'А', due: due);
      final b = await app.tasks.add(content: 'Б', due: due);
      final p4Last = await app.tasks.add(content: 'В', due: due);

      await app.tasks.reorderInDay(p4Last, today, afterId: p1);
      expect(day(await app.read()), ['P1', 'В', 'А', 'Б']);

      final undo = await app.tasks.reorderInDay(a, today, afterId: a);
      expect(undo.isEmpty, isTrue);

      await app.tasks.reorderInDay(p1, today, afterId: b);
      expect(day(await app.read()).first, 'P1');
    });

    test('отмена возвращает и ключ соседа, который получил его при '
        'перестановке', () async {
      final ids = await addAll(['А', 'Б', 'В'], due: due);
      final undo = await app.tasks.reorderInDay(ids[2], today, afterId: ids[0]);
      expect((await app.read()).task(ids[0])!.dayOrderKey, isNotEmpty);
      await undo();
      final ws = await app.read();
      expect(ws.task(ids[0])!.dayOrderKey, isEmpty);
      expect(ws.task(ids[2])!.dayOrderKey, isEmpty);
      expect(day(ws), ['А', 'Б', 'В']);
    });

    test(
      'сортировка с направлением — ошибка: порядок дня там не действует',
      () async {
        final ids = await addAll(['А'], due: due);
        await expectLater(
          app.tasks.reorderInDay(
            ids[0],
            today,
            sorting: Sorting.alphabetically,
          ),
          throwsArgumentError,
        );
      },
    );

    test(
      'moveToDay на тот же день — без записи: текст срока не теряется',
      () async {
        const typed = Due(date: today, string: 'сегодня', lang: 'ru');
        final id = await app.tasks.add(content: 'А', due: typed);
        final undo = await app.tasks.moveToDay(id, today);
        expect(undo.isEmpty, isTrue);
        expect((await app.read()).task(id)!.due, typed);
      },
    );

    test('задача с битым правилом переставляется в своём дне', () async {
      const broken = Due(
        date: today,
        rule: RecurrenceRule(rrule: ['FREQ=SECONDLY'], fromCompletion: false),
      );
      final a = await app.tasks.add(content: 'А', due: due);
      final b = await app.tasks.add(content: 'Б', due: due);
      final c = await app.tasks.add(content: 'В', due: broken);
      await app.tasks.reorderInDay(c, today, afterId: a);
      expect(day(await app.read()), ['А', 'В', 'Б']);
      expect((await app.read()).task(b)!.dayOrderKey, isEmpty);
    });

    test('бросок на своё место — пустая отмена', () async {
      final ids = await addAll(['А', 'Б'], due: due);
      final undo = await app.tasks.reorderInDay(ids[1], today, afterId: ids[0]);
      expect(undo.isEmpty, isTrue);
      expect((await app.read()).task(ids[1])!.dayOrderKey, isEmpty);
    });

    test('moveToDay у повторяющейся — только вхождение', () async {
      const rule = RecurrenceRule(rrule: ['FREQ=DAILY'], fromCompletion: false);
      const recurring = Due(date: today, time: '07:30', rule: rule);
      final id = await app.tasks.add(content: 'Бег', due: recurring);
      await app.tasks.moveToDay(id, '2026-10-24');
      expect(
        (await app.read()).task(id)!.due,
        recurring.copyWith(date: '2026-10-24'),
      );
    });
  });

  group('О-71: смена дня снимает ключ порядка дня', () {
    const today = '2026-10-23';
    const rule = RecurrenceRule(rrule: ['FREQ=DAILY'], fromCompletion: false);

    /// Задача с ключом порядка дня.
    Future<String> keyed(Due due) async {
      final id = await app.tasks.add(content: 'С ключом', due: due);
      await device.services.mutator.update(EntityTypes.task, id, {
        TaskFields.dayOrderKey: 'V',
      });
      return id;
    }

    Future<String> key(String id) async =>
        (await app.read()).task(id)!.dayOrderKey;

    test('setDue — снят; «Отменить» возвращает; время в тот же день — не '
        'снят', () async {
      final id = await keyed(const Due(date: today));
      await app.tasks.setDue(id, const Due(date: today, time: '09:00'));
      expect(await key(id), 'V');

      final undo = await app.tasks.setDue(id, const Due(date: '2026-10-25'));
      expect(await key(id), isEmpty);

      await undo();
      expect(await key(id), 'V');
    });

    test('renameWithDue', () async {
      final id = await keyed(const Due(date: today));
      await app.tasks.renameWithDue(id, 'Новое', const Due(date: '2026-10-25'));
      expect(await key(id), isEmpty);
    });

    test('«Перенести»', () async {
      final id = await keyed(const Due(date: '2026-10-20'));
      await app.tasks.rescheduleOverdue([id], today);
      expect(await key(id), isEmpty);
    });

    test('выполнение вхождения', () async {
      final id = await keyed(const Due(date: today, rule: rule));
      final undo = await app.tasks.complete(id);
      expect(await key(id), isEmpty);
      await undo();
      expect(await key(id), 'V');
    });

    test('«Отложить»', () async {
      final id = await keyed(const Due(date: today, rule: rule));
      await app.tasks.postpone(id);
      expect(await key(id), isEmpty);
    });

    test('массовый срок', () async {
      final id = await keyed(const Due(date: today));
      await app.bulk.setDue([id], const Due(date: '2026-10-25'));
      expect(await key(id), isEmpty);
    });
  });
}
