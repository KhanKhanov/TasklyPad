import 'package:flutter_test/flutter_test.dart';
import 'package:planner/data/projection/entity_fields.dart';
import 'package:planner/domain/conflicts.dart';
import 'package:planner/sync/conflict_repository.dart';
import 'package:planner/sync/io_sync_fs.dart';

import '../data/support/drift_probe.dart';
import '../features/support/app_commands.dart';
import 'support/devices.dart';

// Цикл родителей после правок двух устройств офлайн (A под B, B под A)
// разорван при чтении: корень цикла виден корневым, но записан под другим
// (находка ревью M4.13). Перенос корня на верхний уровень пишет `parent_id`,
// даже если видимое место то же, — иначе цикл вернётся, когда второй уйдёт
// из-под первого.
void main() {
  late TestDevice pc;
  late TestDevice phone;
  late AppCommands onPc;
  late AppCommands onPhone;
  late String folder;

  setUp(() async {
    folder = tempDir('stale_parent_').path;
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

  /// Повторная доставка тех же ops и пересборка из журнала ничего не меняют,
  /// базы устройств совпадают.
  Future<void> expectStableAndSame() async {
    final again = <Map<String, Object?>>[];
    for (final dev in [pc, phone]) {
      final before = await dumpSyncedState(dev.db);
      await dev.folder(IoSyncFs(folder)).syncOnce();
      expect(await dumpSyncedState(dev.db), before, reason: dev.nodeId);
      await dev.services.engine.rebuild();
      expect(await dumpSyncedState(dev.db), before, reason: dev.nodeId);
      again.add(before);
    }
    expect(again[1]['field_versions'], again[0]['field_versions']);
    expect(again[1]['projects'], again[0]['projects']);
    expect(again[1]['tasks'], again[0]['tasks']);
  }

  Future<List<ConflictCard>> cards(TestDevice dev) => ConflictRepository(
    db: dev.db,
    store: dev.services.store,
    meta: dev.services.meta,
  ).load();

  /// Корень разорванного цикла — меньший id (resolveParents), второй — под ним.
  (String, String) rootAndOther(String a, String b) =>
      a.compareTo(b) < 0 ? (a, b) : (b, a);

  test('проекты: корень цикла на верхний уровень на том же месте — '
      'parent_id пишется, второй проект позже выносят — оба на верхнем '
      'уровне на обоих устройствах', () async {
    final x = await onPc.projects.add(name: 'X');
    final y = await onPc.projects.add(name: 'Y');
    await syncBoth();
    await onPc.projects.reorder(x, parentId: y);
    await onPhone.projects.reorder(y, parentId: x);
    await syncBoth();
    final (root, other) = rootAndOther(x, y);
    var ws = await onPc.read();
    expect(ws.projectParent(root), isNull);
    expect(ws.project(root)!.parentId, other);

    await onPc.projects.reorder(root);
    await syncBoth();
    for (final dev in [pc, phone]) {
      expect(
        (await dev.entity(EntityTypes.project, root))![ProjectFields.parentId],
        isNull,
      );
    }

    await onPhone.projects.reorder(other);
    await syncBoth();
    for (final app in [onPc, onPhone]) {
      ws = await app.read();
      expect(ws.projectParent(root), isNull);
      expect(ws.projectParent(other), isNull);
    }
    expect(await cards(pc), isEmpty);
    expect(await cards(phone), isEmpty);
    await expectStableAndSame();
  });

  test('задачи: корень цикла на верхний уровень на том же месте — '
      'parent_id исправлен, а отмены нет — на экране ничего не изменилось, '
      'тоста нет', () async {
    final a = await onPc.tasks.add(content: 'A');
    final b = await onPc.tasks.add(content: 'B');
    await syncBoth();
    await onPc.tasks.move(a, parentId: b);
    await onPhone.tasks.move(b, parentId: a);
    await syncBoth();
    final (root, other) = rootAndOther(a, b);
    expect((await onPc.read()).taskParent(root), isNull);

    final undo = await onPc.tasks.move(root, projectId: inboxProjectId);
    expect(undo.isEmpty, isTrue);
    expect((await pc.taskRow(root))!.parentId, isNull);
    await syncBoth();
    await onPhone.tasks.move(other, projectId: inboxProjectId);
    await syncBoth();
    for (final app in [onPc, onPhone]) {
      final ws = await app.read();
      expect(ws.taskParent(root), isNull);
      expect(ws.taskParent(other), isNull);
    }
    expect(await cards(pc), isEmpty);
    expect(await cards(phone), isEmpty);
    await expectStableAndSame();
  });

  test('задачи: корень цикла перетащили на другое место верхнего уровня — '
      'parent_id пишется вместе с порядком, проект и раздел — нет', () async {
    final a = await onPc.tasks.add(content: 'A');
    final b = await onPc.tasks.add(content: 'B');
    final c = await onPc.tasks.add(content: 'C');
    await syncBoth();
    await onPc.tasks.move(a, parentId: b);
    await onPhone.tasks.move(b, parentId: a);
    await syncBoth();
    final (root, other) = rootAndOther(a, b);

    final before = (await pc.ownOps()).length;
    await onPc.tasks.move(root, projectId: inboxProjectId, afterId: c);
    final written = {
      for (final op in (await pc.ownOps()).skip(before))
        if (op.entityId == root) op.field,
    };
    expect(written, {TaskFields.parentId, TaskFields.orderKey});
    await syncBoth();

    await onPhone.tasks.move(other, projectId: inboxProjectId, atTop: true);
    await syncBoth();
    for (final app in [onPc, onPhone]) {
      final ws = await app.read();
      expect(
        [for (final t in ws.children(null, projectId: inboxProjectId)) t.id],
        [other, c, root],
      );
    }
    await expectStableAndSame();
  });
}
