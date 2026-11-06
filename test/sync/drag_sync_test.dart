import 'package:flutter_test/flutter_test.dart';
import 'package:planner/domain/conflicts.dart';
import 'package:planner/domain/models.dart';
import 'package:planner/domain/view_options.dart';
import 'package:planner/domain/workspace.dart';
import 'package:planner/sync/conflict_repository.dart';
import 'package:planner/sync/io_sync_fs.dart';

import '../data/support/drift_probe.dart';
import '../features/support/app_commands.dart';
import 'support/devices.dart';

// Перетаскивание (M4.9) на двух устройствах: одно действие — одна карточка,
// перестановки сходятся без карточки, смена дня и порядок дня сходятся.
void main() {
  late TestDevice pc;
  late TestDevice phone;
  late AppCommands onPc;
  late AppCommands onPhone;
  late String folder;

  setUp(() async {
    folder = tempDir('drag_sync_').path;
    pc = await TestDevice.start(seed: 1);
    phone = await TestDevice.start(seed: 2);
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
    pc.advance(const Duration(seconds: 1));
    phone.advance(const Duration(seconds: 2));
  }

  /// Пересборка из журнала не меняет базу ни на одном устройстве, и базы
  /// устройств совпадают.
  Future<void> expectStableAndSame() async {
    final states = <Map<String, Object?>>[];
    for (final dev in [pc, phone]) {
      final before = await dumpSyncedState(dev.db);
      await dev.services.engine.rebuild();
      expect(await dumpSyncedState(dev.db), before, reason: dev.nodeId);
      states.add(before);
    }
    expect(states[1]['field_versions'], states[0]['field_versions']);
    expect(states[1]['tasks'], states[0]['tasks']);
  }

  Future<List<ConflictCard>> cards(TestDevice dev) => ConflictRepository(
    db: dev.db,
    store: dev.services.store,
    meta: dev.services.meta,
  ).load();

  Future<void> expectNoCards() async {
    expect(await cards(pc), isEmpty);
    expect(await cards(phone), isEmpty);
  }

  List<String> top(Workspace ws) => [
    for (final t in ws.children(null, projectId: ws.inbox!.id)) t.id,
  ];

  test('бросок под одного родителя на ПК против другого на телефоне — одна '
      'карточка с одним id на обоих', () async {
    final a = await onPc.tasks.add(content: 'А');
    final b = await onPc.tasks.add(content: 'Б');
    final c = await onPc.tasks.add(content: 'В');
    await syncBoth();

    await onPc.tasks.placeAll([b], parentId: a, atTop: true);
    await onPhone.tasks.placeAll([b], parentId: c, atTop: true);
    await syncBoth();

    final onPcCards = await cards(pc);
    expect([for (final card in onPcCards) card.entityId], [b]);
    expect(
      [for (final card in await cards(phone)) card.conflictIds],
      [onPcCards.single.conflictIds],
    );
    expect(
      (await onPc.read()).taskParent(b),
      (await onPhone.read()).taskParent(b),
    );
    await expectStableAndSame();
  });

  test('бросок на проект на ПК против другого проекта на телефоне — одна '
      'карточка', () async {
    final work = await onPc.projects.add(name: 'Работа');
    final home = await onPc.projects.add(name: 'Дом');
    final a = await onPc.tasks.add(content: 'А');
    await syncBoth();

    await onPc.tasks.placeAll([a], projectId: work);
    await onPhone.tasks.placeAll([a], projectId: home);
    await syncBoth();

    expect([for (final card in await cards(pc)) card.entityId], [a]);
    expect([for (final card in await cards(phone)) card.entityId], [a]);
    await expectStableAndSame();
  });

  test(
    'параллельная перестановка задач — без карточки, порядок один',
    () async {
      final ids = [
        for (final name in ['А', 'Б', 'В', 'Г'])
          await onPc.tasks.add(content: name),
      ];
      await syncBoth();

      await onPc.tasks.placeAll([ids[3]], atTop: true);
      await onPhone.tasks.placeAll([ids[1]], afterId: ids[2]);
      await syncBoth();

      expect(await cards(pc), isEmpty);
      expect(await cards(phone), isEmpty);
      expect(top(await onPc.read()), top(await onPhone.read()));
      await expectStableAndSame();
    },
  );

  test('бросок в одно место на обоих — равные ключи не мешают следующей '
      'перестановке (О-8)', () async {
    final ids = [
      for (final name in ['А', 'Б', 'В', 'Г'])
        await onPc.tasks.add(content: name),
    ];
    await syncBoth();

    await onPc.tasks.placeAll([ids[2]], afterId: ids[0]);
    await onPhone.tasks.placeAll([ids[3]], afterId: ids[0]);
    await syncBoth();
    expect(top(await onPc.read()), top(await onPhone.read()));
    final order = top(await onPc.read());

    // Встать между двумя брошенными.
    await onPc.tasks.placeAll([ids[1]], afterId: order[1]);
    await syncBoth();
    for (final dev in [onPc, onPhone]) {
      final now = top(await dev.read());
      expect(now.indexOf(ids[1]), 2);
    }
    await expectStableAndSame();
  });

  test(
    'перестановка подзадачи с устаревшим проектом на ПК против выноса в '
    'другой проект на телефоне — без спора за проект, вынос действует',
    () async {
      final work = await onPc.projects.add(name: 'Работа');
      final home = await onPc.projects.add(name: 'Дом');
      final parent = await onPc.tasks.add(content: 'Родитель');
      final a = await onPc.tasks.add(content: 'А', parentId: parent);
      final b = await onPc.tasks.add(content: 'Б', parentId: parent);
      await onPc.tasks.move(parent, projectId: work);
      await syncBoth();

      await onPc.tasks.placeAll([b], parentId: parent, atTop: true);
      await onPhone.tasks.move(b, projectId: home);
      await syncBoth();

      await expectNoCards();
      for (final dev in [onPc, onPhone]) {
        final ws = await dev.read();
        expect(ws.rootProjectOf(b), home);
        expect(ws.rootProjectOf(a), work);
      }
      await expectStableAndSame();
    },
  );

  test('перестановка подзадачи против переноса её родителя — без карточки: '
      'подзадача не спорит за проект', () async {
    final work = await onPc.projects.add(name: 'Работа');
    final parent = await onPc.tasks.add(content: 'Родитель');
    final a = await onPc.tasks.add(content: 'А', parentId: parent);
    final b = await onPc.tasks.add(content: 'Б', parentId: parent);
    await syncBoth();

    await onPc.tasks.placeAll([b], parentId: parent, atTop: true);
    await onPhone.tasks.move(parent, projectId: work);
    await syncBoth();

    expect(await cards(pc), isEmpty);
    expect(await cards(phone), isEmpty);
    for (final dev in [onPc, onPhone]) {
      final ws = await dev.read();
      expect(ws.rootProjectOf(a), work);
      expect([for (final t in ws.children(parent)) t.id], [b, a]);
    }
    await expectStableAndSame();
  });

  test('параллельная перестановка дня — без карточки', () async {
    const today = '2026-10-23';
    const due = Due(date: today);
    final ids = [
      for (final name in ['А', 'Б', 'В'])
        await onPc.tasks.add(content: name, due: due),
    ];
    await syncBoth();

    await onPc.tasks.reorderInDay(ids[2], today);
    await onPhone.tasks.reorderInDay(
      ids[1],
      today,
      afterId: ids[2],
      sorting: Sorting.manual,
    );
    await syncBoth();

    expect(await cards(pc), isEmpty);
    expect(await cards(phone), isEmpty);
    await expectStableAndSame();
  });

  test('О-71: смена дня снимает ключ на обоих; смена дня на ПК против '
      'перестановки дня на телефоне — без карточки, устройства сходятся, срок '
      'с ПК', () async {
    const today = '2026-10-23';
    const due = Due(date: today);
    final ids = [
      for (final name in ['А', 'Б', 'В'])
        await onPc.tasks.add(content: name, due: due),
    ];
    await onPc.tasks.reorderInDay(ids[1], today);
    await syncBoth();

    await onPc.tasks.moveToDay(ids[1], '2026-10-24');
    await syncBoth();
    for (final dev in [onPc, onPhone]) {
      final task = (await dev.read()).task(ids[1])!;
      expect(task.due?.date, '2026-10-24');
      expect(task.dayOrderKey, isEmpty);
    }

    // Параллельно: ключ может остаться старым — порядок косметический, но
    // устройства сходятся, а срок — с ПК.
    await onPc.tasks.moveToDay(ids[2], '2026-10-25');
    await onPhone.tasks.reorderInDay(ids[2], today);
    await syncBoth();
    await expectNoCards();
    final first = (await onPc.read()).task(ids[2])!;
    final second = (await onPhone.read()).task(ids[2])!;
    expect(first.due?.date, '2026-10-25');
    expect(second.due?.date, '2026-10-25');
    expect(first.dayOrderKey, second.dayOrderKey);
    await expectStableAndSame();
  });

  test('день на ПК против срока на телефоне — одна карточка срока', () async {
    const due = Due(date: '2026-10-23');
    final id = await onPc.tasks.add(content: 'А', due: due);
    await syncBoth();

    await onPc.tasks.moveToDay(id, '2026-10-24');
    await onPhone.tasks.setDue(id, const Due(date: '2026-10-25'));
    await syncBoth();

    expect([for (final card in await cards(pc)) card.entityId], [id]);
    expect([for (final card in await cards(phone)) card.entityId], [id]);
    await expectStableAndSame();
  });

  test('несколько выделенных против правки одной задачи — карточка только '
      'на неё', () async {
    final work = await onPc.projects.add(name: 'Работа');
    final home = await onPc.projects.add(name: 'Дом');
    final a = await onPc.tasks.add(content: 'А');
    final b = await onPc.tasks.add(content: 'Б');
    await syncBoth();

    await onPc.bulk.moveMany([a, b], projectId: work);
    await onPhone.tasks.move(a, projectId: home);
    await syncBoth();

    expect([for (final card in await cards(pc)) card.entityId], [a]);
    expect((await onPc.read()).rootProjectOf(b), work);
    expect((await onPhone.read()).rootProjectOf(b), work);
    await expectStableAndSame();
  });

  test(
    'повторная доставка и долгий офлайн: бросок применяется один раз',
    () async {
      final ids = [
        for (final name in ['А', 'Б', 'В']) await onPc.tasks.add(content: name),
      ];
      await syncBoth();

      pc.advance(const Duration(days: 30));
      phone.advance(const Duration(days: 30));
      await onPc.tasks.placeAll([ids[2]], atTop: true);
      await syncBoth();
      await syncBoth();

      expect(top(await onPhone.read()), [ids[2], ids[0], ids[1]]);
      await expectStableAndSame();
    },
  );
}
