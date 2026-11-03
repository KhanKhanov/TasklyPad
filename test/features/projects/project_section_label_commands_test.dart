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

    test('удаление — метка пропадает со списка и активных задач, на '
        'выполненных остаётся; одна op', () async {
      final label = await app.labels.add(name: 'дом');
      final open = await app.tasks.add(content: 'open', labelIds: {label});
      final done = await app.tasks.add(content: 'done', labelIds: {label});
      await app.tasks.complete(done);
      final before = (await device.ownOps()).length;
      await app.labels.delete(label);
      expect((await device.ownOps()).length, before + 1);
      final ws = await app.read();
      expect(ws.labels, isEmpty);
      expect(ws.task(open)!.labelIds, isEmpty);
      expect(ws.task(done)!.labelIds, [label]);
      expect(ws.taskLabel(ws.task(done)!, label)?.name, 'дом');
    });

    test('возврат в работу задачи с удалённой меткой — метка создаётся '
        'заново: то же имя, цвет и избранное по умолчанию, в конце '
        'списка', () async {
      final label = await app.labels.add(
        name: 'дом',
        color: 'red',
        isFavorite: true,
      );
      final other = await app.labels.add(name: 'работа');
      final open = await app.tasks.add(content: 'open', labelIds: {label});
      final done = await app.tasks.add(content: 'done', labelIds: {label});
      await app.tasks.complete(done);
      await app.labels.delete(label);

      await app.tasks.uncomplete(done);
      final ws = await app.read();
      expect([for (final l in ws.labels) l.name], ['работа', 'дом']);
      final revived = ws.labels.last;
      expect(revived.id, isNot(label));
      expect(revived.id, isNot(other));
      expect(revived.color, 'charcoal');
      expect(revived.isFavorite, isFalse);
      expect(ws.task(done)!.labelIds, [revived.id]);
      expect(
        ws.task(open)!.labelIds,
        isEmpty,
        reason:
            'метка не вернулась '
            'на задачи, с которых её сняло удаление',
      );

      // Снова завершённая задача несёт только новую метку.
      await app.tasks.complete(done);
      expect((await app.read()).task(done)!.labelIds, [revived.id]);
    });

    test('возврат в работу — живая метка с тем же именем (без учёта '
        'регистра) уже есть: задача получает её, новой нет', () async {
      final label = await app.labels.add(name: 'дом');
      final done = await app.tasks.add(content: 'done', labelIds: {label});
      await app.tasks.complete(done);
      await app.labels.delete(label);
      final same = await app.labels.add(name: 'Дом');

      await app.tasks.uncomplete(done);
      final ws = await app.read();
      expect([for (final l in ws.labels) l.id], [same]);
      expect(ws.task(done)!.labelIds, [same]);
    });

    test('возврат подзадачи возвращает и родителя: одна удалённая метка у '
        'обоих — одна новая метка на обоих', () async {
      final label = await app.labels.add(name: 'дом');
      final parent = await app.tasks.add(content: 'p', labelIds: {label});
      final child = await app.tasks.add(
        content: 'c',
        parentId: parent,
        labelIds: {label},
      );
      await app.tasks.complete(parent);
      await app.labels.delete(label);

      await app.tasks.uncomplete(child);
      final ws = await app.read();
      expect(ws.labels, hasLength(1));
      final revived = ws.labels.single.id;
      expect(ws.task(parent)!.labelIds, [revived]);
      expect(ws.task(child)!.labelIds, [revived]);
    });

    test('созданную заново метку тоже удалили — следующий возврат создаёт '
        'ещё одну, с другим id', () async {
      final label = await app.labels.add(name: 'дом');
      final first = await app.tasks.add(content: '1', labelIds: {label});
      final second = await app.tasks.add(content: '2', labelIds: {label});
      await app.tasks.complete(first);
      await app.tasks.complete(second);
      await app.labels.delete(label);

      await app.tasks.uncomplete(first);
      final revived = (await app.read()).labels.single.id;
      await app.labels.delete(revived);
      await app.tasks.uncomplete(second);

      final ws = await app.read();
      final again = ws.labels.single;
      expect(again.name, 'дом');
      expect({again.id, revived, label}, hasLength(3));
      expect(ws.task(second)!.labelIds, [again.id]);
      expect(ws.task(first)!.labelIds, isEmpty);
    });

    test('задача, активная при удалении метки, после завершения её не '
        'показывает, а возврат в работу метку не создаёт', () async {
      final label = await app.labels.add(name: 'дом');
      final open = await app.tasks.add(content: 'open', labelIds: {label});
      await app.labels.delete(label);

      await app.tasks.complete(open);
      expect((await app.read()).task(open)!.labelIds, isEmpty);
      await app.tasks.uncomplete(open);
      final ws = await app.read();
      expect(ws.labels, isEmpty);
      expect(ws.task(open)!.labelIds, isEmpty);
    });

    test('удалённую метку восстановили после возврата задачи (выбор на '
        'экране «Конфликты») — на задаче только новая метка', () async {
      final label = await app.labels.add(name: 'дом');
      final done = await app.tasks.add(content: 'done', labelIds: {label});
      await app.tasks.complete(done);
      await app.labels.delete(label);
      await app.tasks.uncomplete(done);
      final revived = (await app.read()).labels.single.id;

      await device.services.mutator.restore(EntityTypes.label, label);
      final ws = await app.read();
      expect(ws.labels, hasLength(2));
      expect(ws.task(done)!.labelIds, [revived]);
    });

    test('переименование после завершения — на выполненной задаче имя на '
        'момент завершения, на активной новое', () async {
      final label = await app.labels.add(name: 'дом');
      final open = await app.tasks.add(content: 'open', labelIds: {label});
      final done = await app.tasks.add(content: 'done', labelIds: {label});
      await app.tasks.complete(done);
      await app.labels.rename(label, 'дача');

      final ws = await app.read();
      expect(ws.task(done)!.completedLabelNames, {label: 'дом'});
      expect(ws.taskLabel(ws.task(done)!, label)?.name, 'дом');
      expect(ws.taskLabel(ws.task(open)!, label)?.name, 'дача');
      expect(ws.label(label)?.name, 'дача');
    });

    test('метку переименовали после завершения и удалили — возврат в работу '
        'создаёт метку с именем на момент завершения, снимок снят', () async {
      final label = await app.labels.add(name: 'дом');
      final done = await app.tasks.add(content: 'done', labelIds: {label});
      await app.tasks.complete(done);
      await app.labels.rename(label, 'дача');
      await app.labels.delete(label);
      final before = await app.read();
      expect(before.taskLabel(before.task(done)!, label)?.name, 'дом');

      await app.tasks.uncomplete(done);
      final ws = await app.read();
      final revived = ws.labels.single;
      expect(revived.name, 'дом');
      expect(ws.task(done)!.labelIds, [revived.id]);
      expect(
        (await device.entity(
          EntityTypes.task,
          done,
        ))![TaskFields.completedLabelNames],
        isNull,
      );
    });

    test('переименованная после завершения живая метка — возврат оставляет '
        'её на задаче с текущим именем (допущение О-41)', () async {
      final label = await app.labels.add(name: 'дом');
      final done = await app.tasks.add(content: 'done', labelIds: {label});
      await app.tasks.complete(done);
      await app.labels.rename(label, 'дача');

      await app.tasks.uncomplete(done);
      final ws = await app.read();
      expect([for (final l in ws.labels) l.name], ['дача']);
      expect(ws.taskLabel(ws.task(done)!, label)?.name, 'дача');
    });

    test('задача без меток — снимок не пишется; «Отменить» завершения '
        'снимает снимок задачи с метками', () async {
      final label = await app.labels.add(name: 'дом');
      final plain = await app.tasks.add(content: 'plain');
      final tagged = await app.tasks.add(content: 'tagged', labelIds: {label});
      await app.tasks.complete(plain);
      expect(
        (await device.entity(
          EntityTypes.task,
          plain,
        ))!.containsKey(TaskFields.completedLabelNames),
        isFalse,
      );

      final undo = await app.tasks.complete(tagged);
      expect(
        (await device.entity(
          EntityTypes.task,
          tagged,
        ))![TaskFields.completedLabelNames],
        {label: 'дом'},
      );
      await undo();
      final ws = await app.read();
      expect(ws.task(tagged)!.isCompleted, isFalse);
      expect(
        (await device.entity(
          EntityTypes.task,
          tagged,
        ))![TaskFields.completedLabelNames],
        isNull,
      );
    });

    test('архив раздела и завершение с подзадачами пишут снимок каждой '
        'завершённой задаче с метками', () async {
      final label = await app.labels.add(name: 'дом');
      final project = await app.projects.add(name: 'Работа');
      final section = await app.sections.add(project, name: 'Неделя');
      final inSection = await app.tasks.add(
        content: 'в разделе',
        projectId: project,
        sectionId: section,
        labelIds: {label},
      );
      final parent = await app.tasks.add(content: 'p');
      final child = await app.tasks.add(
        content: 'c',
        parentId: parent,
        labelIds: {label},
      );
      await app.sections.archive(section);
      await app.tasks.complete(parent);
      await app.labels.rename(label, 'дача');

      final ws = await app.read();
      for (final t in [inSection, child]) {
        expect(ws.task(t)!.completedLabelNames, {label: 'дом'}, reason: t);
        expect(ws.taskLabel(ws.task(t)!, label)?.name, 'дом', reason: t);
      }
      expect(ws.task(parent)!.completedLabelNames, isEmpty);
    });

    test('одна удалённая метка под разными именами в снимках задач одного '
        'возврата — у каждого имени своя новая метка', () async {
      final label = await app.labels.add(name: 'дом');
      final parent = await app.tasks.add(content: 'p', labelIds: {label});
      final child = await app.tasks.add(
        content: 'c',
        parentId: parent,
        labelIds: {label},
      );
      await app.tasks.complete(child);
      await app.labels.rename(label, 'работа');
      await app.tasks.complete(parent);
      await app.labels.delete(label);

      // Возврат подзадачи возвращает и родителя — одно действие.
      await app.tasks.uncomplete(child);
      final ws = await app.read();
      String nameOn(String t) => ws.label(ws.task(t)!.labelIds.single)!.name;
      expect({for (final l in ws.labels) l.name}, {'дом', 'работа'});
      expect(nameOn(child), 'дом');
      expect(nameOn(parent), 'работа');
    });

    test('удалённая метка известна только по tombstone: со снимком возврат '
        'создаёт метку с его именем, без снимка — ничего не создаёт', () async {
      final mutator = device.services.mutator;
      Future<String> doneWithGhost(String ghost, {String? name}) async {
        final t = await app.tasks.add(content: ghost);
        await mutator.update(EntityTypes.taskLabel, taskLabelId(t, ghost), {
          TaskLabelFields.taskId: t,
          TaskLabelFields.labelId: ghost,
          TaskLabelFields.deleted: false,
        });
        await mutator.update(EntityTypes.task, t, {
          TaskFields.isCompleted: true,
          TaskFields.completedLabelNames: ?(name == null
              ? null
              : {ghost: name}),
        });
        device.advance(const Duration(seconds: 1));
        await mutator.delete(EntityTypes.label, ghost);
        return t;
      }

      final named = await doneWithGhost('ghost1', name: 'дом');
      final bare = await doneWithGhost('ghost2');
      await app.tasks.uncomplete(named);
      await app.tasks.uncomplete(bare);

      final ws = await app.read();
      final revived = ws.labels.single;
      expect(
        (revived.id, revived.name),
        (revivedLabelId('ghost1', 'дом'), 'дом'),
      );
      expect(ws.task(named)!.labelIds, [revived.id]);
      expect(ws.task(bare)!.labelIds, isEmpty);
    });

    test('«Отменить» возврата в работу возвращает и снимок имён', () async {
      final label = await app.labels.add(name: 'дом');
      final done = await app.tasks.add(content: 'done', labelIds: {label});
      await app.tasks.complete(done);
      await app.labels.rename(label, 'дача');

      final undo = await app.tasks.uncomplete(done);
      await undo();
      final ws = await app.read();
      expect(ws.task(done)!.isCompleted, isTrue);
      expect(ws.taskLabel(ws.task(done)!, label)?.name, 'дом');
    });

    test('старый снимок у задачи, завершённой уже без меток, снимается: '
        'метка, поставленная потом, — под текущим именем', () async {
      final label = await app.labels.add(name: 'дом');
      final task = await app.tasks.add(content: 't', labelIds: {label});
      await app.tasks.complete(task);
      // Возврат без снятия снимка — как после параллельных завершения на
      // одном устройстве и возврата на другом.
      await device.services.mutator.update(EntityTypes.task, task, {
        TaskFields.isCompleted: false,
      });
      await app.tasks.setLabels(task, const {});
      await app.labels.rename(label, 'дача');
      await app.tasks.complete(task);
      await app.tasks.setLabels(task, {label});

      final ws = await app.read();
      expect(ws.task(task)!.completedLabelNames, isEmpty);
      expect(ws.taskLabel(ws.task(task)!, label)?.name, 'дача');
    });

    test('дубликат выполненной задачи не получает связь с удалённой '
        'меткой', () async {
      final gone = await app.labels.add(name: 'дом');
      final work = await app.labels.add(name: 'работа');
      final done = await app.tasks.add(content: 'done', labelIds: {gone, work});
      await app.tasks.complete(done);
      await app.labels.delete(gone);

      final copy = await app.tasks.duplicate(done);
      final links = await (device.db.select(
        device.db.taskLabels,
      )..where((l) => l.taskId.equals(copy))).get();
      expect([for (final l in links) l.labelId], [work]);
    });

    test(
      'setLabels на выполненной задаче не снимает удалённую метку',
      () async {
        final gone = await app.labels.add(name: 'дом');
        final work = await app.labels.add(name: 'работа');
        final done = await app.tasks.add(content: 'done', labelIds: {gone});
        await app.tasks.complete(done);
        await app.labels.delete(gone);

        await app.tasks.setLabels(done, {work});
        expect((await app.read()).task(done)!.labelIds, [gone, work]);
        await app.tasks.setLabels(done, {});
        expect((await app.read()).task(done)!.labelIds, [gone]);
      },
    );

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
