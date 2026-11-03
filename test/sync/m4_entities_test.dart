import 'package:flutter_test/flutter_test.dart';
import 'package:oplog_sync/oplog_sync.dart';
import 'package:planner/data/projection/entity_fields.dart';
import 'package:planner/data/repositories/view_options_repository.dart';
import 'package:planner/domain/conflicts.dart';
import 'package:planner/domain/view_options.dart';
import 'package:planner/sync/conflict_repository.dart';
import 'package:planner/sync/io_sync_fs.dart';

import '../data/support/drift_probe.dart';
import '../features/support/app_commands.dart';
import 'support/devices.dart';

// Данные схемы v5 (решения 1, 3, 4, 5 плана M4) на двух устройствах тем же
// путём, что в приложении: Mutator → журнал drift → папка на диске → другая
// база. Команд для новых полей ещё нет (M4.2, M4.5, M4.9, M4.11) — правки
// пишутся через Mutator, как их будут писать команды.
void main() {
  late TestDevice pc;
  late TestDevice phone;
  late AppCommands onPc;
  late AppCommands onPhone;
  late String folder;

  setUp(() async {
    folder = tempDir('m4_entities_').path;
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
    expect(states[1]['view_options'], states[0]['view_options']);
    expect(states[1]['tasks'], states[0]['tasks']);
    expect(states[1]['projects'], states[0]['projects']);
  }

  Future<List<ConflictCard>> cards(TestDevice dev) => ConflictRepository(
    db: dev.db,
    store: dev.services.store,
    meta: dev.services.meta,
  ).load();

  /// Правка «Отображения» вида проекта [projectId] на устройстве [dev] —
  /// как её запишет команда M4.5: тип и объект вида плюс изменённые поля.
  Future<void> setView(
    TestDevice dev,
    String projectId,
    Map<String, Object?> fields,
  ) => dev.services.mutator.update(
    EntityTypes.viewOptions,
    viewOptionsId(ViewType.project.apiName, projectId),
    {
      ViewOptionsFields.viewType: ViewType.project.apiName,
      ViewOptionsFields.objectId: projectId,
      ...fields,
    },
  );

  Future<ViewOptions> viewOf(TestDevice dev, String projectId) =>
      ViewOptionsRepository(dev.db).load(ViewType.project, objectId: projectId);

  test('настройки одного вида на двух устройствах офлайн — одна сущность, '
      'разные поля сохраняются, без конфликтов', () async {
    final project = await onPc.projects.add(name: 'Работа');
    await syncBoth();

    await setView(pc, project, {ViewOptionsFields.groupedBy: 'priority'});
    await setView(phone, project, {
      ViewOptionsFields.sortedBy: 'due_date',
      ViewOptionsFields.sortOrder: 'desc',
    });
    await syncBoth();

    for (final dev in [pc, phone]) {
      expect(
        await viewOf(dev, project),
        ViewOptions(
          viewType: ViewType.project,
          objectId: project,
          grouping: Grouping.priority,
          sorting: Sorting.dueDate,
          sortOrder: SortOrder.desc,
        ),
      );
      expect(await dev.db.select(dev.db.viewOptions).get(), hasLength(1));
      expect(await dev.conflicts(), isEmpty);
      expect(await cards(dev), isEmpty);
    }
    await expectStableAndSame();
  });

  test('одно поле вида на двух устройствах офлайн — побеждает поздняя правка, '
      'карточки нет', () async {
    final project = await onPc.projects.add(name: 'Работа');
    await syncBoth();

    await setView(pc, project, {ViewOptionsFields.groupedBy: 'priority'});
    phone.advance(const Duration(seconds: 5));
    await setView(phone, project, {ViewOptionsFields.groupedBy: 'label'});
    await syncBoth();

    for (final dev in [pc, phone]) {
      expect((await viewOf(dev, project)).grouping, Grouping.label);
      expect(await cards(dev), isEmpty);
    }
    await expectStableAndSame();
  });

  test('вид, настроек которого не меняли, и значение от более новой версии — '
      'значения по умолчанию, само значение в журнале', () async {
    final project = await onPc.projects.add(name: 'Работа');
    expect(
      await viewOf(pc, project),
      ViewOptions(viewType: ViewType.project, objectId: project),
    );

    await setView(pc, project, {ViewOptionsFields.groupedBy: 'assignee'});
    await syncBoth();
    expect((await viewOf(phone, project)).grouping, Grouping.none);
    final id = viewOptionsId(ViewType.project.apiName, project);
    expect(
      (await phone.entity(
        EntityTypes.viewOptions,
        id,
      ))![ViewOptionsFields.groupedBy],
      'assignee',
    );
    await expectStableAndSame();
  });

  test('описание проекта правят на двух устройствах офлайн — конфликт с одним '
      'id на обоих; выбор на телефоне закрывает его на ПК', () async {
    final project = await onPc.projects.add(name: 'Работа');
    await syncBoth();

    await pc.services.mutator.update(EntityTypes.project, project, {
      ProjectFields.description: 'План на квартал',
    });
    await phone.services.mutator.update(EntityTypes.project, project, {
      ProjectFields.description: 'План на месяц',
    });
    await syncBoth();

    final onPcConflicts = await pc.conflicts();
    expect(onPcConflicts.single.kind, ConflictKind.edit);
    expect(onPcConflicts.single.field, ProjectFields.description);
    expect((await phone.conflicts()).map((c) => c.id), [
      onPcConflicts.single.id,
    ]);
    final card = (await cards(phone)).single;
    expect(card.newer.values.single.field, ConflictField.description);

    await phone.services.mutator.resolveConflict(onPcConflicts.single.id, {
      ProjectFields.description: 'План на квартал',
    });
    await syncBoth();
    for (final dev in [onPc, onPhone]) {
      expect(
        (await dev.read()).project(project)!.description,
        'План на квартал',
      );
    }
    expect((await pc.conflicts()).single.resolved, isTrue);
    expect(await cards(pc), isEmpty);
    await expectStableAndSame();
  });

  test('описание проекта правят по очереди с синхронизацией между правками — '
      'конфликта нет', () async {
    final project = await onPc.projects.add(name: 'Работа');
    await syncBoth();

    await pc.services.mutator.update(EntityTypes.project, project, {
      ProjectFields.description: 'черновик',
    });
    await syncBoth();
    await phone.services.mutator.update(EntityTypes.project, project, {
      ProjectFields.description: 'итог',
    });
    await syncBoth();

    for (final dev in [onPc, onPhone]) {
      expect((await dev.read()).project(project)!.description, 'итог');
    }
    expect(await pc.conflicts(), isEmpty);
    expect(await phone.conflicts(), isEmpty);
    await expectStableAndSame();
  });

  test('проект удалён на ПК, его описание изменено на телефоне — конфликт '
      '«удалено / изменено» с одним id на обоих', () async {
    final project = await onPc.projects.add(name: 'Работа');
    await syncBoth();

    await onPc.projects.delete(project);
    await phone.services.mutator.update(EntityTypes.project, project, {
      ProjectFields.description: 'новое',
    });
    await syncBoth();

    final onPcConflicts = await pc.conflicts();
    expect(onPcConflicts.single.kind, ConflictKind.delete);
    expect((await phone.conflicts()).map((c) => c.id), [
      onPcConflicts.single.id,
    ]);
    await expectStableAndSame();
  });

  test('порядок дня одной задачи меняют на двух устройствах офлайн — без '
      'карточки, одинаковое значение на обоих', () async {
    final task = await onPc.tasks.add(content: 'Отчёт');
    await syncBoth();

    await pc.services.mutator.update(EntityTypes.task, task, {
      TaskFields.dayOrderKey: 'a1',
    });
    await phone.services.mutator.update(EntityTypes.task, task, {
      TaskFields.dayOrderKey: 'a2',
    });
    await syncBoth();

    final keys = [
      for (final dev in [onPc, onPhone])
        (await dev.read()).task(task)!.dayOrderKey,
    ];
    expect(keys.toSet(), hasLength(1));
    expect(await pc.conflicts(), isEmpty);
    expect(await phone.conflicts(), isEmpty);
    await expectStableAndSame();
  });

  test('задачу с меткой завершили на двух устройствах офлайн с разными '
      'снимками имён — без карточки, одинаковый снимок на обоих', () async {
    final label = await onPc.labels.add(name: 'дом');
    final task = await onPc.tasks.add(
      content: 'Полить цветы',
      labelIds: {label},
    );
    await syncBoth();

    // Телефон завершил задачу после переименования метки, которого ПК не
    // видел: снимки расходятся.
    final names = {pc: 'дом', phone: 'дача'};
    for (final MapEntry(key: dev, value: name) in names.entries) {
      await dev.services.mutator.update(EntityTypes.task, task, {
        TaskFields.isCompleted: true,
        TaskFields.completedAt: dev.clock.nowUtc().toIso8601String(),
        TaskFields.completedLabelNames: {label: name},
      });
    }
    await syncBoth();

    final snapshots = [
      for (final dev in [onPc, onPhone])
        (await dev.read()).task(task)!.completedLabelNames,
    ];
    expect(snapshots[1], snapshots[0]);
    expect(snapshots[0].values.single, isIn(['дом', 'дача']));
    for (final dev in [pc, phone]) {
      expect(await dev.conflicts(), isEmpty);
      expect(await cards(dev), isEmpty);
    }
    await expectStableAndSame();
  });

  test('снимок имён у задачи в работе (после параллельных завершения и '
      'возврата) — не читается', () async {
    final label = await onPc.labels.add(name: 'дом');
    final task = await onPc.tasks.add(
      content: 'Полить цветы',
      labelIds: {label},
    );
    await pc.services.mutator.update(EntityTypes.task, task, {
      TaskFields.completedLabelNames: {label: 'дом'},
    });

    expect((await onPc.read()).task(task)!.completedLabelNames, isEmpty);
  });

  test('задачу с меткой завершили на двух устройствах офлайн — снимок имён '
      'одинаков, конфликтов нет', () async {
    final label = await onPc.labels.add(name: 'дом');
    final task = await onPc.tasks.add(
      content: 'Полить цветы',
      labelIds: {label},
    );
    await syncBoth();

    // Как будет писать `markCompleted` (M4.2): выполнение и снимок одним
    // действием.
    for (final dev in [pc, phone]) {
      await dev.services.mutator.update(EntityTypes.task, task, {
        TaskFields.isCompleted: true,
        TaskFields.completedAt: dev.clock.nowUtc().toIso8601String(),
        TaskFields.completedLabelNames: {label: 'дом'},
      });
    }
    await syncBoth();

    for (final dev in [onPc, onPhone]) {
      final done = (await dev.read()).task(task)!;
      expect(done.isCompleted, isTrue);
      expect(done.completedLabelNames, {label: 'дом'});
    }
    expect(await pc.conflicts(), isEmpty);
    expect(await phone.conflicts(), isEmpty);
    await expectStableAndSame();
  });

  test(
    'долгий офлайн: 30 правок на телефоне против одной на ПК, затем '
    'повторная доставка — одинаковая база, пересборка её не меняет',
    () async {
      final project = await onPc.projects.add(name: 'Работа');
      final task = await onPc.tasks.add(content: 'Отчёт', projectId: project);
      await syncBoth();

      await setView(pc, project, {ViewOptionsFields.showCompletedTasks: true});
      for (var i = 0; i < 30; i++) {
        phone.advance(const Duration(minutes: 1));
        await setView(phone, project, {
          ViewOptionsFields.sortedBy: i.isEven ? 'priority' : 'alphabetically',
        });
        await phone.services.mutator.update(EntityTypes.task, task, {
          TaskFields.dayOrderKey: 'a$i',
        });
      }
      await syncBoth();
      // Повторная доставка: курсоры сброшены, все чанки читаются заново.
      for (final dev in [pc, phone]) {
        await dev.db.delete(dev.db.syncCursors).go();
      }
      await syncBoth();

      for (final dev in [pc, phone]) {
        final view = await viewOf(dev, project);
        expect(
          (view.sorting, view.showCompletedTasks),
          (Sorting.alphabetically, true),
        );
      }
      for (final dev in [onPc, onPhone]) {
        expect((await dev.read()).task(task)!.dayOrderKey, 'a29');
      }
      expect(await pc.conflicts(), isEmpty);
      await expectStableAndSame();
    },
  );
}
