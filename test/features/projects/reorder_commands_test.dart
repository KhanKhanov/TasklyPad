import 'package:flutter_test/flutter_test.dart';
import 'package:planner/data/projection/entity_fields.dart';
import 'package:planner/domain/rules.dart';
import 'package:planner/domain/workspace.dart';

import '../../sync/support/devices.dart';
import '../support/app_commands.dart';

// Ручной порядок проектов, разделов и меток (часть M4.10 плана M4).
void main() {
  late TestDevice device;
  late AppCommands app;

  setUp(() async {
    device = await TestDevice.start();
    app = AppCommands(device);
  });

  Matcher rejected(RejectReason reason) =>
      throwsA(isA<CommandRejected>().having((e) => e.reason, 'reason', reason));

  group('проекты', () {
    List<String> level(Workspace ws, [String? parent]) => [
      for (final p in ws.childProjects(parent))
        if (!p.isInbox) p.name,
    ];

    late List<String> ids;

    setUp(() async {
      ids = [
        for (final name in ['А', 'Б', 'В']) await app.projects.add(name: name),
      ];
    });

    test('в начало, в середину, в конец', () async {
      await app.projects.reorder(ids[2]);
      expect(level(await app.read()), ['В', 'А', 'Б']);
      await app.projects.reorder(ids[1], afterId: ids[2]);
      expect(level(await app.read()), ['В', 'Б', 'А']);
      await app.projects.reorder(ids[2], afterId: ids[0]);
      expect(level(await app.read()), ['Б', 'А', 'В']);
    });

    test('бросок на своё место — без записи', () async {
      final key = (await app.read()).project(ids[1])!.orderKey;
      await app.projects.reorder(ids[1], afterId: ids[0]);
      expect((await app.read()).project(ids[1])!.orderKey, key);
    });

    test('равные ключи соседей разводятся (О-8)', () async {
      for (final id in [ids[0], ids[1]]) {
        await device.services.mutator.update(EntityTypes.project, id, {
          ProjectFields.orderKey: 'V',
        });
      }
      final first = (await app.read())
          .childProjects(null)
          .firstWhere((p) => !p.isInbox)
          .id;
      await app.projects.reorder(ids[2], afterId: first);
      final order = [
        for (final p in (await app.read()).childProjects(null))
          if (!p.isInbox) p.id,
      ];
      expect(order[0], first);
      expect(order[1], ids[2]);
    });

    test('в подпроект и обратно', () async {
      await app.projects.reorder(ids[1], parentId: ids[0]);
      var ws = await app.read();
      expect(ws.projectParent(ids[1]), ids[0]);
      expect(level(ws, ids[0]), ['Б']);

      await app.projects.reorder(ids[1], afterId: ids[0]);
      ws = await app.read();
      expect(ws.projectParent(ids[1]), isNull);
      expect(level(ws), ['А', 'Б', 'В']);
    });

    test(
      '«Входящие», цикл, предел уровней, родитель в архиве — отказ',
      () async {
        final inbox = (await app.read()).inbox!.id;
        await expectLater(
          app.projects.reorder(inbox),
          rejected(RejectReason.inboxProtected),
        );
        await expectLater(
          app.projects.reorder(ids[0], parentId: inbox),
          rejected(RejectReason.inboxProtected),
        );

        await app.projects.reorder(ids[1], parentId: ids[0]);
        await app.projects.reorder(ids[2], parentId: ids[1]);
        await expectLater(
          app.projects.reorder(ids[0], parentId: ids[2]),
          rejected(RejectReason.cycle),
        );
        final fourth = await app.projects.add(name: 'Г');
        await expectLater(
          app.projects.reorder(fourth, parentId: ids[2]),
          rejected(RejectReason.tooDeep),
        );

        final archived = await app.projects.add(name: 'Архив');
        await app.projects.archive(archived);
        await expectLater(
          app.projects.reorder(fourth, parentId: archived),
          rejected(RejectReason.notFound),
        );
      },
    );
  });

  group('разделы', () {
    late String project;
    late List<String> ids;

    setUp(() async {
      project = await app.projects.add(name: 'Работа');
      ids = [
        for (final name in ['А', 'Б', 'В'])
          await app.sections.add(project, name: name),
      ];
    });

    List<String> order(Workspace ws) => [
      for (final s in ws.sectionsOf(project)) s.name,
    ];

    test('в начало и после соседа; задачи остаются в разделе', () async {
      final task = await app.tasks.add(
        content: 'Задача',
        projectId: project,
        sectionId: ids[2],
      );
      await app.sections.reorder(ids[2]);
      expect(order(await app.read()), ['В', 'А', 'Б']);
      await app.sections.reorder(ids[0], afterId: ids[1]);
      final ws = await app.read();
      expect(order(ws), ['В', 'Б', 'А']);
      expect(ws.rootSectionOf(task)?.id, ids[2]);
    });

    test(
      'бросок на своё место — без записи; архивный раздел — отказ',
      () async {
        final key = (await app.read()).section(ids[1])!.orderKey;
        await app.sections.reorder(ids[1], afterId: ids[0]);
        expect((await app.read()).section(ids[1])!.orderKey, key);

        await app.sections.archive(ids[1]);
        await expectLater(
          app.sections.reorder(ids[1]),
          rejected(RejectReason.notFound),
        );
      },
    );

    test('равные ключи соседей разводятся (О-8)', () async {
      for (final id in [ids[0], ids[1]]) {
        await device.services.mutator.update(EntityTypes.section, id, {
          SectionFields.orderKey: 'V',
        });
      }
      final first = (await app.read()).sectionsOf(project).first.id;
      await app.sections.reorder(ids[2], afterId: first);
      final now = (await app.read()).sectionsOf(project);
      expect(now[0].id, first);
      expect(now[1].id, ids[2]);
    });
  });

  group('метки', () {
    test('в начало и после соседа; своё место — без записи', () async {
      final ids = [
        for (final name in ['а', 'б', 'в']) await app.labels.add(name: name),
      ];
      List<String> order(Workspace ws) => [for (final l in ws.labels) l.name];

      await app.labels.reorder(ids[2]);
      expect(order(await app.read()), ['в', 'а', 'б']);
      await app.labels.reorder(ids[0], afterId: ids[1]);
      expect(order(await app.read()), ['в', 'б', 'а']);

      final key = (await app.read()).label(ids[1])!.orderKey;
      await app.labels.reorder(ids[1], afterId: ids[2]);
      expect((await app.read()).label(ids[1])!.orderKey, key);
    });
  });
}
