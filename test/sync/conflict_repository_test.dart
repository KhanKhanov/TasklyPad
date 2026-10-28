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
