import 'package:flutter_test/flutter_test.dart';
import 'package:oplog_sync/oplog_sync.dart';
import 'package:planner/core/clock.dart';
import 'package:planner/data/projection/entity_fields.dart';
import 'package:planner/sync/io_sync_fs.dart';

import 'support/devices.dart';

// Сквозные сценарии «ПК + телефон» тем же путём, что в приложении:
// Mutator → журнал drift → FolderSync с арендой → папка на диске → другая база.
void main() {
  late TestDevice pc;
  late TestDevice phone;
  late String folder;

  setUp(() async {
    folder = tempDir('two_devices_').path;
    pc = await TestDevice.start(seed: 1);
    phone = await TestDevice.start(seed: 2);
  });

  Future<void> syncBoth() async {
    for (var round = 0; round < 2; round++) {
      for (final dev in [pc, phone]) {
        final report = await dev.folder(IoSyncFs(folder)).syncOnce();
        expect(report?.issues, isEmpty);
      }
    }
  }

  Future<String> sharedTask(Map<String, Object?> fields) async {
    final id = await pc.services.mutator.create(EntityTypes.task, fields);
    await syncBoth();
    pc.advance(const Duration(seconds: 1));
    phone.advance(const Duration(seconds: 2));
    return id;
  }

  test('задача с ПК появляется в таблице задач телефона', () async {
    final id = await pc.services.mutator.create(EntityTypes.task, {
      TaskFields.content: 'Купить молоко',
      TaskFields.priority: 1,
      TaskFields.projectId: inboxProjectId,
    });
    await syncBoth();

    final row = await phone.taskRow(id);
    expect(
      (row?.content, row?.priority, row?.projectId),
      ('Купить молоко', 1, inboxProjectId),
    );
  });

  test('«Входящие» созданы на обоих независимо — один проект, без '
      'конфликтов', () async {
    await syncBoth();

    for (final dev in [pc, phone]) {
      final inboxes = await (dev.db.select(
        dev.db.projects,
      )..where((t) => t.isInbox.equals(true))).get();
      expect(inboxes.map((p) => p.id), [inboxProjectId]);
      expect(await dev.conflicts(), isEmpty);
    }
  });

  test('вид «Входящих» изменён на ПК до подключения нового телефона — '
      'сохраняется, конфликтов нет', () async {
    await syncBoth();
    pc.advance(const Duration(days: 1));
    await pc.services.mutator.update(EntityTypes.project, inboxProjectId, {
      ProjectFields.viewStyle: 'board',
    });
    await pc.folder(IoSyncFs(folder)).syncOnce();

    // Новый телефон ставят через день: «Входящие» он создаёт до первой
    // синхронизации.
    final newPhone = await TestDevice.start(
      clock: FixedClock(testStart.add(const Duration(days: 2))),
      seed: 3,
    );
    for (var round = 0; round < 2; round++) {
      await newPhone.folder(IoSyncFs(folder)).syncOnce();
      await pc.folder(IoSyncFs(folder)).syncOnce();
    }

    for (final dev in [pc, newPhone]) {
      final inbox = await (dev.db.select(
        dev.db.projects,
      )..where((t) => t.id.equals(inboxProjectId))).getSingle();
      expect(inbox.viewStyle, 'board');
      expect(await dev.conflicts(), isEmpty);
    }
  });

  test('параллельная правка названия — конфликт с одним id на обоих, выбор '
      'на телефоне закрывает его на ПК', () async {
    final id = await sharedTask({TaskFields.content: 'Отчёт'});
    await pc.services.mutator.update(EntityTypes.task, id, {
      TaskFields.content: 'Отчёт за квартал',
    });
    await phone.services.mutator.update(EntityTypes.task, id, {
      TaskFields.content: 'Отчёт до пятницы',
    });
    await syncBoth();

    final onPc = await pc.conflicts();
    expect(onPc, hasLength(1));
    expect(await phone.conflicts(), onPc);

    await phone.services.mutator.resolveConflict(onPc.single.id, {
      TaskFields.content: 'Отчёт за квартал',
    });
    await syncBoth();

    for (final dev in [pc, phone]) {
      expect((await dev.conflicts()).single.resolved, isTrue);
      expect((await dev.taskRow(id))?.content, 'Отчёт за квартал');
    }
  });

  test(
    'правка против удаления — конфликт delete, задача удалена на обоих',
    () async {
      final id = await sharedTask({TaskFields.content: 'Позвонить'});
      await pc.services.mutator.delete(EntityTypes.task, id);
      await phone.services.mutator.update(EntityTypes.task, id, {
        TaskFields.priority: 1,
      });
      await syncBoth();

      for (final dev in [pc, phone]) {
        expect((await dev.conflicts()).single.kind, ConflictKind.delete);
        expect(await dev.aliveTasks(), isNot(contains(id)));
      }
    },
  );

  test('оба завершили повторяющуюся задачу офлайн — две completion, срок '
      'сдвинут один раз, правило повторения цело', () async {
    final id = await sharedTask({
      TaskFields.content: 'Зарядка',
      TaskFields.due: {
        'date': '2026-10-23',
        'string': 'каждый день',
        'is_recurring': true,
      },
    });
    for (final dev in [pc, phone]) {
      // Завершение повторяющейся = событие completion + новый срок.
      await dev.services.mutator.create('completion', {
        'task_id': id,
        'due_was': '2026-10-23',
      });
      await dev.services.mutator.update(EntityTypes.task, id, {
        TaskFields.due: {'date': '2026-10-24'},
      });
    }
    await syncBoth();

    for (final dev in [pc, phone]) {
      final completions = await (dev.db.select(
        dev.db.fieldVersions,
      )..where((t) => t.entityType.equals('completion'))).get();
      expect(completions.map((r) => r.entityId).toSet(), hasLength(2));
      expect((await dev.entity(EntityTypes.task, id))?[TaskFields.due], {
        'date': '2026-10-24',
        'string': 'каждый день',
        'is_recurring': true,
      });
      expect(await dev.conflicts(), isEmpty, reason: 'сроки одинаковые');
    }
  });

  test('перезапуск телефона между синхронизациями — правки продолжают '
      'доходить в обе стороны', () async {
    final id = await sharedTask({TaskFields.content: 'v0'});
    phone = await phone.restart();
    await phone.services.mutator.update(EntityTypes.task, id, {
      TaskFields.content: 'с телефона после перезапуска',
    });
    await syncBoth();
    expect((await pc.taskRow(id))?.content, 'с телефона после перезапуска');

    pc.advance(const Duration(minutes: 1));
    await pc.services.mutator.update(EntityTypes.task, id, {
      TaskFields.content: 'с ПК',
    });
    await syncBoth();
    expect((await phone.taskRow(id))?.content, 'с ПК');
    expect(await phone.conflicts(), isEmpty);
  });
}
