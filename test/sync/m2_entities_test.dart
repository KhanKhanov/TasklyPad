import 'package:flutter_test/flutter_test.dart';
import 'package:oplog_sync/oplog_sync.dart';
import 'package:planner/data/projection/entity_fields.dart';
import 'package:planner/domain/workspace.dart';
import 'package:planner/sync/io_sync_fs.dart';

import '../features/support/app_commands.dart';
import 'support/devices.dart';

// Сущности M2 (разделы, метки, связи задача–метка, каскад, деревья) на двух
// устройствах тем же путём, что в приложении: действия → Mutator → журнал
// drift → папка на диске → другая база → снимок Workspace.
void main() {
  late TestDevice pc;
  late TestDevice phone;
  late AppCommands onPc;
  late AppCommands onPhone;
  late String folder;

  setUp(() async {
    folder = tempDir('m2_entities_').path;
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

  /// Одинаковая видимая картина на обоих устройствах.
  Future<void> expectSame(String projectId) async {
    final (a, b) = (await onPc.read(), await onPhone.read());
    List<(String, int)> view(Workspace ws) => [
      for (final item
          in ws.projectView(projectId, showCompleted: true).unsectioned)
        (item.value.id, item.depth),
    ];
    expect(view(b), view(a));
  }

  test('одна метка, поставленная задаче на двух устройствах офлайн, — одна '
      'связь и без конфликта', () async {
    final label = await onPc.labels.add(name: 'дом');
    final task = await onPc.tasks.add(content: 'Купить молоко');
    await syncBoth();

    await onPc.tasks.setLabels(task, {label});
    await onPhone.tasks.setLabels(task, {label});
    await syncBoth();

    for (final dev in [onPc, onPhone]) {
      expect((await dev.read()).task(task)!.labelIds, [label]);
    }
    expect(await pc.db.select(pc.db.taskLabels).get(), hasLength(1));
    expect(await pc.conflicts(), isEmpty);
    expect(await phone.conflicts(), isEmpty);
  });

  test('метка снята на одном, поставлена другая на другом — обе правки '
      'сохраняются', () async {
    final x = await onPc.labels.add(name: 'x');
    final y = await onPc.labels.add(name: 'y');
    final task = await onPc.tasks.add(content: 't', labelIds: {x});
    await syncBoth();

    await onPc.tasks.setLabels(task, {});
    await onPhone.tasks.setLabels(task, {x, y});
    await syncBoth();

    for (final dev in [onPc, onPhone]) {
      expect((await dev.read()).task(task)!.labelIds, [y]);
    }
  });

  test('проект удалён на ПК, в него добавлена задача на телефоне — задача '
      'скрыта на обоих; отмена удаления возвращает её везде', () async {
    final project = await onPc.projects.add(name: 'Ремонт');
    await syncBoth();

    await onPc.projects.delete(project);
    final task = await onPhone.tasks.add(content: 'Обои', projectId: project);
    await syncBoth();

    for (final dev in [onPc, onPhone]) {
      expect((await dev.read()).task(task), isNull);
    }
    // Удаление против новой задачи — не конфликт: правились разные сущности.
    expect(await pc.conflicts(), isEmpty);

    await pc.services.mutator.restore(EntityTypes.project, project);
    await syncBoth();
    for (final dev in [onPc, onPhone]) {
      expect((await dev.read()).task(task)?.content, 'Обои');
    }
  });

  test('проект удалён на ПК и переименован на телефоне — конфликт удаления с '
      'одним id на обоих', () async {
    final project = await onPc.projects.add(name: 'Ремонт');
    await syncBoth();

    await onPc.projects.delete(project);
    await onPhone.projects.rename(project, 'Ремонт кухни');
    await syncBoth();

    final pcConflicts = await pc.conflicts();
    expect(pcConflicts.single.kind, ConflictKind.delete);
    expect((await phone.conflicts()).map((c) => c.id), [pcConflicts.single.id]);
  });

  test('параллельные переносы задач друг под друга — одинаковое дерево на '
      'обоих, обе задачи видны', () async {
    final a = await onPc.tasks.add(content: 'a');
    final b = await onPc.tasks.add(content: 'b');
    await syncBoth();

    await onPc.tasks.move(a, parentId: b);
    await onPhone.tasks.move(b, parentId: a);
    await syncBoth();

    await expectSame(inboxProjectId);
    final ws = await onPc.read();
    expect(ws.task(a), isNotNull);
    expect(ws.task(b), isNotNull);
  });

  test('параллельное переименование раздела — конфликт с одним id; выбор на '
      'телефоне закрывает его на ПК', () async {
    final project = await onPc.projects.add(name: 'Работа');
    final section = await onPc.sections.add(project, name: 'Неделя');
    await syncBoth();

    await onPc.sections.rename(section, 'Эта неделя');
    await onPhone.sections.rename(section, 'Спринт');
    await syncBoth();

    final conflict = (await phone.conflicts()).single;
    expect((await pc.conflicts()).single.id, conflict.id);

    await phone.services.mutator.resolveConflict(conflict.id, {
      SectionFields.name: 'Спринт',
    });
    await syncBoth();
    for (final dev in [pc, phone]) {
      expect((await dev.conflicts()).single.resolved, isTrue);
    }
    for (final dev in [onPc, onPhone]) {
      expect((await dev.read()).section(section)!.name, 'Спринт');
    }
  });

  test(
    'свёрнутость и порядок, изменённые на обоих, — без конфликтов',
    () async {
      final a = await onPc.tasks.add(content: 'a');
      await onPc.tasks.add(content: 'b');
      await onPc.tasks.add(content: 'a1', parentId: a);
      await syncBoth();

      await onPc.tasks.setCollapsed(a, true);
      await onPhone.tasks.setCollapsed(a, false);
      await onPc.tasks.moveDown(a);
      await onPhone.tasks.moveDown(a);
      await syncBoth();

      expect(await pc.conflicts(), isEmpty);
      expect(await phone.conflicts(), isEmpty);
      await expectSame(inboxProjectId);
    },
  );

  test('завершение родителя на ПК и новая подзадача на телефоне — данные '
      'сходятся', () async {
    final parent = await onPc.tasks.add(content: 'Родитель');
    await syncBoth();

    await onPc.tasks.complete(parent);
    final child = await onPhone.tasks.add(content: 'Новая', parentId: parent);
    await syncBoth();

    await expectSame(inboxProjectId);
    final ws = await onPc.read();
    expect(ws.task(parent)!.isCompleted, isTrue);
    expect(ws.task(child)!.isCompleted, isFalse);
  });

  test('раздел перенесён в другой проект на ПК, в него добавлена задача на '
      'телефоне — новая задача видна в разделе на обоих', () async {
    final from = await onPc.projects.add(name: 'Откуда');
    final to = await onPc.projects.add(name: 'Куда');
    final section = await onPc.sections.add(from, name: 'Неделя');
    await syncBoth();

    await onPc.sections.moveToProject(section, to);
    final task = await onPhone.tasks.add(
      content: 'Новая',
      projectId: from,
      sectionId: section,
    );
    await syncBoth();

    for (final dev in [onPc, onPhone]) {
      final ws = await dev.read();
      expect(ws.task(task), isNotNull);
      expect(ws.section(section)!.projectId, to);
      expect(
        [for (final i in ws.projectView(to).sections.single.tasks) i.value.id],
        [task],
      );
      expect(ws.activeTaskCount(from), 0);
    }
  });

  test(
    'долгий офлайн телефона и повторная доставка — снимки совпадают',
    () async {
      final project = await onPc.projects.add(name: 'Работа');
      await syncBoth();

      // Телефон месяц без синхронизации, ПК работает каждый день. Время идёт
      // на обоих: op «из будущего» больше чем на час отклоняется.
      for (var day = 0; day < 30; day++) {
        pc.advance(const Duration(days: 1));
        phone.advance(const Duration(days: 1));
        await onPc.tasks.add(content: 'день $day', projectId: project);
      }
      await onPhone.tasks.add(content: 'с телефона', projectId: project);
      await syncBoth();
      await syncBoth();

      await expectSame(project);
      expect((await onPhone.read()).activeTaskCount(project), 31);
    },
  );

  test('перестановка задачи на ПК и перенос её подзадачи на телефоне — без '
      'конфликтов, перенос сохранён', () async {
    final p1 = await onPc.projects.add(name: 'Работа');
    final p2 = await onPc.projects.add(name: 'Дом');
    await onPc.tasks.add(content: 'первая', projectId: p1);
    final parent = await onPc.tasks.add(content: 'Родитель', projectId: p1);
    final child = await onPc.tasks.add(content: 'Ребёнок', parentId: parent);
    await syncBoth();

    await onPc.tasks.move(parent, projectId: p1, atTop: true);
    await onPhone.tasks.move(child, projectId: p2);
    await syncBoth();

    expect(await pc.conflicts(), isEmpty);
    expect(await phone.conflicts(), isEmpty);
    for (final dev in [onPc, onPhone]) {
      final ws = await dev.read();
      expect(ws.taskParent(child), isNull);
      expect(ws.rootProjectOf(child), p2);
      expect(ws.children(null, projectId: p1).first.id, parent);
    }
  });

  test('подзадача удалена на ПК, родитель перенесён на телефоне — конфликтов '
      'удаления нет', () async {
    final project = await onPc.projects.add(name: 'Работа');
    final parent = await onPc.tasks.add(content: 'Родитель');
    final child = await onPc.tasks.add(content: 'Ребёнок', parentId: parent);
    await syncBoth();

    await onPc.tasks.delete(child);
    await onPhone.tasks.move(parent, projectId: project);
    await syncBoth();

    expect(await pc.conflicts(), isEmpty);
    expect(await phone.conflicts(), isEmpty);
    for (final dev in [onPc, onPhone]) {
      expect((await dev.read()).task(child), isNull);
    }
  });
}
