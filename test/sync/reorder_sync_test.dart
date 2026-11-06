import 'package:flutter_test/flutter_test.dart';
import 'package:planner/domain/conflicts.dart';
import 'package:planner/sync/conflict_repository.dart';
import 'package:planner/sync/io_sync_fs.dart';

import '../data/support/drift_probe.dart';
import '../features/support/app_commands.dart';
import 'support/devices.dart';

// Ручной порядок проектов, разделов и меток (часть M4.10) на двух устройствах:
// параллельная перестановка — без карточки, перенос против архива и цикл
// сходятся одинаково, пересборка из журнала ничего не меняет.
void main() {
  late TestDevice pc;
  late TestDevice phone;
  late AppCommands onPc;
  late AppCommands onPhone;
  late String folder;

  setUp(() async {
    folder = tempDir('reorder_sync_').path;
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

  Future<void> expectStableAndSame() async {
    final states = <Map<String, Object?>>[];
    for (final dev in [pc, phone]) {
      final before = await dumpSyncedState(dev.db);
      await dev.services.engine.rebuild();
      expect(await dumpSyncedState(dev.db), before, reason: dev.nodeId);
      states.add(before);
    }
    expect(states[1]['field_versions'], states[0]['field_versions']);
    expect(states[1]['projects'], states[0]['projects']);
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

  test(
    'параллельная перестановка проектов — без карточки, порядок один',
    () async {
      final ids = [
        for (final name in ['А', 'Б', 'В', 'Г'])
          await onPc.projects.add(name: name),
      ];
      await syncBoth();

      await onPc.projects.reorder(ids[3]);
      await onPhone.projects.reorder(ids[1], afterId: ids[2]);
      await syncBoth();

      await expectNoCards();
      final a = [for (final p in (await onPc.read()).childProjects(null)) p.id];
      final b = [
        for (final p in (await onPhone.read()).childProjects(null)) p.id,
      ];
      expect(a, b);
      await expectStableAndSame();
    },
  );

  test('параллельная перестановка разделов и меток — без карточки', () async {
    final project = await onPc.projects.add(name: 'Работа');
    final sections = [
      for (final name in ['А', 'Б', 'В'])
        await onPc.sections.add(project, name: name),
    ];
    final labels = [
      for (final name in ['а', 'б', 'в']) await onPc.labels.add(name: name),
    ];
    await syncBoth();

    await onPc.sections.reorder(sections[2]);
    await onPhone.sections.reorder(sections[0], afterId: sections[1]);
    await onPc.labels.reorder(labels[2]);
    await onPhone.labels.reorder(labels[0], afterId: labels[1]);
    await syncBoth();

    await expectNoCards();
    final first = await onPc.read();
    final second = await onPhone.read();
    expect(
      [for (final s in first.sectionsOf(project)) s.id],
      [for (final s in second.sectionsOf(project)) s.id],
    );
    expect(
      [for (final l in first.labels) l.id],
      [for (final l in second.labels) l.id],
    );
    await expectStableAndSame();
  });

  test('перенос проекта на ПК против архива на телефоне — без карточки, в '
      'архиве и под новым родителем на обоих', () async {
    final parent = await onPc.projects.add(name: 'Родитель');
    final child = await onPc.projects.add(name: 'Дочерний');
    await syncBoth();

    await onPc.projects.reorder(child, parentId: parent);
    await onPhone.projects.archive(child);
    await syncBoth();

    await expectNoCards();
    for (final dev in [onPc, onPhone]) {
      final ws = await dev.read();
      expect(ws.projectParent(child), parent);
      expect(ws.isProjectArchived(child), isTrue);
    }
    await expectStableAndSame();
  });

  test('цикл проектов (X под Y, Y под X) разрывается одинаково', () async {
    final x = await onPc.projects.add(name: 'X');
    final y = await onPc.projects.add(name: 'Y');
    await syncBoth();

    await onPc.projects.reorder(x, parentId: y);
    await onPhone.projects.reorder(y, parentId: x);
    await syncBoth();

    final first = await onPc.read();
    final second = await onPhone.read();
    expect(first.projectParent(x), second.projectParent(x));
    expect(first.projectParent(y), second.projectParent(y));
    expect(
      first.projectParent(x) == null || first.projectParent(y) == null,
      isTrue,
    );
    await expectStableAndSame();
  });
}
