import 'package:flutter_test/flutter_test.dart';
import 'package:oplog_sync/oplog_sync.dart';
import 'package:planner/data/local_meta_dao.dart';
import 'package:planner/data/projection/entity_fields.dart';
import 'package:planner/domain/conflicts.dart';
import 'package:planner/features/conflicts/logic/conflict_commands.dart';
import 'package:planner/sync/conflict_repository.dart';
import 'package:planner/sync/io_sync_fs.dart';
import 'package:planner/sync/sync_services.dart';

import '../features/support/app_commands.dart';
import 'support/devices.dart';

// Экран «Конфликты» и уведомления о них на двух устройствах: карточки
// (решения 2Б и 3Б к коммиту 3 M2.3), выбор стороны и О-9 — уведомление по
// таблице конфликтов, а не по отчёту прохода.
void main() {
  late TestDevice pc;
  late TestDevice phone;
  late AppCommands onPc;
  late AppCommands onPhone;
  late String folder;

  setUp(() async {
    folder = tempDir('conflict_repo_').path;
    pc = await TestDevice.start(seed: 1);
    phone = await TestDevice.start(seed: 2);
    onPc = AppCommands(pc);
    onPhone = AppCommands(phone);
  });

  ConflictRepository repoOf(TestDevice dev) => ConflictRepository(
    db: dev.db,
    store: dev.services.store,
    meta: dev.services.meta,
  );

  ConflictCommands commandsOf(TestDevice dev) => ConflictCommands(
    mutator: dev.services.mutator,
    read: AppCommands(dev).read,
  );

  /// Ops, которые [action] записал на устройстве [dev]: (сущность, поле, значение).
  Future<List<(String, String, Object?)>> written(
    TestDevice dev,
    Future<void> Function() action,
  ) async {
    final before = (await dev.ownOps()).length;
    await action();
    return [
      for (final op in (await dev.ownOps()).skip(before))
        (op.entityType, op.field, op.value),
    ];
  }

  const resolved = (conflictEntityType, conflictResolvedField, true);

  Future<void> syncBoth() async {
    for (var round = 0; round < 2; round++) {
      for (final dev in [pc, phone]) {
        final report = await dev.folder(IoSyncFs(folder)).syncOnce();
        expect(report?.issues, isEmpty);
      }
    }
    pc.advance(const Duration(seconds: 1));
    phone.advance(const Duration(seconds: 2));
  }

  test('конфликт из перечитанного после сбоя чанка: в отчёте прохода его '
      'нет, а уведомление есть — одно (О-9)', () async {
    final task = await onPc.tasks.add(content: 'Отчёт');
    await syncBoth();
    await onPc.tasks.rename(task, 'Отчёт за квартал');
    await onPhone.tasks.rename(task, 'Отчёт за год');
    expect(await pc.folder(IoSyncFs(folder)).syncOnce(), isNotNull);

    // Сбой между применением чанка и сдвигом курсора.
    final failing = FolderTransport(
      fs: IoSyncFs(folder),
      engine: phone.services.engine,
      state: _CursorFailsOnce(phone.services.syncState),
      root: syncFolderName,
    );
    await expectLater(failing.sync(), throwsA(isA<_CursorFailure>()));
    expect(await phone.conflicts(), hasLength(1));

    phone = await phone.restart();
    final report = await phone.folder(IoSyncFs(folder)).syncOnce();
    expect(report!.received.conflicts, isEmpty, reason: 'условие О-9');

    final cards = await repoOf(phone).takeUnnotified();
    expect(cards.single.entityId, task);
    expect(await repoOf(phone).takeUnnotified(), isEmpty);
    await phone.services.engine.rebuild();
    expect(await repoOf(phone).takeUnnotified(), isEmpty);
  });

  test('разрешённые конфликты уходят из списка уведомлённых; битый список — '
      'одно повторное уведомление, без падения', () async {
    final task = await onPc.tasks.add(content: 'a');
    await syncBoth();
    await onPc.tasks.rename(task, 'b');
    await onPhone.tasks.rename(task, 'c');
    await syncBoth();

    final meta = phone.services.meta;
    expect(await repoOf(phone).takeUnnotified(), hasLength(1));
    await meta.write(LocalMetaDao.notifiedConflictsKey, '{не json');
    expect(await repoOf(phone).takeUnnotified(), hasLength(1));

    final card = (await repoOf(pc).load()).single;
    await commandsOf(pc).keep(card, card.newer);
    await syncBoth();
    expect(await repoOf(phone).takeUnnotified(), isEmpty);
    expect(await meta.notifiedConflicts(), isEmpty);
  });

  test('метку сняли на ПК, на телефоне сняли и поставили снова — карточка '
      'метки задачи знает задачу-владельца (пометка в строке задачи, 1Б '
      'M4.13)', () async {
    final label = await onPc.labels.add(name: 'дом');
    final task = await onPc.tasks.add(content: 'Купить', labelIds: {label});
    await syncBoth();

    await onPc.tasks.setLabels(task, {});
    await onPhone.tasks.setLabels(task, {});
    phone.advance(const Duration(seconds: 1));
    await onPhone.tasks.setLabels(task, {label});
    await syncBoth();

    for (final dev in [pc, phone]) {
      final card = (await repoOf(dev).load()).single;
      expect(card.entity, ConflictEntity.taskLabel);
      expect(card.title, 'дом');
      expect(card.ownerTitle, 'Купить');
      expect(card.ownerId, task);
    }
  });

  test('карточки задачи и проекта — без задачи-владельца', () async {
    final project = await onPc.projects.add(name: 'Дом');
    final task = await onPc.tasks.add(content: 'a', projectId: project);
    await syncBoth();
    await onPc.tasks.rename(task, 'b');
    await onPhone.tasks.rename(task, 'c');
    await onPc.projects.rename(project, 'Дача');
    await onPhone.projects.rename(project, 'Сад');
    await syncBoth();

    final cards = await repoOf(pc).load();
    expect(cards.map((c) => c.entity), {
      ConflictEntity.task,
      ConflictEntity.project,
    });
    expect(cards.map((c) => c.ownerId), everyElement(isNull));
  });

  test('перенос задачи в разные проекты и разделы — одна карточка на оба '
      'поля; выбор ранней стороны переносит целиком на обоих', () async {
    final work = await onPc.projects.add(name: 'Работа');
    final home = await onPc.projects.add(name: 'Дом');
    final week = await onPc.sections.add(work, name: 'Неделя');
    final kitchen = await onPc.sections.add(home, name: 'Кухня');
    final task = await onPc.tasks.add(content: 'Купить лампу');
    await syncBoth();

    await onPc.tasks.move(task, projectId: work, sectionId: week);
    await onPhone.tasks.move(task, projectId: home, sectionId: kitchen);
    await syncBoth();

    final card = (await repoOf(phone).load()).single;
    expect(card.entity, ConflictEntity.task);
    expect(card.title, 'Купить лампу');
    expect(card.isDelete, isFalse);
    expect(card.conflictIds, hasLength(2));
    expect(card.older.values.map((v) => v.field), [
      ConflictField.project,
      ConflictField.section,
    ]);
    final project = card.older.values.first.value! as ConflictRef;
    expect(project.title, 'Работа');
    expect((card.older.isCurrent, card.newer.isCurrent), (false, true));
    expect(card.older.isThisDevice, isFalse);
    expect(card.newer.isThisDevice, isTrue);
    expect(card.current, isEmpty);
    expect((await repoOf(pc).load()).single.conflictIds, card.conflictIds);

    await commandsOf(phone).keep(card, card.older);
    await syncBoth();
    for (final dev in [onPc, onPhone]) {
      final moved = (await dev.read()).task(task)!;
      expect((moved.projectId, moved.sectionId), (work, week));
    }
    for (final dev in [pc, phone]) {
      expect((await dev.conflicts()).every((c) => c.resolved), isTrue);
      expect(await repoOf(dev).load(), isEmpty);
    }
  });

  test('30 переименований на телефоне против одного на ПК — одна карточка '
      'со всеми конфликтами, у телефона последнее название; выбор закрывает '
      'все на обоих (О-66)', () async {
    final task = await onPc.tasks.add(content: 'Отчёт');
    await syncBoth();

    await onPc.tasks.rename(task, 'Отчёт ПК');
    for (var i = 1; i <= 30; i++) {
      phone.advance(const Duration(minutes: 1));
      await onPhone.tasks.rename(task, 'Отчёт $i');
    }
    await syncBoth();

    expect(await pc.conflicts(), hasLength(30));
    final card = (await repoOf(pc).load()).single;
    expect(card.conflictIds, hasLength(30));
    final onPhoneCard = (await repoOf(phone).load()).single;
    expect(onPhoneCard.conflictIds, card.conflictIds);
    // Стороны те же на обоих: отличаются только отметки «это устройство».
    ConflictSide plain(ConflictSide s) =>
        s.copyWith(isThisDevice: false, isFormerThisDevice: false);
    expect(
      [plain(onPhoneCard.older), plain(onPhoneCard.newer)],
      [plain(card.older), plain(card.newer)],
    );
    expect((card.older.isThisDevice, card.newer.isThisDevice), (true, false));
    expect(card.older.values.map((v) => (v.field, v.value)), [
      (ConflictField.content, 'Отчёт ПК'),
    ]);
    expect(card.newer.values.map((v) => (v.field, v.value)), [
      (ConflictField.content, 'Отчёт 30'),
    ]);
    expect((card.older.isCurrent, card.newer.isCurrent), (false, true));

    await commandsOf(pc).keep(card, card.older);
    await syncBoth();
    for (final dev in [onPc, onPhone]) {
      expect((await dev.read()).task(task)!.content, 'Отчёт ПК');
    }
    for (final dev in [pc, phone]) {
      expect({for (final c in await dev.conflicts()) c.resolved}, {true});
      expect(await repoOf(dev).load(), isEmpty);
    }
  });

  test('название и приоритет разными действиями на обоих — одна карточка с '
      'обоими полями, хотя последние действия правят только приоритет; '
      'выбор возвращает оба поля', () async {
    final task = await onPc.tasks.add(content: 'Отчёт');
    await syncBoth();

    await onPc.tasks.rename(task, 'Отчёт ПК');
    pc.advance(const Duration(minutes: 1));
    await onPc.tasks.setPriority(task, 1);
    phone.advance(const Duration(minutes: 5));
    await onPhone.tasks.rename(task, 'Отчёт тел');
    phone.advance(const Duration(minutes: 1));
    await onPhone.tasks.setPriority(task, 3);
    await syncBoth();

    final card = (await repoOf(phone).load()).single;
    expect(card.conflictIds, hasLength(2));
    final byPc = card.older.isThisDevice ? card.newer : card.older;
    final byPhone = card.older.isThisDevice ? card.older : card.newer;
    expect(byPc.values.map((v) => (v.field, v.value)), [
      (ConflictField.content, 'Отчёт ПК'),
      (ConflictField.priority, 1),
    ]);
    expect(byPhone.values.map((v) => (v.field, v.value)), [
      (ConflictField.content, 'Отчёт тел'),
      (ConflictField.priority, 3),
    ]);
    expect((byPc.isCurrent, byPhone.isCurrent), (false, true));

    await commandsOf(phone).keep(card, byPc);
    await syncBoth();
    for (final dev in [onPc, onPhone]) {
      final kept = (await dev.read()).task(task)!;
      expect((kept.content, kept.priority), ('Отчёт ПК', 1));
    }
    for (final dev in [pc, phone]) {
      expect(await repoOf(dev).load(), isEmpty);
    }
  });

  test('устройства порознь пришли к одним значениям — карточка без полей, '
      'обе стороны действуют; выбор ничего не пишет и закрывает её', () async {
    final task = await onPc.tasks.add(content: 'Отчёт');
    await syncBoth();

    await onPc.tasks.setPriority(task, 1);
    pc.advance(const Duration(minutes: 1));
    await onPc.tasks.setPriority(task, 2);
    pc.advance(const Duration(minutes: 1));
    await onPc.tasks.rename(task, 'Итог');
    phone.advance(const Duration(minutes: 5));
    await onPhone.tasks.rename(task, 'Черновик');
    phone.advance(const Duration(minutes: 1));
    await phone.services.mutator.update(EntityTypes.task, task, {
      TaskFields.content: 'Итог',
      TaskFields.priority: 2,
    });
    await syncBoth();

    final card = (await repoOf(phone).load()).single;
    expect(card.conflictIds, hasLength(2));
    expect([...card.older.values, ...card.newer.values], isEmpty);
    expect((card.older.isCurrent, card.newer.isCurrent), (true, true));

    final ops = await written(
      phone,
      () => commandsOf(phone).keep(card, card.older),
    );
    expect(ops.toSet(), {resolved});
    await syncBoth();
    for (final dev in [pc, phone]) {
      expect(await repoOf(dev).load(), isEmpty);
    }
  });

  test(
    'спор о названии не решён, синхронизация, спор о приоритете — две '
    'карточки, у каждой своё поле обеих сторон (решение 1А «Ход M4.3»)',
    () async {
      final task = await onPc.tasks.add(content: 'Отчёт');
      await syncBoth();

      await onPc.tasks.rename(task, 'Отчёт ПК');
      phone.advance(const Duration(minutes: 1));
      await onPhone.tasks.rename(task, 'Отчёт тел');
      await syncBoth();
      await onPc.tasks.setPriority(task, 1);
      await onPhone.tasks.setPriority(task, 3);
      await syncBoth();

      for (final dev in [pc, phone]) {
        final cards = await repoOf(dev).load();
        expect(
          {
            for (final card in cards)
              {
                for (final side in [card.older, card.newer])
                  for (final v in side.values) (v.field, v.value),
              },
          },
          {
            {
              (ConflictField.content, 'Отчёт ПК'),
              (ConflictField.content, 'Отчёт тел'),
            },
            {(ConflictField.priority, 1), (ConflictField.priority, 3)},
          },
        );
      }
    },
  );

  test('стороны совпадают в поле, его поменяли после спора — выбор его не '
      'пишет и не откатывает (решения 3А и 6А «Ход M4.3»)', () async {
    final task = await onPc.tasks.add(content: 'Отчёт');
    await syncBoth();

    await pc.services.mutator.update(EntityTypes.task, task, {
      TaskFields.content: 'Отчёт ПК',
      TaskFields.priority: 2,
    });
    phone.advance(const Duration(minutes: 1));
    await phone.services.mutator.update(EntityTypes.task, task, {
      TaskFields.content: 'Отчёт тел',
      TaskFields.priority: 2,
    });
    await syncBoth();
    await onPc.tasks.setPriority(task, 4);
    await syncBoth();

    final card = (await repoOf(pc).load()).single;
    expect(card.older.isThisDevice, isTrue);
    expect(card.older.fields.keys, [TaskFields.content]);
    final ops = await written(pc, () => commandsOf(pc).keep(card, card.older));
    expect(ops, contains((EntityTypes.task, TaskFields.content, 'Отчёт ПК')));
    expect(ops.where((op) => op.$2 == TaskFields.priority), isEmpty);
    await syncBoth();
    for (final dev in [onPc, onPhone]) {
      final kept = (await dev.read()).task(task)!;
      expect((kept.content, kept.priority), ('Отчёт ПК', 4));
    }
  });

  test('перенос в разные проекты, раздел поменяли после спора — выбор другой '
      'стороны пишет место целиком и переносит задачу на обоих; карточка '
      'показывает раздел, который сбросится (решение 4А «Ход M4.3»)', () async {
    final work = await onPc.projects.add(name: 'Работа');
    final home = await onPc.projects.add(name: 'Дом');
    final kitchen = await onPc.sections.add(home, name: 'Кухня');
    final later = await onPc.sections.add(inboxProjectId, name: 'Позже');
    final lamp = await onPc.tasks.add(content: 'Лампа');
    await onPc.tasks.move(lamp, projectId: inboxProjectId, sectionId: later);
    await syncBoth();

    await onPc.tasks.move(lamp, projectId: work);
    phone.advance(const Duration(minutes: 1));
    await onPhone.tasks.move(lamp, projectId: home);
    await syncBoth();
    await onPhone.tasks.move(lamp, projectId: home, sectionId: kitchen);
    await syncBoth();

    final card = (await repoOf(pc).load()).single;
    final byPc = card.older.isThisDevice ? card.older : card.newer;
    // Место целиком — с порядком, который записал перенос ПК.
    expect(byPc.fields.keys.toSet(), {
      TaskFields.projectId,
      TaskFields.sectionId,
      TaskFields.parentId,
      TaskFields.orderKey,
    });
    expect(
      (
        byPc.fields[TaskFields.projectId],
        byPc.fields[TaskFields.sectionId],
        byPc.fields[TaskFields.parentId],
      ),
      (work, null, null),
    );
    expect(byPc.values.map((v) => v.field), [
      ConflictField.project,
      ConflictField.section,
    ]);
    expect(byPc.values.last.value, isNull);
    final section = card.current.singleWhere(
      (v) => v.field == ConflictField.section,
    );
    expect((section.value! as ConflictRef).title, 'Кухня');

    await commandsOf(pc).keep(card, byPc);
    await syncBoth();
    for (final dev in [onPc, onPhone]) {
      final task = (await dev.read()).task(lamp)!;
      expect((task.projectId, task.sectionId), (work, null));
    }
  });

  test('название спорили в двух периодах — старый спор названия в карточке '
      'позднего; ранняя показывает только приоритет и не закрывает новую '
      '(решение 5А «Ход M4.3»)', () async {
    final task = await onPc.tasks.add(content: 'Отчёт');
    await syncBoth();

    await pc.services.mutator.update(EntityTypes.task, task, {
      TaskFields.content: 'A1',
      TaskFields.priority: 1,
    });
    phone.advance(const Duration(minutes: 1));
    await phone.services.mutator.update(EntityTypes.task, task, {
      TaskFields.content: 'B1',
      TaskFields.priority: 3,
    });
    await syncBoth();
    await onPc.tasks.rename(task, 'A2');
    await onPhone.tasks.rename(task, 'B2');
    await syncBoth();

    expect(await pc.conflicts(), hasLength(3));
    final cards = await repoOf(pc).load();
    expect(cards, hasLength(2));
    final early = cards.singleWhere(
      (c) => c.older.values.single.field == ConflictField.priority,
    );
    final late = cards.singleWhere((c) => c != early);
    expect(early.older.fields.keys, [TaskFields.priority]);
    expect(early.conflictIds, hasLength(1));
    expect(late.conflictIds, hasLength(2));
    expect(
      {
        for (final s in [late.older, late.newer]) s.values.single.value,
      },
      {'A2', 'B2'},
    );

    await commandsOf(pc).keep(early, early.older);
    await syncBoth();
    final left = (await repoOf(phone).load()).single;
    expect(left.conflictIds, late.conflictIds);
    await commandsOf(phone).keep(left, left.older);
    await syncBoth();
    for (final dev in [pc, phone]) {
      expect(await repoOf(dev).load(), isEmpty);
    }
  });

  test('последняя правка ПК спорит с двумя периодами телефона — название '
      'в карточке позднего: у телефона его последнее название', () async {
    final task = await onPc.tasks.add(content: 'Отчёт');
    await syncBoth();

    await onPc.tasks.setPriority(task, 1);
    await onPhone.tasks.rename(task, 'y1');
    // Телефон получает приоритет ПК, ПК правок телефона пока не видит.
    await phone.services.engine.applyAll(await pc.ownOps());
    phone.advance(const Duration(minutes: 1));
    await onPhone.tasks.rename(task, 'y2');
    pc.advance(const Duration(minutes: 5));
    await onPc.tasks.rename(task, 'x');
    await syncBoth();

    expect(await pc.conflicts(), hasLength(2));
    for (final dev in [pc, phone]) {
      final card = (await repoOf(dev).load()).single;
      expect(card.conflictIds, hasLength(2));
      expect(
        [
          for (final s in [card.older, card.newer]) s.values.single.value,
        ],
        ['y2', 'x'],
      );
    }
  });

  test('последняя правка телефона спорит с двумя периодами ПК, ПК в раннем не '
      'знал ничего чужого — название в карточке позднего', () async {
    final task = await onPc.tasks.add(content: 'Отчёт');
    await syncBoth();

    await onPhone.tasks.setPriority(task, 1);
    await onPc.tasks.rename(task, 'y1');
    await pc.services.engine.applyAll(await phone.ownOps());
    pc.advance(const Duration(minutes: 1));
    await onPc.tasks.rename(task, 'y2');
    phone.advance(const Duration(minutes: 5));
    await onPhone.tasks.rename(task, 'x');
    await syncBoth();

    expect(await pc.conflicts(), hasLength(2));
    final card = (await repoOf(pc).load()).single;
    expect(
      [
        for (final s in [card.older, card.newer]) s.values.single.value,
      ],
      ['y2', 'x'],
    );
  });

  test('ПК переименовал и поставил приоритет, телефон только переименовал — '
      'карточка только о названии; выбор телефона приоритет не трогает '
      '(решение 6А «Ход M4.3»)', () async {
    final task = await onPc.tasks.add(content: 'Отчёт');
    await syncBoth();

    await pc.services.mutator.update(EntityTypes.task, task, {
      TaskFields.content: 'Отчёт ПК',
      TaskFields.priority: 1,
    });
    phone.advance(const Duration(minutes: 1));
    await onPhone.tasks.rename(task, 'Отчёт тел');
    await syncBoth();

    final card = (await repoOf(pc).load()).single;
    final byPhone = card.older.isThisDevice ? card.newer : card.older;
    expect(byPhone.fields.keys, [TaskFields.content]);
    expect(card.older.values.map((v) => v.field), [ConflictField.content]);
    await commandsOf(pc).keep(card, byPhone);
    await syncBoth();
    for (final dev in [onPc, onPhone]) {
      final kept = (await dev.read()).task(task)!;
      expect((kept.content, kept.priority), ('Отчёт тел', 1));
    }
  });

  test('ПК получил только раннюю правку телефона — каждое поле на одной '
      'карточке, выбор на одной не откатывает другую', () async {
    final task = await onPc.tasks.add(content: 'Отчёт');
    await syncBoth();

    await pc.services.mutator.update(EntityTypes.task, task, {
      TaskFields.content: 'A1',
      TaskFields.priority: 1,
    });
    await onPhone.tasks.setDescription(task, 'план');
    final early = await phone.ownOps();
    phone.advance(const Duration(minutes: 1));
    await phone.services.mutator.update(EntityTypes.task, task, {
      TaskFields.content: 'B1',
      TaskFields.priority: 3,
    });
    await pc.services.engine.applyAll(early);
    pc.advance(const Duration(minutes: 5));
    await onPc.tasks.rename(task, 'A2');
    await syncBoth();

    final cards = await repoOf(pc).load();
    expect(cards, hasLength(2));
    final fields = [
      for (final card in cards) {for (final v in card.older.values) v.field},
    ];
    expect(
      fields,
      unorderedEquals([
        {ConflictField.content},
        {ConflictField.priority},
      ]),
    );
    for (final card in cards) {
      final byPhone = card.older.isThisDevice ? card.newer : card.older;
      await commandsOf(pc).keep(card, byPhone);
    }
    await syncBoth();
    for (final dev in [onPc, onPhone]) {
      final kept = (await dev.read()).task(task)!;
      expect((kept.content, kept.priority), ('B1', 3));
    }
  });

  test('ПК дважды переименовал офлайн, второй раз — как телефон потом — '
      'стороны совпали: у ПК его последнее название', () async {
    final task = await onPc.tasks.add(content: 'Отчёт');
    await syncBoth();

    await onPc.tasks.setPriority(task, 1);
    final early = await pc.ownOps();
    await onPc.tasks.rename(task, 'a1');
    pc.advance(const Duration(minutes: 1));
    await onPc.tasks.rename(task, 'итог');
    await onPhone.tasks.rename(task, 'b1');
    await phone.services.engine.applyAll(early);
    phone.advance(const Duration(minutes: 1));
    await onPhone.tasks.rename(task, 'итог');
    await syncBoth();

    final card = (await repoOf(pc).load()).single;
    expect([...card.older.values, ...card.newer.values], isEmpty);
    expect((card.older.isCurrent, card.newer.isCurrent), (true, true));
  });

  test('телефон в споре в итоге вернулся к названию ПК, потом название '
      'поменяли — выбор его не откатывает (решение 3А)', () async {
    final task = await onPc.tasks.add(content: 'Отчёт');
    await syncBoth();

    await onPc.tasks.rename(task, 'X');
    await onPhone.tasks.rename(task, 'Y');
    phone.advance(const Duration(minutes: 1));
    await onPhone.tasks.rename(task, 'X');
    await syncBoth();
    await onPc.tasks.rename(task, 'Z');
    await syncBoth();

    final card = (await repoOf(pc).load()).single;
    final ops = await written(pc, () => commandsOf(pc).keep(card, card.older));
    expect(ops.where((op) => op.$2 == TaskFields.content), isEmpty);
    await syncBoth();
    for (final dev in [onPc, onPhone]) {
      expect((await dev.read()).task(task)!.content, 'Z');
    }
  });

  test('периоды несравнимы (каждое устройство получило часть чужих правок) — '
      'карточки на обоих одинаковые', () async {
    final task = await onPc.tasks.add(content: 'Отчёт');
    await syncBoth();

    await onPc.tasks.setPriority(task, 1);
    await onPhone.tasks.setDescription(task, 'план');
    await phone.services.engine.applyAll(await pc.ownOps());
    await onPc.tasks.rename(task, 'a1');
    await pc.services.engine.applyAll(await phone.ownOps());
    pc.advance(const Duration(minutes: 1));
    await onPc.tasks.rename(task, 'итог');
    await onPhone.tasks.rename(task, 'b1');
    phone.advance(const Duration(minutes: 1));
    await onPhone.tasks.rename(task, 'итог');
    await syncBoth();

    ConflictSide plain(ConflictSide s) =>
        s.copyWith(isThisDevice: false, isFormerThisDevice: false);
    List<List<Object>> shape(List<ConflictCard> cards) => [
      for (final c in cards) [c.conflictIds, plain(c.older), plain(c.newer)],
    ];
    final onPcCards = await repoOf(pc).load();
    expect(onPcCards, isNotEmpty);
    expect(shape(await repoOf(phone).load()), shape(onPcCards));
  });

  test('приоритет спорили только в позднем периоде — ранняя карточка его не '
      'пишет, хотя её действие меняло приоритет', () async {
    final task = await onPc.tasks.add(content: 'Отчёт');
    await syncBoth();

    await pc.services.mutator.update(EntityTypes.task, task, {
      TaskFields.content: 'A1',
      TaskFields.priority: 1,
    });
    phone.advance(const Duration(minutes: 1));
    await onPhone.tasks.rename(task, 'B1');
    await syncBoth();
    await onPc.tasks.setPriority(task, 2);
    await onPhone.tasks.setPriority(task, 3);
    await syncBoth();

    final cards = await repoOf(pc).load();
    expect(cards, hasLength(2));
    final early = cards.singleWhere(
      (c) => c.older.values.any((v) => v.field == ConflictField.content),
    );
    expect(early.older.fields.keys, [TaskFields.content]);
    expect(early.newer.fields.keys, [TaskFields.content]);
  });

  test('место задачи спорили в двух периодах — уходит в позднюю карточку '
      'целиком: ранняя не пишет ни проект, ни раздел', () async {
    final work = await onPc.projects.add(name: 'Работа');
    final home = await onPc.projects.add(name: 'Дом');
    final week = await onPc.sections.add(work, name: 'Неделя');
    final kitchen = await onPc.sections.add(home, name: 'Кухня');
    final later = await onPc.sections.add(inboxProjectId, name: 'Позже');
    final lamp = await onPc.tasks.add(content: 'Лампа');
    await onPc.tasks.move(lamp, projectId: inboxProjectId, sectionId: later);
    await syncBoth();

    await pc.services.mutator.update(EntityTypes.task, lamp, {
      TaskFields.content: 'A1',
      TaskFields.projectId: work,
      TaskFields.sectionId: null,
    });
    phone.advance(const Duration(minutes: 1));
    await phone.services.mutator.update(EntityTypes.task, lamp, {
      TaskFields.content: 'B1',
      TaskFields.projectId: home,
      TaskFields.sectionId: null,
    });
    await syncBoth();
    await onPc.tasks.move(lamp, projectId: work, sectionId: week);
    await onPhone.tasks.move(lamp, projectId: home, sectionId: kitchen);
    await syncBoth();

    final cards = await repoOf(pc).load();
    expect(cards, hasLength(2));
    final early = cards.singleWhere(
      (c) => c.older.values.any((v) => v.field == ConflictField.content),
    );
    expect(early.older.fields.keys, [TaskFields.content]);
    expect(early.newer.fields.keys, [TaskFields.content]);
    final late = cards.singleWhere((c) => c != early);
    final placementIds = [
      for (final c in await pc.conflicts())
        if (c.field == TaskFields.projectId || c.field == TaskFields.sectionId)
          c.id,
    ];
    expect(late.conflictIds, unorderedEquals(placementIds));

    // Ранняя карточка не трогает место, поздняя пишет его целиком.
    final byPhoneEarly = early.older.isThisDevice ? early.newer : early.older;
    final ops = await written(
      pc,
      () => commandsOf(pc).keep(early, byPhoneEarly),
    );
    expect(
      ops.where(
        (op) => op.$2 == TaskFields.projectId || op.$2 == TaskFields.sectionId,
      ),
      isEmpty,
    );
    final byPcLate = late.older.isThisDevice ? late.older : late.newer;
    await commandsOf(pc).keep(late, byPcLate);
    await syncBoth();
    for (final dev in [onPc, onPhone]) {
      final kept = (await dev.read()).task(lamp)!;
      expect(
        (kept.content, kept.projectId, kept.sectionId),
        ('B1', work, week),
      );
    }
    for (final dev in [pc, phone]) {
      expect(await repoOf(dev).load(), isEmpty);
    }
  });

  test('«выполнена» спорили в двух периодах — уходит в позднюю карточку с '
      'датой выполнения: ранняя пишет только название', () async {
    final task = await onPc.tasks.add(content: 'Отчёт');
    await syncBoth();
    Future<void> set(TestDevice dev, Map<String, Object?> fields) async {
      dev.advance(const Duration(minutes: 1));
      await dev.services.mutator.update(EntityTypes.task, task, fields);
    }

    const done = '2026-11-03T10:00:00.000Z';
    await set(pc, {
      TaskFields.content: 'A1',
      TaskFields.isCompleted: true,
      TaskFields.completedAt: done,
    });
    await set(phone, {
      TaskFields.content: 'B1',
      TaskFields.isCompleted: true,
      TaskFields.completedAt: done,
    });
    await set(phone, {
      TaskFields.content: 'B2',
      TaskFields.isCompleted: false,
      TaskFields.completedAt: null,
    });
    await syncBoth();
    await set(pc, {TaskFields.isCompleted: true, TaskFields.completedAt: done});
    await set(phone, {
      TaskFields.isCompleted: true,
      TaskFields.completedAt: done,
    });
    await set(phone, {
      TaskFields.isCompleted: false,
      TaskFields.completedAt: null,
    });
    await syncBoth();

    final cards = await repoOf(pc).load();
    expect(cards, hasLength(2));
    final early = cards.singleWhere(
      (c) => c.older.values.any((v) => v.field == ConflictField.content),
    );
    expect(early.older.fields.keys, [TaskFields.content]);
    expect(early.newer.fields.keys, [TaskFields.content]);
    final late = cards.singleWhere((c) => c != early);
    expect(
      late.conflictIds,
      unorderedEquals([
        for (final c in await pc.conflicts())
          if (c.field == TaskFields.isCompleted) c.id,
      ]),
    );
    expect(late.older.fields.keys.toSet(), {
      TaskFields.isCompleted,
      TaskFields.completedAt,
      TaskFields.completedLabelNames,
    });
  });

  test('место совпало, разошёлся только порядок, задачу потом переставили — '
      'выбор порядок не трогает: на карточке его нет', () async {
    final work = await onPc.projects.add(name: 'Работа');
    final home = await onPc.projects.add(name: 'Дом');
    final lamp = await onPc.tasks.add(content: 'Лампа');
    await syncBoth();

    await onPc.tasks.move(lamp, projectId: home);
    await onPc.tasks.move(lamp, projectId: work);
    await onPc.tasks.rename(lamp, 'A');
    phone.advance(const Duration(minutes: 1));
    // Своя задача в «Работе» — перенос телефона получит другой порядок.
    await onPhone.tasks.add(content: 'Другая', projectId: work);
    await onPhone.tasks.move(lamp, projectId: work);
    await onPhone.tasks.rename(lamp, 'B');
    await syncBoth();
    await phone.services.mutator.update(EntityTypes.task, lamp, {
      TaskFields.orderKey: 'zz',
    });
    await syncBoth();

    final card = (await repoOf(pc).load()).single;
    final byPc = card.older.isThisDevice ? card.older : card.newer;
    expect(byPc.fields.keys, [TaskFields.content]);
    await commandsOf(pc).keep(card, byPc);
    await syncBoth();
    for (final dev in [onPc, onPhone]) {
      final kept = (await dev.read()).task(lamp)!;
      expect((kept.content, kept.projectId, kept.orderKey), ('A', work, 'zz'));
    }
  });

  test('раздел перенесли в разные проекты — выбор пишет проект с порядком '
      'своего переноса', () async {
    final work = await onPc.projects.add(name: 'Работа');
    final home = await onPc.projects.add(name: 'Дом');
    final week = await onPc.sections.add(work, name: 'Неделя');
    await syncBoth();

    await onPc.sections.moveToProject(week, home);
    final pcKey = (await onPc.read()).section(week)!.orderKey;
    phone.advance(const Duration(minutes: 1));
    await onPhone.sections.moveToProject(week, inboxProjectId);
    await syncBoth();

    final card = (await repoOf(pc).load()).single;
    final byPc = card.older.isThisDevice ? card.older : card.newer;
    expect(byPc.fields, {
      SectionFields.projectId: home,
      SectionFields.orderKey: pcKey,
    });
    await commandsOf(pc).keep(card, byPc);
    await syncBoth();
    for (final app in [onPc, onPhone]) {
      final section = (await app.read()).section(week)!;
      expect((section.projectId, section.orderKey), (home, pcKey));
    }
  });

  test('новый конфликт того же периода вошёл в карточку — о ней уведомляют '
      'снова', () async {
    final task = await onPc.tasks.add(content: 'Отчёт');
    await syncBoth();

    await onPc.tasks.rename(task, 'Отчёт ПК');
    await onPhone.tasks.rename(task, 'Отчёт 1');
    // ПК получает правки телефона, телефон правки ПК — нет: период один.
    await pc.services.engine.applyAll(await phone.ownOps());
    final first = await repoOf(pc).takeUnnotified();
    expect(first.single.conflictIds, hasLength(1));
    expect(await repoOf(pc).takeUnnotified(), isEmpty);

    phone.advance(const Duration(minutes: 1));
    await onPhone.tasks.rename(task, 'Отчёт 2');
    await pc.services.engine.applyAll(await phone.ownOps());
    final again = await repoOf(pc).takeUnnotified();
    expect(again.single.conflictIds, hasLength(2));
    expect(again.single.conflictIds, containsAll(first.single.conflictIds));
  });

  test('поля победили у разных сторон — ни одна не действует целиком, '
      'карточка показывает действующие значения', () async {
    final task = await onPc.tasks.add(content: 'Отчёт');
    await syncBoth();

    await onPc.tasks.rename(task, 'Отчёт ПК');
    phone.advance(const Duration(minutes: 1));
    await onPhone.tasks.setPriority(task, 3);
    pc.advance(const Duration(minutes: 2));
    await onPc.tasks.setPriority(task, 1);
    phone.advance(const Duration(minutes: 2));
    await onPhone.tasks.rename(task, 'Отчёт тел');
    await syncBoth();

    final card = (await repoOf(pc).load()).single;
    expect((card.older.isCurrent, card.newer.isCurrent), (false, false));
    expect(card.current.map((v) => (v.field, v.value)), [
      (ConflictField.content, 'Отчёт тел'),
      (ConflictField.priority, 1),
    ]);
  });

  test('три устройства правят название параллельно — карточка на каждую '
      'пару; выбор на одной закрывает спор поля и с третьим', () async {
    final tablet = await TestDevice.start(seed: 3);
    Future<void> syncAll() async {
      for (var round = 0; round < 2; round++) {
        for (final dev in [pc, phone, tablet]) {
          await dev.folder(IoSyncFs(folder)).syncOnce();
        }
      }
      pc.advance(const Duration(seconds: 1));
      phone.advance(const Duration(seconds: 2));
      tablet.advance(const Duration(seconds: 3));
    }

    final task = await onPc.tasks.add(content: 'Отчёт');
    await syncAll();
    await onPc.tasks.rename(task, 'ПК');
    await onPhone.tasks.rename(task, 'Телефон');
    await AppCommands(tablet).tasks.rename(task, 'Планшет');
    await syncAll();

    final cards = await repoOf(pc).load();
    expect(cards, hasLength(3));
    expect({for (final c in cards) c.conflictIds.single}, hasLength(3));

    await commandsOf(pc).keep(cards.first, cards.first.older);
    await syncAll();
    for (final dev in [pc, phone, tablet]) {
      expect(await repoOf(dev).load(), isEmpty);
    }
  });

  test('споры правки и споры удаления одной задачи — по-прежнему отдельные '
      'карточки: удаление решает только «deleted»', () async {
    final task = await onPc.tasks.add(content: 'Отчёт');
    await syncBoth();

    await onPc.tasks.rename(task, 'Отчёт ПК');
    phone.advance(const Duration(minutes: 1));
    await onPhone.tasks.rename(task, 'Отчёт тел');
    pc.advance(const Duration(minutes: 2));
    await onPc.tasks.delete(task);
    await syncBoth();

    final cards = await repoOf(pc).load();
    expect(cards.map((c) => c.isDelete).toSet(), {false, true});
    expect(cards, hasLength(2));
  });

  test('задача удалена на ПК и переименована на телефоне — одна карточка '
      'удаления; «Восстановить» возвращает её на обоих', () async {
    final task = await onPc.tasks.add(content: 'Отчёт');
    await syncBoth();

    await onPc.tasks.delete(task);
    await onPhone.tasks.rename(task, 'Отчёт v2');
    await onPhone.tasks.setPriority(task, 1);
    await syncBoth();

    final card = (await repoOf(pc).load()).single;
    expect(card.isDelete, isTrue);
    expect(card.title, 'Отчёт v2');
    final deletion = card.older.deletes ? card.older : card.newer;
    final edit = card.older.deletes ? card.newer : card.older;
    expect(deletion.isCurrent, isTrue);
    expect(deletion.isThisDevice, isTrue);
    expect(edit.values.map((v) => (v.field, v.value)), [
      (ConflictField.content, 'Отчёт v2'),
      (ConflictField.priority, 1),
    ]);

    await commandsOf(pc).keep(card, edit);
    await syncBoth();
    for (final dev in [onPc, onPhone]) {
      expect((await dev.read()).task(task)?.content, 'Отчёт v2');
    }
    expect(await repoOf(phone).load(), isEmpty);
  });

  test('поле правили после конфликта — действующее значение в карточке; '
      '«Оставить текущее» закрывает конфликт, не меняя его', () async {
    final task = await onPc.tasks.add(content: 'a');
    await syncBoth();
    await onPc.tasks.rename(task, 'b');
    await onPhone.tasks.rename(task, 'c');
    await syncBoth();
    await onPhone.tasks.rename(task, 'd');

    final card = (await repoOf(phone).load()).single;
    expect((card.older.isCurrent, card.newer.isCurrent), (false, false));
    expect(card.current.map((v) => v.value), ['d']);

    await commandsOf(phone).keepCurrent(card);
    await syncBoth();
    for (final dev in [onPc, onPhone]) {
      expect((await dev.read()).task(task)!.content, 'd');
    }
    expect(await repoOf(pc).load(), isEmpty);
  });

  test('записанный раньше конфликт по «молчащему» полю не показывается и не '
      'уведомляется', () async {
    await phone.services.store.putConflict(
      const Conflict(
        id: 'old-completed-at',
        kind: ConflictKind.edit,
        entityType: EntityTypes.task,
        entityId: 'task',
        field: TaskFields.completedAt,
        olderOpId: 'a',
        newerOpId: 'b',
      ),
    );
    expect(await repoOf(phone).load(), isEmpty);
    expect(await repoOf(phone).takeUnnotified(), isEmpty);
  });

  test('записанный раньше конфликт по записи о выполнении (молчащий тип) не '
      'показывается и не уведомляется', () async {
    await phone.services.store.putConflict(
      const Conflict(
        id: 'old-completion',
        kind: ConflictKind.delete,
        entityType: EntityTypes.completion,
        entityId: 'completion',
        field: CompletionFields.dueWas,
        olderOpId: 'a',
        newerOpId: 'b',
      ),
    );
    expect(await repoOf(phone).load(), isEmpty);
    expect(await repoOf(phone).takeUnnotified(), isEmpty);
  });

  test('«выполнена» против «не выполнена»: выбор проигравшей стороны пишет и '
      'дату выполнения — задача согласована на обоих', () async {
    final task = await onPc.tasks.add(content: 'a');
    await onPc.tasks.complete(task);
    await syncBoth();
    await onPc.tasks.uncomplete(task);
    await onPhone.tasks.uncomplete(task);
    await onPhone.tasks.complete(task);
    await syncBoth();

    final card = (await repoOf(pc).load()).single;
    final loser = card.older.isCurrent ? card.newer : card.older;
    expect(loser.values.map((v) => v.field), [ConflictField.completed]);
    expect(loser.fields.keys, contains(TaskFields.completedAt));
    await commandsOf(pc).keep(card, loser);
    await syncBoth();
    for (final dev in [pc, phone]) {
      final row = (await dev.taskRow(task))!;
      expect(row.isCompleted, loser.fields[TaskFields.isCompleted]);
      expect(row.completedAt == null, !row.isCompleted);
    }
  });

  test('выбор действующей стороны и «Оставить удалённым» при действующем '
      'удалении пишут только отметки «решено»; «Восстановить» — ещё '
      'deleted=false', () async {
    final work = await onPc.projects.add(name: 'Работа');
    final home = await onPc.projects.add(name: 'Дом');
    final week = await onPc.sections.add(work, name: 'Неделя');
    final kitchen = await onPc.sections.add(home, name: 'Кухня');
    final lamp = await onPc.tasks.add(content: 'Лампа');
    final report = await onPc.tasks.add(content: 'Отчёт');
    final memo = await onPc.tasks.add(content: 'Записка');
    await syncBoth();
    await onPc.tasks.move(lamp, projectId: work, sectionId: week);
    await onPhone.tasks.move(lamp, projectId: home, sectionId: kitchen);
    for (final id in [report, memo]) {
      await onPc.tasks.delete(id);
      await onPhone.tasks.rename(id, 'v2');
    }
    await syncBoth();

    final cards = {for (final c in await repoOf(pc).load()) c.entityId: c};
    final move = cards[lamp]!;
    final current = move.older.isCurrent ? move.older : move.newer;
    expect(await written(pc, () => commandsOf(pc).keep(move, current)), [
      resolved,
      resolved,
    ]);
    ConflictSide deletion(ConflictCard c) =>
        c.older.deletes ? c.older : c.newer;
    ConflictSide edit(ConflictCard c) => c.older.deletes ? c.newer : c.older;
    expect(
      await written(
        pc,
        () => commandsOf(pc).keep(cards[report]!, deletion(cards[report]!)),
      ),
      [resolved],
    );
    expect(
      await written(
        pc,
        () => commandsOf(pc).keep(cards[memo]!, edit(cards[memo]!)),
      ),
      [(EntityTypes.task, TaskFields.deleted, false), resolved],
    );
    expect(await repoOf(pc).load(), isEmpty);
  });

  test('«удалено» против «восстановлено» — карточка удаления; устаревшая '
      'карточка после выбора на другом устройстве ничего не пишет', () async {
    final task = await onPc.tasks.add(content: 'a');
    await onPc.tasks.delete(task);
    await syncBoth();
    await pc.services.mutator.restore(EntityTypes.task, task);
    await phone.services.mutator.restore(EntityTypes.task, task);
    await phone.services.mutator.delete(EntityTypes.task, task);
    await syncBoth();

    final card = (await repoOf(pc).load()).single;
    expect(card.isDelete, isTrue);
    final restored = card.older.deletes ? card.newer : card.older;
    expect(restored.values.single.value, isFalse);

    final stale = (await repoOf(phone).load()).single;
    await commandsOf(pc).keep(card, restored);
    await syncBoth();
    final deletion = stale.older.deletes ? stale.older : stale.newer;
    expect(
      await written(phone, () => commandsOf(phone).keep(stale, deletion)),
      isEmpty,
    );
    for (final dev in [onPc, onPhone]) {
      expect((await dev.read()).task(task), isNotNull);
    }
  });

  test('первый конфликт карточки уже закрыт, второй открыт — выбор всё равно '
      'записывается целиком', () async {
    final work = await onPc.projects.add(name: 'Работа');
    final home = await onPc.projects.add(name: 'Дом');
    final week = await onPc.sections.add(work, name: 'Неделя');
    final kitchen = await onPc.sections.add(home, name: 'Кухня');
    final lamp = await onPc.tasks.add(content: 'Лампа');
    await syncBoth();
    await onPc.tasks.move(lamp, projectId: work, sectionId: week);
    await onPhone.tasks.move(lamp, projectId: home, sectionId: kitchen);
    await syncBoth();

    final card = (await repoOf(pc).load()).single;
    expect(card.conflictIds, hasLength(2));
    await pc.services.mutator.resolveConflict(card.conflictIds.first, {});
    final loser = card.older.isCurrent ? card.newer : card.older;
    await commandsOf(pc).keep(card, loser);
    final moved = (await onPc.read()).task(lamp)!;
    expect(
      (moved.projectId, moved.sectionId),
      (loser.fields[TaskFields.projectId], loser.fields[TaskFields.sectionId]),
    );
    expect(await repoOf(pc).load(), isEmpty);
  });

  test('перенос с разделом против переноса без смены раздела — карточка '
      'показывает раздел у обеих сторон; выбор второй возвращает «Без '
      'раздела» на обоих (решение 5А)', () async {
    final work = await onPc.projects.add(name: 'Работа');
    final home = await onPc.projects.add(name: 'Дом');
    final week = await onPc.sections.add(work, name: 'Неделя');
    final lamp = await onPc.tasks.add(content: 'Лампа');
    await syncBoth();
    await onPc.tasks.move(lamp, projectId: work, sectionId: week);
    await onPhone.tasks.move(lamp, projectId: home);
    await syncBoth();

    final card = (await repoOf(phone).load()).single;
    expect(card.conflictIds, hasLength(1), reason: 'спор только о проекте');
    final byPhone = card.older.isThisDevice ? card.older : card.newer;
    final byPc = card.older.isThisDevice ? card.newer : card.older;
    expect(byPhone.values.map((v) => v.field), [
      ConflictField.project,
      ConflictField.section,
    ]);
    expect(byPhone.values.last.value, isNull);
    expect((byPc.values.last.value! as ConflictRef).title, 'Неделя');

    await commandsOf(phone).keep(card, byPhone);
    await syncBoth();
    for (final dev in [onPc, onPhone]) {
      final task = (await dev.read()).task(lamp)!;
      expect((task.projectId, task.sectionId), (home, null));
    }
  });

  test('выбор действующей стороны после перестановки задачи не возвращает '
      'прежний порядок — только отметки «решено»', () async {
    final work = await onPc.projects.add(name: 'Работа');
    final home = await onPc.projects.add(name: 'Дом');
    final lamp = await onPc.tasks.add(content: 'Лампа');
    await onPc.tasks.add(content: 'Отчёт', projectId: work);
    await onPc.tasks.add(content: 'Обои', projectId: home);
    await syncBoth();
    await onPc.tasks.move(lamp, projectId: work);
    await onPhone.tasks.move(lamp, projectId: home);
    await syncBoth();
    await pc.services.mutator.update(EntityTypes.task, lamp, {
      TaskFields.orderKey: 'zz',
    });

    final card = (await repoOf(pc).load()).single;
    final current = card.older.isCurrent ? card.older : card.newer;
    expect(await written(pc, () => commandsOf(pc).keep(card, current)), [
      resolved,
    ]);
    expect((await pc.taskRow(lamp))!.orderKey, 'zz');
  });

  test('«Восстановить» в карточке, уже решённой «Оставить удалённым» на '
      'другом устройстве, — ничего не пишет и не сообщает «скрыто»', () async {
    final task = await onPc.tasks.add(content: 'Отчёт');
    await syncBoth();
    await onPc.tasks.delete(task);
    await onPhone.tasks.rename(task, 'Отчёт v2');
    await syncBoth();

    final stale = (await repoOf(pc).load()).single;
    final onPhoneCard = (await repoOf(phone).load()).single;
    await commandsOf(phone).keep(
      onPhoneCard,
      onPhoneCard.older.deletes ? onPhoneCard.older : onPhoneCard.newer,
    );
    await syncBoth();

    final restore = stale.older.deletes ? stale.newer : stale.older;
    late bool hidden;
    expect(
      await written(pc, () async {
        hidden = await commandsOf(pc).keep(stale, restore);
      }),
      isEmpty,
    );
    expect(hidden, isFalse);
    expect((await onPc.read()).task(task), isNull);
  });
}

final class _CursorFailure implements Exception {}

/// Хранилище состояния, у которого первый сдвиг курсора падает: чанк уже
/// применён, а курсор остаётся прежним — как при сбое между ними.
final class _CursorFailsOnce implements SyncStateStore {
  _CursorFailsOnce(this._inner);

  final SyncStateStore _inner;
  bool _failed = false;

  @override
  Future<void> setChunkCursor(String nodeId, int seq) async {
    if (!_failed) {
      _failed = true;
      throw _CursorFailure();
    }
    await _inner.setChunkCursor(nodeId, seq);
  }

  @override
  Future<int> chunkCursor(String nodeId) => _inner.chunkCursor(nodeId);

  @override
  Future<String?> folderId() => _inner.folderId();

  @override
  Future<void> forgetFolder() => _inner.forgetFolder();

  @override
  Future<void> resetForFolder(String folderId) =>
      _inner.resetForFolder(folderId);

  @override
  Future<Hlc?> uploadedUpTo() => _inner.uploadedUpTo();

  @override
  Future<void> setUploadedUpTo(Hlc hlc) => _inner.setUploadedUpTo(hlc);
}
