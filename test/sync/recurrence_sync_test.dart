import 'package:flutter_test/flutter_test.dart';
import 'package:planner/core/clock.dart';
import 'package:planner/data/app_database.dart';
import 'package:planner/data/projection/entity_fields.dart';
import 'package:planner/domain/models.dart';
import 'package:planner/sync/io_sync_fs.dart';

import '../features/support/app_commands.dart';
import 'support/devices.dart';

// Повторяющиеся задачи на двух устройствах (план M3, «Тесты (сводно)»):
// команды M3.4 на ПК и телефоне, обмен через папку на диске. Каждый сценарий
// проверяется и после пересборки базы из журнала. Часы обоих — понедельник
// 26.10.2026, 10:00 по стенным часам (+03:00).

final DateTime _monday = DateTime.utc(2026, 10, 26, 7);

Due _daily(String date) => Due(
  date: date,
  string: 'каждый день',
  lang: 'ru',
  rule: const RecurrenceRule(rrule: ['FREQ=DAILY'], fromCompletion: false),
);

void main() {
  late TestDevice pc;
  late TestDevice phone;
  late AppCommands onPc;
  late AppCommands onPhone;
  late String folder;

  setUp(() async {
    folder = tempDir('recurrence_sync_').path;
    pc = await TestDevice.start(
      seed: 1,
      clock: FixedClock(_monday, wallOffset: const Duration(hours: 3)),
    );
    phone = await TestDevice.start(
      seed: 2,
      clock: FixedClock(_monday, wallOffset: const Duration(hours: 3)),
    );
    onPc = AppCommands(pc);
    onPhone = AppCommands(phone);
  });

  Future<void> syncBoth() async {
    for (var round = 0; round < 2; round++) {
      for (final dev in [pc, phone]) {
        final report = await dev.folder(IoSyncFs(folder)).syncOnce();
        expect(report?.issues, isEmpty);
      }
    }
  }

  /// Задача создана на ПК и доставлена на телефон; часы телефона на 2 с
  /// позже — его правки параллельны правкам ПК и новее их.
  Future<String> sharedTask(Due due) async {
    final id = await onPc.tasks.add(content: 'Зарядка', due: due);
    await syncBoth();
    pc.advance(const Duration(seconds: 1));
    phone.advance(const Duration(seconds: 2));
    return id;
  }

  Future<List<CompletionRow>> completionsOf(TestDevice dev) =>
      dev.db.select(dev.db.completions).get();

  /// Состояние, которое должно совпасть на обоих устройствах и пережить
  /// пересборку: записи о выполнении, задача, конфликты.
  Future<Object> stateOf(TestDevice dev, String id) async {
    final rows = await completionsOf(dev);
    final t = (await AppCommands(dev).read()).task(id);
    return [
      for (final c in rows..sort((a, b) => a.id.compareTo(b.id)))
        (c.id, c.dueWas, c.deleted),
      (t?.isCompleted, t?.due),
      for (final c in await dev.conflicts()) (c.id, c.field, c.resolved),
    ];
  }

  /// Одинаково на обоих устройствах и после пересборки на каждом.
  Future<Object> expectConverged(String id) async {
    final expected = await stateOf(pc, id);
    expect(await stateOf(phone, id), expected, reason: 'телефон == ПК');
    for (final dev in [pc, phone]) {
      await dev.services.engine.rebuild();
      expect(await stateOf(dev, id), expected, reason: 'после пересборки');
    }
    return expected;
  }

  test('оба отметили одно вхождение офлайн — одна запись, срок сдвинут один '
      'раз, конфликтов нет', () async {
    final id = await sharedTask(_daily('2026-10-26'));
    await onPc.tasks.complete(id);
    await onPhone.tasks.complete(id);
    await syncBoth();

    expect((await completionsOf(pc)).single.id, completionId(id, '2026-10-26'));
    expect(await pc.conflicts(), isEmpty);
    expect((await onPc.read()).task(id)!.due!.date, '2026-10-27');
    await expectConverged(id);
  });

  test('одно просроченное вхождение выполнено в разные дни — одна запись, '
      'конфликт по сроку с одним id на обоих', () async {
    final id = await sharedTask(_daily('2026-10-24'));
    await onPc.tasks.complete(id); // понедельник → вторник
    // Сутки идут на обоих: иначе ПК отклонил бы ops телефона из «будущего».
    pc.advance(const Duration(days: 1));
    phone.advance(const Duration(days: 1));
    await onPhone.tasks.complete(id); // вторник → среда
    await syncBoth();

    expect(await completionsOf(pc), hasLength(1));
    final conflicts = await pc.conflicts();
    expect(conflicts.single.field, TaskFields.due);
    expect(await phone.conflicts(), conflicts);
    await expectConverged(id);
  });

  test('ПК отметил два вхождения, телефон одно — две записи, конфликт по '
      'сроку; выбор на ПК закрывает его на телефоне', () async {
    final id = await sharedTask(_daily('2026-10-26'));
    await onPc.tasks.complete(id); // 26 → 27
    pc.advance(const Duration(seconds: 1));
    await onPc.tasks.complete(id); // 27 → 28
    await onPhone.tasks.complete(id); // 26 → 27
    await syncBoth();

    expect((await completionsOf(pc)).map((c) => c.dueWas).toSet(), {
      '2026-10-26',
      '2026-10-27',
    });
    final conflict = (await pc.conflicts()).single;
    expect(conflict.field, TaskFields.due);
    await pc.services.mutator.resolveConflict(conflict.id, {
      TaskFields.due: await pc.services.store.fieldValue(
        EntityTypes.task,
        id,
        TaskFields.due,
      ),
    });
    await syncBoth();
    expect((await phone.conflicts()).single.resolved, isTrue);
    await expectConverged(id);
  });

  test('правка правила против выполнения — один конфликт по сроку', () async {
    final id = await sharedTask(_daily('2026-10-26'));
    await onPc.tasks.setDue(
      id,
      _daily('2026-10-26').copyWith(
        string: 'каждый пн',
        rule: const RecurrenceRule(
          rrule: ['FREQ=WEEKLY;BYDAY=MO'],
          fromCompletion: false,
        ),
      ),
    );
    await onPhone.tasks.complete(id);
    await syncBoth();

    expect((await pc.conflicts()).map((c) => (c.entityType, c.field)), [
      (EntityTypes.task, TaskFields.due),
    ]);
    await expectConverged(id);
  });

  test(
    '«Отменить» на ПК против выполнения на телефоне — конфликт по сроку, '
    'по записи о выполнении карточки нет, запись удалена (О-62, M8)',
    () async {
      final id = await sharedTask(_daily('2026-10-26'));
      final undo = await onPc.tasks.complete(id);
      pc.advance(const Duration(seconds: 2));
      await undo();
      await onPhone.tasks.complete(id);
      await syncBoth();

      expect((await pc.conflicts()).map((c) => (c.entityType, c.field)), [
        (EntityTypes.task, TaskFields.due),
      ]);
      expect((await completionsOf(pc)).single.deleted, isTrue);

      // Выбор стороны телефона («выполнено», срок 27.10) пишет только срок:
      // запись о выполнении остаётся удалённой — ограничение О-62 (M8).
      final conflict = (await pc.conflicts()).single;
      await pc.services.mutator.resolveConflict(conflict.id, {
        TaskFields.due: {
          DueKeys.date: '2026-10-27',
          DueKeys.string: 'каждый день',
          DueKeys.lang: 'ru',
          DueKeys.rule: {
            RuleKeys.rrule: ['FREQ=DAILY'],
            RuleKeys.fromCompletion: false,
          },
        },
      });
      await syncBoth();
      for (final app in [onPc, onPhone]) {
        expect((await app.read()).task(id)!.due!.date, '2026-10-27');
      }
      for (final dev in [pc, phone]) {
        expect((await completionsOf(dev)).single.deleted, isTrue);
        expect((await dev.conflicts()).single.resolved, isTrue);
      }
      await expectConverged(id);
    },
  );

  test('«Завершить навсегда» против выполнения — одинаково на обоих', () async {
    final id = await sharedTask(_daily('2026-10-26'));
    await onPc.tasks.completeForever(id);
    await onPhone.tasks.complete(id);
    await syncBoth();

    final t = (await onPc.read()).task(id)!;
    expect(t.isCompleted, isTrue);
    expect(await completionsOf(pc), hasLength(1));
    await expectConverged(id);
  });

  test('сброс подзадач против правки подзадачи — обе правки сохранены, '
      'конфликтов нет', () async {
    final id = await sharedTask(_daily('2026-10-26'));
    final sub = await onPc.tasks.add(content: 'Разминка', parentId: id);
    await onPc.tasks.complete(sub);
    await syncBoth();
    pc.advance(const Duration(seconds: 1));
    phone.advance(const Duration(seconds: 2));

    await onPc.tasks.complete(
      id,
      resetSubtasks: true,
    ); // подзадача снова в работе
    await onPhone.tasks.rename(sub, 'Разминка 10 минут');
    await syncBoth();

    for (final app in [onPc, onPhone]) {
      final s = (await app.read()).task(sub)!;
      expect((s.isCompleted, s.content), (false, 'Разминка 10 минут'));
    }
    expect(await pc.conflicts(), isEmpty);
    await expectConverged(id);
  });

  test('долгий офлайн — пять выполнений на ПК доходят до телефона, повторная '
      'доставка ничего не меняет', () async {
    final id = await sharedTask(_daily('2026-10-26'));
    for (var i = 0; i < 5; i++) {
      await onPc.tasks.complete(id);
      pc.advance(const Duration(days: 1));
    }
    phone.advance(const Duration(days: 5)); // телефон «просыпается» позже
    await syncBoth();

    expect(await completionsOf(phone), hasLength(5));
    final state = await expectConverged(id);
    await syncBoth();
    expect(await stateOf(phone, id), state);
  });
}
