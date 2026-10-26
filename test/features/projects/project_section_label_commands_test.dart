import 'package:flutter_test/flutter_test.dart';
import 'package:planner/data/projection/entity_fields.dart';
import 'package:planner/domain/rules.dart';

import '../../sync/support/devices.dart';
import '../support/app_commands.dart';

Matcher _rejected(RejectReason reason) =>
    throwsA(isA<CommandRejected>().having((e) => e.reason, 'reason', reason));

void main() {
  late TestDevice device;
  late AppCommands app;

  setUp(() async {
    device = await TestDevice.start();
    app = AppCommands(device);
  });

  group('проекты', () {
    test('«Входящие» нельзя удалить, архивировать, переименовать, вложить и '
        'сделать родителем; вид менять можно', () async {
      const inbox = inboxProjectId;
      final p = await app.projects.add(name: 'Работа');
      expect(
        app.projects.delete(inbox),
        _rejected(RejectReason.inboxProtected),
      );
      expect(
        app.projects.archive(inbox),
        _rejected(RejectReason.inboxProtected),
      );
      expect(
        app.projects.rename(inbox, 'Мои'),
        _rejected(RejectReason.inboxProtected),
      );
      expect(
        app.projects.move(inbox, parentId: p),
        _rejected(RejectReason.inboxProtected),
      );
      expect(
        app.projects.add(name: 'Под', parentId: inbox),
        _rejected(RejectReason.inboxProtected),
      );
      await app.projects.setViewStyle(inbox, 'board');
      expect((await app.read()).inbox!.viewStyle, 'board');
    });

    test(
      'подпроекты — до 3 уровней; перенос в своего потомка запрещён',
      () async {
        final p1 = await app.projects.add(name: '1');
        final p2 = await app.projects.add(name: '2', parentId: p1);
        final p3 = await app.projects.add(name: '3', parentId: p2);
        expect(
          app.projects.add(name: '4', parentId: p3),
          _rejected(RejectReason.tooDeep),
        );
        expect(
          app.projects.move(p1, parentId: p3),
          _rejected(RejectReason.cycle),
        );
        final other = await app.projects.add(name: 'другой');
        expect(app.projects.move(p2, parentId: other), completes);
        final other2 = await app.projects.add(
          name: 'другой 2',
          parentId: other,
        );
        // p2 с подпроектом p3 под other2 — это 4 уровня.
        expect(
          app.projects.move(p2, parentId: other2),
          _rejected(RejectReason.tooDeep),
        );
      },
    );

    test('удаление скрывает подпроекты, разделы и задачи', () async {
      final p = await app.projects.add(name: 'Работа');
      final sub = await app.projects.add(name: 'Под', parentId: p);
      final section = await app.sections.add(p, name: 'Неделя');
      final task = await app.tasks.add(content: 't', projectId: sub);
      await app.projects.delete(p);
      final ws = await app.read();
      expect(ws.project(sub), isNull);
      expect(ws.section(section), isNull);
      expect(ws.task(task), isNull);
    });

    test('архив и возврат — проект с подпроектами уходит из дерева и '
        'возвращается', () async {
      final p = await app.projects.add(name: 'Работа');
      await app.projects.add(name: 'Под', parentId: p);
      await app.projects.archive(p);
      var ws = await app.read();
      expect(ws.projectTree(), isEmpty);
      expect([for (final a in ws.archivedProjects) a.id], [p]);
      await app.projects.unarchive(p);
      ws = await app.read();
      expect(ws.projectTree().length, 2);
    });

    test('возврат подпроекта при архивном родителе — один, корневым, в конце '
        '(project_unarchive в Todoist API)', () async {
      final parent = await app.projects.add(name: 'Работа');
      final sub = await app.projects.add(name: 'Под', parentId: parent);
      final other = await app.projects.add(name: 'Дом');
      await app.projects.archive(parent);

      final subsub = await app.projects.add(name: 'Подпод', parentId: sub);
      await app.projects.unarchive(sub);
      final ws = await app.read();
      expect(ws.project(sub)!.parentId, isNull);
      expect(
        [for (final i in ws.projectTree()) i.value.id],
        [other, sub, subsub],
      );
      expect(ws.isProjectArchived(parent), isTrue);
    });

    test('возврат проекта, который не в архиве, — ни одной op', () async {
      final p = await app.projects.add(name: 'Работа');
      final opsBefore = (await device.ownOps()).length;
      await app.projects.unarchive(p);
      expect((await device.ownOps()).length, opsBefore);
    });

    test('дубликат — после оригинала, без избранного, с активными разделами '
        'и незавершёнными задачами', () async {
      final p = await app.projects.add(name: 'Работа', isFavorite: true);
      final next = await app.projects.add(name: 'Дом');
      final section = await app.sections.add(p, name: 'Неделя');
      final archived = await app.sections.add(p, name: 'Старое');
      await app.sections.archive(archived);
      await app.tasks.add(content: 'без раздела', projectId: p);
      await app.tasks.add(
        content: 'в разделе',
        projectId: p,
        sectionId: section,
      );
      final done = await app.tasks.add(content: 'готово', projectId: p);
      await app.tasks.complete(done);

      final copy = await app.projects.duplicate(p, name: 'Копия Работа');
      final ws = await app.read();
      expect([for (final i in ws.projectTree()) i.value.id], [p, copy, next]);
      expect(ws.project(copy)!.isFavorite, isFalse);
      final view = ws.projectView(copy, showCompleted: true);
      expect(
        [for (final i in view.unsectioned) i.value.content],
        ['без раздела'],
      );
      expect([for (final s in view.sections) s.section.name], ['Неделя']);
      expect(
        [for (final i in view.sections.single.tasks) i.value.content],
        ['в разделе'],
      );
    });
  });

  group('разделы', () {
    test(
      'архив раздела завершает его незавершённые задачи с подзадачами; после '
      'возврата раздела они остаются завершёнными',
      () async {
        final p = await app.projects.add(name: 'Работа');
        final s = await app.sections.add(p, name: 'Неделя');
        final t = await app.tasks.add(content: 't', projectId: p, sectionId: s);
        final sub = await app.tasks.add(content: 'под', parentId: t);
        await app.sections.archive(s);
        var ws = await app.read();
        expect(
          (ws.task(t)!.isCompleted, ws.task(sub)!.isCompleted),
          (true, true),
        );
        expect(ws.task(t)!.completedAt, isNotNull);

        await app.sections.unarchive(s);
        ws = await app.read();
        expect(ws.sectionsOf(p).single.id, s);
        expect(ws.task(t)!.isCompleted, isTrue);
        expect(ws.projectView(p).sections.single.tasks, isEmpty);
      },
    );

    test('не больше 20 в проекте, архивные считаются', () async {
      final p = await app.projects.add(name: 'Работа');
      for (var i = 0; i < 19; i++) {
        await app.sections.add(p, name: '$i');
      }
      final last = await app.sections.add(p, name: '19');
      await app.sections.archive(last);
      expect(
        app.sections.add(p, name: 'лишний'),
        _rejected(RejectReason.tooManySections),
      );
    });

    test('перенос в другой проект — вместе с задачами и подзадачами; отмена '
        'возвращает', () async {
      final from = await app.projects.add(name: 'Откуда');
      final to = await app.projects.add(name: 'Куда');
      final section = await app.sections.add(from, name: 'Неделя');
      final parent = await app.tasks.add(
        content: 'Родитель',
        projectId: from,
        sectionId: section,
      );
      final child = await app.tasks.add(content: 'Ребёнок', parentId: parent);

      final undo = await app.sections.moveToProject(section, to);
      var ws = await app.read();
      expect(ws.sectionsOf(to).single.id, section);
      expect(ws.rootProjectOf(child), to);
      expect(ws.projectView(to).sections.single.tasks.length, 2);

      await undo();
      ws = await app.read();
      expect(ws.sectionsOf(from).single.id, section);
      expect(ws.rootProjectOf(parent), from);
    });

    test(
      'удаление раздела скрывает его задачи, архив — убирает из списка',
      () async {
        final p = await app.projects.add(name: 'Работа');
        final s1 = await app.sections.add(p, name: 'А');
        final s2 = await app.sections.add(p, name: 'Б');
        final t1 = await app.tasks.add(
          content: '1',
          projectId: p,
          sectionId: s1,
        );
        final t2 = await app.tasks.add(
          content: '2',
          projectId: p,
          sectionId: s2,
        );
        await app.sections.delete(s1);
        await app.sections.archive(s2);
        final ws = await app.read();
        expect(ws.task(t1), isNull);
        expect(ws.task(t2), isNotNull);
        expect(ws.projectView(p).sections, isEmpty);
        expect(ws.activeTaskCount(p), 0);
      },
    );
  });

  group('метки', () {
    test('имя уникально без учёта регистра, пустое запрещено', () async {
      final home = await app.labels.add(name: 'Дом');
      expect(
        app.labels.add(name: 'дом'),
        _rejected(RejectReason.duplicateName),
      );
      expect(app.labels.add(name: ' '), _rejected(RejectReason.emptyName));
      await app.labels.rename(home, 'ДОМ');
      final work = await app.labels.add(name: 'работа');
      expect(
        app.labels.rename(work, 'дом'),
        _rejected(RejectReason.duplicateName),
      );
    });

    test('удалённая метка пропадает с задач', () async {
      final label = await app.labels.add(name: 'дом');
      final task = await app.tasks.add(content: 't', labelIds: {label});
      await app.labels.delete(label);
      final ws = await app.read();
      expect(ws.labels, isEmpty);
      expect(ws.task(task)!.labelIds, isEmpty);
    });

    test('edit — пишутся только переданные поля, название и цвет одной правкой '
        'Mutator.update; дубль имени — отказ без записи', () async {
      final home = await app.labels.add(name: 'дом');
      await app.labels.add(name: 'работа');
      final before = (await device.ownOps()).length;

      await app.labels.edit(home, name: 'дача', color: 'green');
      final ops = (await device.ownOps()).skip(before).toList();
      expect(ops.map((o) => o.field).toSet(), {
        LabelFields.name,
        LabelFields.color,
      });

      await app.labels.edit(home, color: 'blue');
      final colorOnly = (await device.ownOps()).skip(before + ops.length);
      expect(colorOnly.map((o) => o.field), [LabelFields.color]);

      final count = (await device.ownOps()).length;
      expect(
        app.labels.edit(home, name: 'Работа', color: 'red'),
        _rejected(RejectReason.duplicateName),
      );
      await pumpEventQueue();
      expect((await device.ownOps()).length, count);
      final label = (await app.read()).label(home)!;
      expect((label.name, label.color), ('дача', 'blue'));
    });
  });
}
