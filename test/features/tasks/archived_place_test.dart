import 'package:flutter_test/flutter_test.dart';
import 'package:planner/data/projection/entity_fields.dart';
import 'package:planner/domain/rules.dart';

import '../../sync/support/devices.dart';
import '../support/app_commands.dart';

// Перенос в проект или раздел, который на другом устройстве убрали в архив,
// пока окно было открыто (находка ревью M4.13): отказ «нет такого места» до
// записи — иначе задача, раздел или проект ушли бы туда невидимыми.
Matcher _rejected(RejectReason reason) =>
    throwsA(isA<CommandRejected>().having((e) => e.reason, 'reason', reason));

void main() {
  late TestDevice device;
  late AppCommands app;

  setUp(() async {
    device = await TestDevice.start();
    app = AppCommands(device);
  });

  /// [action] отклонено как «нет такого места», и ни одной новой op.
  Future<void> rejectsWithoutOps(Future<Object?> Function() action) async {
    final before = (await device.ownOps()).length;
    await expectLater(action(), _rejected(RejectReason.notFound));
    expect((await device.ownOps()).length, before);
  }

  test('задача: в архивный проект, его раздел, под его задачу — отказ; '
      'перенос, массовый перенос и добавление', () async {
    final archived = await app.projects.add(name: 'Архив');
    final section = await app.sections.add(archived, name: 'Раздел');
    final parent = await app.tasks.add(
      content: 'Родитель',
      projectId: archived,
    );
    await app.projects.archive(archived);
    final task = await app.tasks.add(content: 'Задача');

    await rejectsWithoutOps(() => app.tasks.move(task, projectId: archived));
    await rejectsWithoutOps(
      () => app.tasks.move(task, projectId: archived, sectionId: section),
    );
    await rejectsWithoutOps(() => app.tasks.move(task, parentId: parent));
    await rejectsWithoutOps(() => app.bulk.move([task], archived, null));
    await rejectsWithoutOps(
      () => app.tasks.add(content: 'Новая', projectId: archived),
    );
    expect((await app.read()).rootProjectOf(task), inboxProjectId);
  });

  test('задача: в архивный раздел активного проекта и под задачу этого '
      'раздела — отказ: перенос, массовый перенос, новая подзадача', () async {
    final project = await app.projects.add(name: 'Работа');
    final section = await app.sections.add(project, name: 'Раздел');
    final parent = await app.tasks.add(
      content: 'Родитель',
      projectId: project,
      sectionId: section,
    );
    await app.sections.archive(section);
    final task = await app.tasks.add(content: 'Задача');

    await rejectsWithoutOps(
      () => app.tasks.move(task, projectId: project, sectionId: section),
    );
    await rejectsWithoutOps(() => app.tasks.move(task, parentId: parent));
    await rejectsWithoutOps(
      () => app.bulk.moveMany([task], projectId: project, sectionId: section),
    );
    // Окно задачи было открыто, пока раздел убирали в архив, — подзадача
    // ушла бы в архивный раздел невидимой.
    await rejectsWithoutOps(
      () => app.tasks.add(content: 'Подзадача', parentId: parent),
    );
  });

  test('проект под архивный проект — отказ, под активный — можно', () async {
    final archived = await app.projects.add(name: 'Архив');
    final active = await app.projects.add(name: 'Работа');
    final child = await app.projects.add(name: 'Подпроект');
    await app.projects.archive(archived);

    await rejectsWithoutOps(() => app.projects.move(child, parentId: archived));
    await app.projects.move(child, parentId: active);
    expect((await app.read()).projectParent(child), active);
  });

  test('раздел в архивный проект — отказ, в активный — можно', () async {
    final from = await app.projects.add(name: 'Работа');
    final archived = await app.projects.add(name: 'Архив');
    final active = await app.projects.add(name: 'Дом');
    final section = await app.sections.add(from, name: 'Раздел');
    await app.projects.archive(archived);

    await rejectsWithoutOps(
      () => app.sections.moveToProject(section, archived),
    );
    await app.sections.moveToProject(section, active);
    expect((await app.read()).section(section)!.projectId, active);
  });
}
