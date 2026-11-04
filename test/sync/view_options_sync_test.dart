import 'package:flutter_test/flutter_test.dart';
import 'package:planner/domain/view_options.dart';
import 'package:planner/sync/conflict_repository.dart';
import 'package:planner/sync/io_sync_fs.dart';

import '../data/support/drift_probe.dart';
import '../features/support/app_commands.dart';
import 'support/devices.dart';

// «Отображение» вида на двух устройствах (О-22, план M4.5): команды пишут
// поля `view_options` через Mutator, папка на диске переносит их на другое
// устройство; тип молчащий — спор полей решает LWW без карточки.
void main() {
  late TestDevice pc;
  late TestDevice phone;
  late AppCommands onPc;
  late AppCommands onPhone;
  late String folder;

  setUp(() async {
    folder = tempDir('view_options_sync_').path;
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
    expect(states[1]['view_options'], states[0]['view_options']);
    expect(states[1]['field_versions'], states[0]['field_versions']);
  }

  Future<void> expectNoCards() async {
    for (final dev in [pc, phone]) {
      final cards = await ConflictRepository(
        db: dev.db,
        store: dev.services.store,
        meta: dev.services.meta,
      ).load();
      expect(cards, isEmpty, reason: dev.nodeId);
    }
  }

  test('«Выполненные задачи», группировку и сортировку включили на ПК — '
      'телефон видит их после синхронизации и пересборки', () async {
    final project = await onPc.projects.add(name: 'Работа');
    await syncBoth();

    final view = ViewOptions(viewType: ViewType.project, objectId: project);
    final changed = view.copyWith(
      showCompletedTasks: true,
      grouping: Grouping.priority,
      sorting: Sorting.alphabetically,
      sortOrder: SortOrder.desc,
    );
    await onPc.views.save(view, changed);
    await syncBoth();

    expect(
      await onPhone.viewsRepo.load(ViewType.project, objectId: project),
      changed,
    );
    await expectNoCards();
    await expectStableAndSame();
  });

  test('«Сбросить всё» на ПК против правки на телефоне офлайн — поля '
      'сходятся по полю: сброшенное ПК, изменённое телефоном', () async {
    final project = await onPc.projects.add(name: 'Работа');
    final view = ViewOptions(viewType: ViewType.project, objectId: project);
    final sorted = view.copyWith(
      grouping: Grouping.priority,
      sorting: Sorting.dueDate,
      sortOrder: SortOrder.desc,
    );
    await onPc.views.save(view, sorted);
    await syncBoth();

    await onPc.views.resetAll(sorted);
    phone.advance(const Duration(seconds: 5));
    await onPhone.views.save(
      sorted,
      sorted.copyWith(sorting: Sorting.priority, showCompletedTasks: true),
    );
    await syncBoth();

    final expected = view.copyWith(
      // Группировку и направление менял только ПК.
      grouping: Grouping.none,
      sortOrder: SortOrder.asc,
      // Сортировку — оба, телефон позже; «Выполненные» — только телефон.
      sorting: Sorting.priority,
      showCompletedTasks: true,
    );
    for (final dev in [onPc, onPhone]) {
      expect(
        await dev.viewsRepo.load(ViewType.project, objectId: project),
        expected,
      );
    }
    await expectNoCards();
    await expectStableAndSame();
  });

  test('первая правка вида «Входящих» на обоих устройствах офлайн — одна '
      'сущность с общим id, поля обеих правок', () async {
    final inbox = (await onPc.read()).inbox!.id;
    await syncBoth();
    final view = ViewOptions(viewType: ViewType.project, objectId: inbox);

    await onPc.views.save(view, view.copyWith(grouping: Grouping.label));
    await onPhone.views.save(view, view.copyWith(showCompletedTasks: true));
    await syncBoth();

    for (final dev in [pc, phone]) {
      expect(await dev.db.select(dev.db.viewOptions).get(), hasLength(1));
    }
    expect(
      await onPhone.viewsRepo.load(ViewType.project, objectId: inbox),
      view.copyWith(grouping: Grouping.label, showCompletedTasks: true),
    );
    await expectNoCards();
    await expectStableAndSame();
  });

  test('дубликат проекта на ПК — копия с «Отображением» источника на '
      'телефоне', () async {
    final project = await onPc.projects.add(name: 'Работа');
    final view = ViewOptions(viewType: ViewType.project, objectId: project);
    await onPc.views.save(
      view,
      view.copyWith(sorting: Sorting.priority, showCompletedTasks: true),
    );
    final copy = await onPc.projects.duplicate(project, name: 'Работа (копия)');
    await syncBoth();

    expect(
      await onPhone.viewsRepo.load(ViewType.project, objectId: copy),
      ViewOptions(
        viewType: ViewType.project,
        objectId: copy,
        sorting: Sorting.priority,
        showCompletedTasks: true,
      ),
    );
    await expectStableAndSame();
  });
}
