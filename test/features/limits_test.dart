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
}
