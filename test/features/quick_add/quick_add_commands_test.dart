import 'package:flutter_test/flutter_test.dart';
import 'package:planner/data/projection/entity_fields.dart';
import 'package:planner/domain/models.dart';
import 'package:planner/domain/rules.dart';
import 'package:planner/features/quick_add/logic/quick_add_draft.dart';

import '../../sync/support/devices.dart';
import '../support/app_commands.dart';

// Запись быстрого добавления: новые проект и метки — одной транзакцией с
// задачами (план M3.6, решение 1А «Ход M3.6»); настройка «Умное
// распознавание дат».
void main() {
  late TestDevice device;
  late AppCommands app;

  setUp(() async {
    device = await TestDevice.start();
    app = AppCommands(device);
  });

  tearDown(() => device.db.close());

  TaskDraft draft(
    String title, {
    String? projectId = inboxProjectId,
    String? newProject,
    String? parentId,
    List<String> newLabels = const [],
    Set<String> labelIds = const {},
    Due? due,
    int priority = 4,
  }) => TaskDraft(
    title: title,
    description: '',
    projectId: projectId,
    newProject: newProject,
    sectionId: null,
    parentId: parentId,
    labelIds: labelIds,
    newLabels: newLabels,
    priority: priority,
    due: due,
    deadline: null,
    duration: null,
  );

  test('новые проект и метка создаются вместе с задачей', () async {
    final ids = await app.quickAdd.add([
      draft(
        'Read',
        projectId: null,
        newProject: 'Books',
        newLabels: ['later'],
        due: const Due(date: '2026-10-24', string: 'tomorrow', lang: 'en'),
        priority: 2,
      ),
    ]);
    final ws = await app.read();
    final task = ws.task(ids.single)!;
    final project = ws.project(task.projectId!)!;
    expect(project.name, 'Books');
    expect(ws.label(task.labelIds.single)!.name, 'later');
    expect(task.due?.string, 'tomorrow');
    expect(task.priority, 2);
  });

  test('отказ на второй задаче — ни проекта, ни метки, ни первой задачи '
      '(одна транзакция)', () async {
    await expectLater(
      app.quickAdd.add([
        draft('A', projectId: null, newProject: 'Books', newLabels: ['x']),
        draft('B', parentId: 'missing'),
      ]),
      throwsA(isA<CommandRejected>()),
    );
    final ws = await app.read();
    expect(ws.projectTree(), isEmpty);
    expect(ws.labels, isEmpty);
    expect(ws.children(null), isEmpty);
  });

  test(
    'одно новое имя у нескольких строк — один проект и одна метка',
    () async {
      await app.quickAdd.add([
        for (final t in ['A', 'B'])
          draft(t, projectId: null, newProject: 'Books', newLabels: ['Later']),
      ]);
      final ws = await app.read();
      expect(ws.projectTree().map((p) => p.value.name), ['Books']);
      expect(ws.labels.map((l) => l.name), ['Later']);
      final books = ws.projectTree().single.value.id;
      expect(ws.children(null, projectId: books).map((t) => t.content), [
        'A',
        'B',
      ]);
    },
  );

  test(
    'имя уже появилось (пришло синхронизацией) — берётся существующее',
    () async {
      final books = await app.projects.add(name: 'books');
      final label = await app.labels.add(name: 'later');
      final ids = await app.quickAdd.add([
        draft(
          'Read',
          projectId: null,
          newProject: 'Books',
          newLabels: ['Later'],
        ),
      ]);
      final ws = await app.read();
      expect(ws.task(ids.single)!.projectId, books);
      expect(ws.task(ids.single)!.labelIds, [label]);
      expect(ws.projectTree(), hasLength(1));
    },
  );

  test('вверху места — строки по порядку, а не задом наперёд', () async {
    await app.tasks.add(content: 'Old');
    await app.quickAdd.add([draft('A'), draft('B')], atTop: true);
    final ws = await app.read();
    expect(ws.children(null).map((t) => t.content), ['A', 'B', 'Old']);
  });

  group('«Умное распознавание дат»', () {
    test('поля нет — включено; запись — op сущности settings', () async {
      expect(await app.settings.smartDateRecognition(), isTrue);
      await app.general.setSmartDateRecognition(false);
      expect(await app.settings.smartDateRecognition(), isFalse);
      final ops = await device.ownOps();
      expect(
        ops.where(
          (op) =>
              op.entityType == EntityTypes.settings &&
              op.field == SettingsFields.smartDateRecognition,
        ),
        hasLength(1),
      );
    });

    test('поток отдаёт новое значение', () async {
      final values = app.settings.watchSmartDateRecognition();
      final seen = <bool>[];
      final sub = values.listen(seen.add);
      await pumpEventQueue();
      await app.general.setSmartDateRecognition(false);
      await pumpEventQueue();
      await sub.cancel();
      expect(seen, [true, false]);
    });
  });
}
