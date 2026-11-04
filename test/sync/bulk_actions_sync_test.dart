import 'package:flutter_test/flutter_test.dart';
import 'package:planner/data/projection/entity_fields.dart';
import 'package:planner/domain/conflicts.dart';
import 'package:planner/domain/models.dart';
import 'package:planner/sync/conflict_repository.dart';
import 'package:planner/sync/io_sync_fs.dart';

import '../data/support/drift_probe.dart';
import '../features/support/app_commands.dart';
import 'support/devices.dart';

// Действия над выделенными задачами (M4.8) на двух устройствах: массовое
// действие на ПК против правки той же задачи на телефоне офлайн.
void main() {
  late TestDevice pc;
  late TestDevice phone;
  late AppCommands onPc;
  late AppCommands onPhone;
  late String folder;

  setUp(() async {
    folder = tempDir('bulk_actions_').path;
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

  test('массовый перенос в проект на ПК против переноса одной из задач на '
      'телефоне офлайн — одна карточка на эту задачу с одним id на обоих, '
      'остальные перенесены без споров', () async {
    final work = await onPc.projects.add(name: 'Работа');
    final home = await onPc.projects.add(name: 'Дом');
    final a = await onPc.tasks.add(content: 'А');
    final b = await onPc.tasks.add(content: 'Б');
    final c = await onPc.tasks.add(content: 'В');
    await syncBoth();

    await onPc.bulk.move([a, b, c], work, null);
    await onPhone.tasks.move(b, projectId: home);
    await syncBoth();

    final onPcCards = await cards(pc);
    expect([for (final card in onPcCards) card.entityId], [b]);
    expect(
      [for (final card in await cards(phone)) card.conflictIds],
      [onPcCards.single.conflictIds],
    );
    for (final dev in [onPc, onPhone]) {
      final ws = await dev.read();
      expect(ws.rootProjectOf(a), work);
      expect(ws.rootProjectOf(c), work);
    }
    expect(
      (await onPc.read()).rootProjectOf(b),
      (await onPhone.read()).rootProjectOf(b),
    );
    await expectStableAndSame();
  });

  test(
    'массовая смена срока на ПК против правки срока двух задач на '
    'телефоне офлайн — по карточке на задачу, одни и те же на обоих',
    () async {
      final a = await onPc.tasks.add(content: 'А');
      final b = await onPc.tasks.add(content: 'Б');
      await syncBoth();

      await onPc.bulk.setDue([a, b], const Due(date: '2026-10-25'));
      for (final id in [a, b]) {
        await onPhone.tasks.setDue(id, const Due(date: '2026-10-30'));
      }
      await syncBoth();

      final onPcCards = await cards(pc);
      expect({for (final card in onPcCards) card.entityId}, {a, b});
      expect(onPcCards, hasLength(2));
      final ids = {for (final card in onPcCards) ...card.conflictIds};
      expect({for (final card in await cards(phone)) ...card.conflictIds}, ids);
      for (final conflict in await pc.conflicts()) {
        expect(conflict.field, TaskFields.due);
      }
      await expectStableAndSame();
    },
  );

  test('массовое выполнение на ПК, на телефоне задачу удалили офлайн — '
      'остальные выполнены на обоих, удалённая удалена', () async {
    final a = await onPc.tasks.add(content: 'А');
    final b = await onPc.tasks.add(content: 'Б');
    await syncBoth();

    await onPc.bulk.complete([a, b]);
    await onPhone.tasks.delete(b);
    await syncBoth();

    for (final dev in [onPc, onPhone]) {
      final ws = await dev.read();
      expect(ws.task(a)!.isCompleted, isTrue);
      expect(ws.task(b), isNull);
    }
    await expectStableAndSame();
  });
}
