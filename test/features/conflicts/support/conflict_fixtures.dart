import 'package:flutter_test/flutter_test.dart';
import 'package:planner/data/projection/entity_fields.dart';
import 'package:planner/sync/mutator.dart';

import '../../../app/support/pump_app.dart';
import '../../../sync/support/devices.dart';

/// Настоящий конфликт для экранных тестов: второе устройство и обмен ops
/// через движок. Сущность [type] создаёт [create] (id — результат); потом
/// второе устройство правит её полями [theirs] по порядку, каждая правка
/// минутой позже прежней, а это устройство — полями [mine]. Возвращает id.
///
/// Каждый шаг с базой приложения — отдельным `runAsync` с кадрами между
/// ними: правка будит потоки экранов, их запросы идут в фейковом времени
/// теста, и следующий запрос к той же базе внутри одного `runAsync` ждал
/// бы их вечно.
Future<String> makeEntityConflict(
  WidgetTester tester,
  TestDevice device, {
  required String type,
  required Future<String> Function(Mutator mutator) create,
  required Map<String, Object?> mine,
  required List<Map<String, Object?>> theirs,
}) async {
  final mutator = device.services.mutator;
  final other = (await tester.runAsync(() => TestDevice.start(seed: 7)))!;
  final id = (await tester.runAsync(() => create(mutator)))!;
  await settle(tester);
  final created = (await tester.runAsync(device.ownOps))!;
  await settle(tester);
  await tester.runAsync(() async {
    await other.services.engine.applyAll(created);
    for (final fields in theirs) {
      other.advance(const Duration(minutes: 1));
      await other.services.mutator.update(type, id, fields);
    }
  });
  await tester.runAsync(() => mutator.update(type, id, mine));
  await settle(tester);
  final ops = (await tester.runAsync(other.ownOps))!;
  await tester.runAsync(() async {
    await device.services.engine.applyAll(ops);
    await other.db.close();
  });
  await settle(tester);
  return id;
}

/// Задача «a», переименованная параллельно: здесь — в «mine», на другом
/// устройстве — позже [renames] раз, последний — в «theirs». Возвращает id.
Future<String> makeConflict(
  WidgetTester tester,
  TestDevice device, {
  int renames = 1,
}) => makeEntityConflict(
  tester,
  device,
  type: EntityTypes.task,
  create: (m) => m.create(EntityTypes.task, {
    TaskFields.content: 'a',
    TaskFields.projectId: inboxProjectId,
  }),
  mine: {TaskFields.content: 'mine'},
  theirs: [
    for (var i = renames; i > 0; i--)
      {TaskFields.content: i == 1 ? 'theirs' : 'theirs $i'},
  ],
);

/// Проект «Work», переименованный здесь в «Mine», на другом — в «Theirs».
Future<String> makeProjectConflict(WidgetTester tester, TestDevice device) =>
    makeEntityConflict(
      tester,
      device,
      type: EntityTypes.project,
      create: (m) => m.create(EntityTypes.project, {
        ProjectFields.name: 'Work',
        ProjectFields.color: 'blue',
        ProjectFields.orderKey: 'a0',
      }),
      mine: {ProjectFields.name: 'Mine'},
      theirs: [
        {ProjectFields.name: 'Theirs'},
      ],
    );

/// Проект «Work», описание которого правят оба устройства: имени и цвета в
/// споре нет — пометки быть не должно (решение 1А «Хода M4.13»).
Future<String> makeProjectDescriptionConflict(
  WidgetTester tester,
  TestDevice device,
) => makeEntityConflict(
  tester,
  device,
  type: EntityTypes.project,
  create: (m) => m.create(EntityTypes.project, {
    ProjectFields.name: 'Work',
    ProjectFields.color: 'blue',
    ProjectFields.orderKey: 'a0',
  }),
  mine: {ProjectFields.description: 'mine'},
  theirs: [
    {ProjectFields.description: 'theirs'},
  ],
);

/// Раздел «Sec» проекта «Work», переименованный параллельно. Возвращает id
/// проекта и раздела. Проект создаётся отдельным `runAsync`: вторая запись в
/// том же `runAsync` ждала бы проснувшиеся потоки экранов вечно (см.
/// [makeEntityConflict]).
Future<({String project, String section})> makeSectionConflict(
  WidgetTester tester,
  TestDevice device,
) async {
  final project = (await tester.runAsync(
    () => device.services.mutator.create(EntityTypes.project, {
      ProjectFields.name: 'Work',
      ProjectFields.color: 'blue',
      ProjectFields.orderKey: 'a0',
    }),
  ))!;
  await settle(tester);
  final section = await makeEntityConflict(
    tester,
    device,
    type: EntityTypes.section,
    create: (m) => m.create(EntityTypes.section, {
      SectionFields.name: 'Sec',
      SectionFields.projectId: project,
      SectionFields.orderKey: 'a0',
    }),
    mine: {SectionFields.name: 'Mine'},
    theirs: [
      {SectionFields.name: 'Theirs'},
    ],
  );
  return (project: project, section: section);
}

/// Метка «home», цвет которой параллельно изменён.
Future<String> makeLabelColorConflict(WidgetTester tester, TestDevice device) =>
    makeEntityConflict(
      tester,
      device,
      type: EntityTypes.label,
      create: (m) => m.create(EntityTypes.label, {
        LabelFields.name: 'home',
        LabelFields.color: 'blue',
        LabelFields.orderKey: 'a0',
      }),
      mine: {LabelFields.color: 'red'},
      theirs: [
        {LabelFields.color: 'green'},
      ],
    );
