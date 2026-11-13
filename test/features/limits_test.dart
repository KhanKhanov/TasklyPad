import 'package:flutter_test/flutter_test.dart';
import 'package:planner/data/projection/entity_fields.dart';
import 'package:planner/domain/models.dart';
import 'package:planner/domain/rules.dart';
import 'package:planner/features/quick_add/logic/quick_add_draft.dart';

import '../sync/support/devices.dart';
import 'support/app_commands.dart';

// Лимиты help «Usage limits» (О-49, О-27; решения 14А и 3А «Часть M4.11»
// plans/m4): сверх лимита — отказ до записи, ни одной op.
Matcher _rejected(RejectReason reason) =>
    throwsA(isA<CommandRejected>().having((e) => e.reason, 'reason', reason));

void main() {
  late TestDevice device;
  late AppCommands app;

  setUp(() async {
    device = await TestDevice.start();
    app = AppCommands(device);
  });

  /// [action] отклонено с [reason], и ни одной новой op.
  Future<void> rejectsWithoutOps(
    Future<Object?> Function() action,
    RejectReason reason,
  ) async {
    final before = (await device.ownOps()).length;
    await expectLater(action(), _rejected(reason));
    expect((await device.ownOps()).length, before);
  }

  /// Пачка записей одной транзакцией — подготовка больших наборов быстрее.
  Future<T> batch<T>(Future<T> Function() action) =>
      device.services.mutator.batch(action);

  TaskDraft draft(String title, {String? projectId, Set<String>? labels}) =>
      TaskDraft(
        title: title,
        description: '',
        projectId: projectId ?? inboxProjectId,
        newProject: null,
        sectionId: null,
        parentId: null,
        labelIds: labels ?? const {},
        newLabels: const [],
        priority: 4,
        due: null,
        deadline: null,
        duration: null,
      );

  group('длина текста — в символах Unicode, эмодзи — один', () {
    test('название задачи — 500', () async {
      final ok = await app.tasks.add(content: '😀' * 500);
      expect(Limits.length((await app.read()).task(ok)!.content), 500);
      await rejectsWithoutOps(
        () => app.tasks.add(content: 'a' * 501),
        RejectReason.tooLong,
      );
      await rejectsWithoutOps(
        () => app.tasks.rename(ok, 'a' * 501),
        RejectReason.tooLong,
      );
      await rejectsWithoutOps(
        () => app.quickAdd.add([draft('a' * 501)]),
        RejectReason.tooLong,
      );
    });

    test('описание задачи — 16383', () async {
      final id = await app.tasks.add(content: 'Задача');
      await app.tasks.setDescription(id, 'a' * Limits.description);
      await rejectsWithoutOps(
        () => app.tasks.setDescription(id, 'a' * (Limits.description + 1)),
        RejectReason.tooLong,
      );
      await rejectsWithoutOps(
        () => app.tasks.add(
          content: 'x',
          description: 'a' * (Limits.description + 1),
        ),
        RejectReason.tooLong,
      );
    });

    test('имя проекта — 120, раздела — 2048, метки — 60', () async {
      final p = await app.projects.add(name: 'a' * 120);
      await rejectsWithoutOps(
        () => app.projects.add(name: 'a' * 121),
        RejectReason.tooLong,
      );
      await rejectsWithoutOps(
        () => app.projects.rename(p, 'a' * 121),
        RejectReason.tooLong,
      );
      final s = await app.sections.add(p, name: 'a' * 2048);
      await rejectsWithoutOps(
        () => app.sections.add(p, name: 'a' * 2049),
        RejectReason.tooLong,
      );
      await rejectsWithoutOps(
        () => app.sections.rename(s, 'b' * 2049),
        RejectReason.tooLong,
      );
      final l = await app.labels.add(name: 'a' * 60);
      await rejectsWithoutOps(
        () => app.labels.add(name: 'b' * 61),
        RejectReason.tooLong,
      );
      await rejectsWithoutOps(
        () => app.labels.edit(l, name: 'c' * 61),
        RejectReason.tooLong,
      );
    });

    test('копия с именем на пределе — имя обрезается, а не отказ', () async {
      final p = await app.projects.add(name: 'a' * 120);
      final copy = await app.projects.duplicate(
        p,
        name: 'Copy of ${'a' * 120}',
      );
      expect(Limits.length((await app.read()).project(copy)!.name), 120);
    });

    test('текст срока — 150', () async {
      final id = await app.tasks.add(content: 'Задача');
      await app.tasks.setDue(
        id,
        Due(date: '2026-11-12', string: 'a' * Limits.dueText),
      );
      await rejectsWithoutOps(
        () => app.tasks.setDue(
          id,
          Due(date: '2026-11-12', string: 'a' * (Limits.dueText + 1)),
        ),
        RejectReason.tooLong,
      );
    });

    test('текст повторяющегося срока длиннее 150, пришедший с другого '
        'устройства, не мешает правке срока и переносу дня', () async {
      final id = await app.tasks.add(content: 'Задача');
      final long = 'every day ${'a' * Limits.dueText}';
      await device.services.mutator.update(EntityTypes.task, id, {
        TaskFields.due: {
          DueKeys.date: '2026-11-12',
          DueKeys.string: long,
          DueKeys.rule: {
            RuleKeys.rrule: ['FREQ=DAILY'],
            RuleKeys.fromCompletion: false,
          },
        },
      });
      final due = (await app.read()).task(id)!.due!;
      await app.tasks.setDue(id, due.copyWith(date: '2026-11-14'));
      await app.tasks.moveToDay(id, '2026-11-13');
      expect((await app.read()).task(id)!.due!.string, long);
    });
  });

  group('метки — 500 всего, 100 на задаче', () {
    Future<List<String>> labels(int n) => batch(() async {
      return [for (var i = 0; i < n; i++) await app.labels.add(name: 'l$i')];
    });

    test('501-я метка — отказ, и из быстрого добавления', () async {
      await labels(Limits.labels);
      await rejectsWithoutOps(
        () => app.labels.add(name: 'extra'),
        RejectReason.tooManyLabelsTotal,
      );
      final line = TaskDraft(
        title: 'Задача',
        description: '',
        projectId: inboxProjectId,
        newProject: null,
        sectionId: null,
        parentId: null,
        labelIds: const {},
        newLabels: const ['extra'],
        priority: 4,
        due: null,
        deadline: null,
        duration: null,
      );
      await rejectsWithoutOps(
        () => app.quickAdd.add([line]),
        RejectReason.tooManyLabelsTotal,
      );
    });

    test('101-я на задаче — отказ: выбор меток, добавление, быстрое '
        'добавление; снять лишние можно', () async {
      final ids = await labels(Limits.labelsPerTask + 1);
      final hundred = ids.take(Limits.labelsPerTask).toSet();
      final id = await app.tasks.add(content: 'Задача', labelIds: hundred);
      await rejectsWithoutOps(
        () => app.tasks.setLabels(id, ids.toSet()),
        RejectReason.tooManyLabels,
      );
      await rejectsWithoutOps(
        () => app.tasks.add(content: 'Ещё', labelIds: ids.toSet()),
        RejectReason.tooManyLabels,
      );
      await rejectsWithoutOps(
        () => app.quickAdd.add([draft('Ещё', labels: ids.toSet())]),
        RejectReason.tooManyLabels,
      );
      await app.tasks.setLabels(id, hundred.skip(1).toSet());
      expect((await app.read()).task(id)!.labelIds, hasLength(99));
    });
  });

  group('300 активных задач в проекте', () {
    late String full;

    setUp(() async {
      full = await app.projects.add(name: 'Full');
      await batch(() async {
        for (var i = 0; i < Limits.activeTasksPerProject; i++) {
          await app.tasks.add(content: 't$i', projectId: full);
        }
      });
    });

    test('301-я — отказ: добавление, подзадача, быстрое добавление '
        'несколькими строками — ни одной', () async {
      final ws = await app.read();
      final first = ws.projectTasks(full, showCompleted: false).first.id;
      await rejectsWithoutOps(
        () => app.tasks.add(content: 'x', projectId: full),
        RejectReason.tooManyTasks,
      );
      await rejectsWithoutOps(
        () => app.tasks.add(content: 'x', parentId: first),
        RejectReason.tooManyTasks,
      );
      await rejectsWithoutOps(
        () => app.quickAdd.add([
          draft('a', projectId: full),
          draft('b', projectId: full),
        ]),
        RejectReason.tooManyTasks,
      );
    });

    test('299 + две строки быстрого добавления — отказ обеих', () async {
      final ws = await app.read();
      await app.tasks.delete(
        ws.projectTasks(full, showCompleted: false).first.id,
      );
      await rejectsWithoutOps(
        () => app.quickAdd.add([
          draft('a', projectId: full),
          draft('b', projectId: full),
        ]),
        RejectReason.tooManyTasks,
      );
      await app.quickAdd.add([draft('a', projectId: full)]);
    });

    test('перенос, дубликат, «Вернуть», перенос и дубликат раздела — отказ; '
        'внутри проекта переставлять можно', () async {
      final other = await app.tasks.add(content: 'Другая');
      await rejectsWithoutOps(
        () => app.tasks.move(other, projectId: full),
        RejectReason.tooManyTasks,
      );
      await rejectsWithoutOps(
        () => app.bulk.move([other], full, null),
        RejectReason.tooManyTasks,
      );

      final tasks = (await app.read()).projectTasks(full, showCompleted: false);
      await rejectsWithoutOps(
        () => app.tasks.duplicate(tasks.first.id),
        RejectReason.tooManyTasks,
      );
      await app.tasks.move(tasks.first.id, projectId: full, atTop: false);

      await app.tasks.complete(tasks.first.id);
      await app.tasks.add(content: 'на место выполненной', projectId: full);
      await rejectsWithoutOps(
        () => app.tasks.uncomplete(tasks.first.id),
        RejectReason.tooManyTasks,
      );

      final p = await app.projects.add(name: 'Other');
      final s = await app.sections.add(p, name: 'S');
      await app.tasks.add(content: 'в разделе', projectId: p, sectionId: s);
      await rejectsWithoutOps(
        () => app.sections.moveToProject(s, full),
        RejectReason.tooManyTasks,
      );
      final own = await app.sections.add(full, name: 'Own');
      await app.tasks.move(tasks[1].id, projectId: full, sectionId: own);
      await rejectsWithoutOps(
        () => app.sections.duplicate(own, name: 'Copy of Own'),
        RejectReason.tooManyTasks,
      );
    });
  });

  group('500 активных проектов', () {
    test('501-й — отказ: добавление, дубликат, возврат из архива', () async {
      final archived = await app.projects.add(name: 'Archived');
      await app.projects.archive(archived);
      // «Входящие» тоже активный проект.
      await batch(() async {
        for (var i = 1; i < Limits.activeProjects; i++) {
          await app.projects.add(name: 'p$i');
        }
      });
      expect((await app.read()).activeProjectCount, Limits.activeProjects);
      await rejectsWithoutOps(
        () => app.projects.add(name: 'extra'),
        RejectReason.tooManyProjects,
      );
      final some = (await app.read()).childProjects(null).last.id;
      await rejectsWithoutOps(
        () => app.projects.duplicate(some, name: 'Copy'),
        RejectReason.tooManyProjects,
      );
      await rejectsWithoutOps(
        () => app.projects.unarchive(archived),
        RejectReason.tooManyProjects,
      );
    });

    test('возврат из архива считает только возвращаемые: подпроект в своём '
        'архиве остаётся там', () async {
      final p = await app.projects.add(name: 'P');
      final c = await app.projects.add(name: 'C', parentId: p);
      await app.projects.add(name: 'D', parentId: c);
      await app.projects.archive(c);
      await app.projects.archive(p);
      // Активных: «Входящие» + 498 = 499 — место ровно для одного (P).
      await batch(() async {
        for (var i = 2; i < Limits.activeProjects; i++) {
          await app.projects.add(name: 'p$i');
        }
      });
      await app.projects.unarchive(p);
      final ws = await app.read();
      expect(ws.isProjectArchived(p), isFalse);
      expect(ws.isProjectArchived(c), isTrue);
    });
  });

  /// Добавить в [project] задачи, пока активных не станет [count].
  Future<void> fillTo(String project, int count) => batch(() async {
    final have = (await app.read()).activeTaskCount(project);
    for (var i = have; i < count; i++) {
      await app.tasks.add(content: 't$i', projectId: project);
    }
  });

  group('О-81: счёт у предела 300 — только те, что станут активными', () {
    late String full;

    /// Незавершённая задача, пришедшая с другого устройства в раздел,
    /// который здесь уже в архиве (запись мимо команд, как синхронизация).
    Future<String> arrivedInto(String project, String section) =>
        device.services.mutator.create(EntityTypes.task, {
          TaskFields.content: 'с другого устройства',
          TaskFields.projectId: project,
          TaskFields.sectionId: section,
          TaskFields.orderKey: 'z',
          TaskFields.priority: 4,
        });

    setUp(() async {
      full = await app.projects.add(name: 'Full');
    });

    test('перенос архивного раздела с незавершённой задачей в полный проект '
        '— можно: его задачи не станут активными', () async {
      final other = await app.projects.add(name: 'Other');
      final s = await app.sections.add(other, name: 'S');
      await app.tasks.add(content: 'в разделе', projectId: other, sectionId: s);
      await app.sections.archive(s);
      await arrivedInto(other, s);
      await fillTo(full, Limits.activeTasksPerProject);

      await app.sections.moveToProject(s, full);
      final ws = await app.read();
      expect(ws.section(s)!.projectId, full);
      expect(ws.activeTaskCount(full), Limits.activeTasksPerProject);
    });

    test('добавление подзадачи под выполненного родителя при 300 активных — '
        'без отказа', () async {
      final done = await app.tasks.add(content: 'Выполнена', projectId: full);
      await app.tasks.complete(done);
      await fillTo(full, Limits.activeTasksPerProject);

      final sub = await app.tasks.add(content: 'Подзадача', parentId: done);
      final ws = await app.read();
      expect(ws.taskParent(sub), done);
      expect(ws.isTaskActive(sub), isFalse);
      expect(ws.activeTaskCount(full), Limits.activeTasksPerProject);
      // Под активного родителя — по-прежнему отказ.
      final active = ws.projectTasks(full).first.id;
      await rejectsWithoutOps(
        () => app.tasks.add(content: 'x', parentId: active),
        RejectReason.tooManyTasks,
      );
    });

    test(
      'перенос под выполненного родителя в полном проекте — можно',
      () async {
        final done = await app.tasks.add(content: 'Выполнена', projectId: full);
        await app.tasks.complete(done);
        await fillTo(full, Limits.activeTasksPerProject);
        final x = await app.tasks.add(content: 'X');

        await app.tasks.move(x, parentId: done);
        final ws = await app.read();
        expect(ws.taskParent(x), done);
        expect(ws.activeTaskCount(full), Limits.activeTasksPerProject);
      },
    );

    test('незавершённая подзадача под выполненной в переносимом и '
        'дублируемом дереве не считается', () async {
      final x = await app.tasks.add(content: 'X');
      final y = await app.tasks.add(content: 'Y', parentId: x);
      await app.tasks.add(content: 'Z', parentId: y);
      // Выполнена одна Y: так бывает, когда Z добавили на другом устройстве,
      // пока здесь выполняли Y (команда завершила бы и Z).
      await device.services.mutator.update(EntityTypes.task, y, {
        TaskFields.isCompleted: true,
      });
      // Z незавершена, но под выполненной Y: активной не станет.
      await fillTo(full, Limits.activeTasksPerProject - 1);

      await app.tasks.move(x, projectId: full);
      var ws = await app.read();
      expect(ws.rootProjectOf(x), full);
      expect(ws.activeTaskCount(full), Limits.activeTasksPerProject);

      await app.tasks.delete(
        ws.projectTasks(full).firstWhere((t) => t.content == 't0').id,
      );
      // Копия X — без выполненной Y и её Z: ровно одна новая активная.
      await app.tasks.duplicate(x);
      ws = await app.read();
      expect(ws.activeTaskCount(full), Limits.activeTasksPerProject);
    });

    test('дубликат задачи под выполненным родителем в полном проекте — '
        'можно: копия встаёт под выполненного и активной не становится', () async {
      final done = await app.tasks.add(content: 'Выполнена', projectId: full);
      final sub = await app.tasks.add(content: 'Подзадача', parentId: done);
      await app.tasks.complete(done);
      await app.tasks.uncomplete(sub);
      // «Вернуть» подзадачи возвращает и родителя — завершаем его снова одного.
      await device.services.mutator.update(EntityTypes.task, done, {
        TaskFields.isCompleted: true,
      });
      await fillTo(full, Limits.activeTasksPerProject);
      var ws = await app.read();
      expect(ws.task(sub)!.isCompleted, isFalse);
      expect(ws.isTaskActive(sub), isFalse);

      final copy = await app.tasks.duplicate(sub);
      ws = await app.read();
      expect(ws.taskParent(copy), done);
      expect(ws.activeTaskCount(full), Limits.activeTasksPerProject);
    });

    test('«Вернуть» с возвратом архивного раздела считает и его незавершённые '
        'задачи', () async {
      final s = await app.sections.add(full, name: 'S');
      final t = await app.tasks.add(
        content: 'в разделе',
        projectId: full,
        sectionId: s,
      );
      await app.sections.archive(s);
      await arrivedInto(full, s);
      // 299 активных: возврат t вернёт раздел, а с ним и пришедшую — 301.
      await fillTo(full, Limits.activeTasksPerProject - 1);
      await rejectsWithoutOps(
        () => app.tasks.uncomplete(t),
        RejectReason.tooManyTasks,
      );

      await app.tasks.delete((await app.read()).projectTasks(full).first.id);
      await app.tasks.uncomplete(t);
      final ws = await app.read();
      expect(ws.section(s)!.isArchived, isFalse);
      expect(ws.activeTaskCount(full), Limits.activeTasksPerProject);
    });
  });

  group('массовые действия у предела 300 — шаги считаются вместе', () {
    late String full;

    setUp(() async {
      full = await app.projects.add(name: 'Full');
    });

    test('«Вернуть» двух задач архивного раздела с пришедшей задачей — 300, '
        'без лишнего отказа: раздел возвращается один раз', () async {
      final s = await app.sections.add(full, name: 'S');
      final z = [
        for (final name in ['z1', 'z2'])
          await app.tasks.add(content: name, projectId: full, sectionId: s),
      ];
      await app.sections.archive(s);
      await device.services.mutator.create(EntityTypes.task, {
        TaskFields.content: 'с другого устройства',
        TaskFields.projectId: full,
        TaskFields.sectionId: s,
        TaskFields.orderKey: 'z',
        TaskFields.priority: 4,
      });
      await fillTo(full, Limits.activeTasksPerProject - 3);

      await app.bulk.uncomplete(z);
      expect(
        (await app.read()).activeTaskCount(full),
        Limits.activeTasksPerProject,
      );
    });

    test('«Вернуть» и «Дублировать» двух при 299 — отказ всего действия, ни '
        'одной op', () async {
      final done = [
        for (final name in ['c1', 'c2'])
          await app.tasks.add(content: name, projectId: full),
      ];
      for (final id in done) {
        await app.tasks.complete(id);
      }
      await fillTo(full, Limits.activeTasksPerProject - 1);
      await rejectsWithoutOps(
        () => app.bulk.uncomplete(done),
        RejectReason.tooManyTasks,
      );
      final two = [
        for (final t in (await app.read()).projectTasks(full).take(2)) t.id,
      ];
      await rejectsWithoutOps(
        () => app.bulk.duplicate(two),
        RejectReason.tooManyTasks,
      );
      expect(
        (await app.read()).activeTaskCount(full),
        Limits.activeTasksPerProject - 1,
      );
    });
  });

  group('решение 3А «Ход M4.13»: сверх лимита без отказа', () {
    late String full;

    setUp(() async {
      full = await app.projects.add(name: 'Full');
    });

    Future<void> resetOn() => device.services.mutator.update(
      EntityTypes.settings,
      settingsEntityId,
      {SettingsFields.resetRecurringSubtasks: true},
    );

    const daily = Due(
      date: '2026-10-23',
      string: 'каждый день',
      lang: 'ru',
      rule: RecurrenceRule(rrule: ['FREQ=DAILY'], fromCompletion: false),
    );

    Future<void> labelsTo(int count) => batch(() async {
      final have = (await app.read()).labels.length;
      for (var i = have; i < count; i++) {
        await app.labels.add(name: 'l$i');
      }
    });

    test('сброс подзадач повторяющейся задачи в полном проекте — 301 '
        'активная', () async {
      final r = await app.tasks.add(content: 'R', projectId: full, due: daily);
      final s = await app.tasks.add(content: 'S', parentId: r);
      await app.tasks.complete(s);
      await fillTo(full, Limits.activeTasksPerProject);
      await resetOn();

      await app.tasks.complete(r);
      final ws = await app.read();
      expect(ws.task(s)!.isCompleted, isFalse);
      expect(ws.activeTaskCount(full), Limits.activeTasksPerProject + 1);
    });

    test('«Отменить» выполнения в проекте, заполненном за время тоста, — 301 '
        'активная', () async {
      await fillTo(full, Limits.activeTasksPerProject);
      final first = (await app.read()).projectTasks(full).first.id;
      final undo = await app.tasks.complete(first);
      await app.tasks.add(content: 'на место выполненной', projectId: full);

      await undo();
      expect(
        (await app.read()).activeTaskCount(full),
        Limits.activeTasksPerProject + 1,
      );
    });

    test('«Вернуть» задачу с удалённой меткой при 500 метках — метка '
        'создаётся заново, 501', () async {
      final label = await app.labels.add(name: 'дом');
      final t = await app.tasks.add(content: 'T', labelIds: {label});
      await app.tasks.complete(t);
      await app.labels.delete(label);
      await labelsTo(Limits.labels);

      await app.tasks.uncomplete(t);
      final ws = await app.read();
      expect(ws.labels, hasLength(Limits.labels + 1));
      expect(
        [for (final l in ws.task(t)!.labelIds) ws.label(l)!.name],
        ['дом'],
      );
    });

    test('сброс подзадачи с удалённой меткой при 500 метках — метка '
        'создаётся заново, 501', () async {
      final label = await app.labels.add(name: 'дом');
      final r = await app.tasks.add(content: 'R', due: daily);
      final s = await app.tasks.add(
        content: 'S',
        parentId: r,
        labelIds: {label},
      );
      await app.tasks.complete(s);
      await app.labels.delete(label);
      await labelsTo(Limits.labels);
      await resetOn();

      await app.tasks.complete(r);
      expect((await app.read()).labels, hasLength(Limits.labels + 1));
    });
  });
}
