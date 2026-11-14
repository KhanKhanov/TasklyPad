import 'package:flutter_test/flutter_test.dart';
import 'package:planner/data/projection/entity_fields.dart';
import 'package:planner/domain/view_options.dart';

import '../../sync/support/devices.dart';
import '../support/app_commands.dart';

void main() {
  late TestDevice dev;
  late AppCommands app;
  late String project;
  late ViewOptions view;

  setUp(() async {
    dev = await TestDevice.start(seed: 1);
    app = AppCommands(dev);
    project = await app.projects.add(name: 'Работа');
    view = ViewOptions(viewType: ViewType.project, objectId: project);
  });

  Future<Map<String, Object?>?> stored() => dev.entity(
    EntityTypes.viewOptions,
    viewOptionsId(ViewType.project.apiName, project),
  );

  Future<ViewOptions> load() =>
      app.viewsRepo.load(ViewType.project, objectId: project);

  test('первая правка — вид, объект и изменённое поле; остальных полей в '
      'журнале нет', () async {
    await app.views.save(view, view.copyWith(grouping: Grouping.priority));

    expect(await stored(), {
      ViewOptionsFields.viewType: 'project',
      ViewOptionsFields.objectId: project,
      ViewOptionsFields.groupedBy: 'priority',
    });
    expect(await load(), view.copyWith(grouping: Grouping.priority));
  });

  test('правка пишет только поля, изменённые от того, что видел '
      'пользователь; без изменений — ни одной op', () async {
    final grouped = view.copyWith(grouping: Grouping.label);
    await app.views.save(view, grouped);
    final before = (await dev.ownOps()).length;

    await app.views.save(grouped, grouped);
    expect((await dev.ownOps()).length, before);

    await app.views.save(grouped, grouped.copyWith(showCompletedTasks: true));
    final ops = (await dev.ownOps()).skip(before).toList();
    expect(
      [for (final op in ops) op.field],
      [ViewOptionsFields.showCompletedTasks],
    );
  });

  test('фильтр «Отображения» пишется и снимается своим полем '
      '(применение и «Сбросить всё» — M5.3)', () async {
    final filtered = view.copyWith(filteredBy: 'p1');
    await app.views.save(view, filtered);
    expect(await load(), filtered);
    expect((await stored())![ViewOptionsFields.filteredBy], 'p1');

    await app.views.save(filtered, view);
    expect(await load(), view);
  });

  test('«Вручную» и порядок вида — направление «по возрастанию»: меню '
      'направления скрыто', () async {
    final desc = view.copyWith(
      sorting: Sorting.dueDate,
      sortOrder: SortOrder.desc,
    );
    await app.views.save(view, desc);
    expect(await load(), desc);

    await app.views.save(desc, desc.copyWith(sorting: Sorting.byDefault));
    expect(await load(), view);
  });

  test('сортировка от более новой версии с направлением — правка другого '
      'поля направление не трогает', () async {
    final id = viewOptionsId(ViewType.project.apiName, project);
    await dev.services.mutator.update(EntityTypes.viewOptions, id, {
      ViewOptionsFields.viewType: 'project',
      ViewOptionsFields.objectId: project,
      ViewOptionsFields.sortedBy: 'assignee',
      ViewOptionsFields.sortOrder: 'desc',
    });
    final seen = await load();
    expect((seen.sorting, seen.sortOrder), (Sorting.byDefault, SortOrder.desc));

    await app.views.save(seen, seen.copyWith(showCompletedTasks: true));
    final fields = await stored();
    expect(fields![ViewOptionsFields.sortedBy], 'assignee');
    expect(fields[ViewOptionsFields.sortOrder], 'desc');
  });

  test('все виды одной подпиской: вид незнакомого типа пропускается', () async {
    await app.views.save(view, view.copyWith(grouping: Grouping.label));
    await dev.services.mutator.update(
      EntityTypes.viewOptions,
      viewOptionsId('workspace_filter', 'w1'),
      {
        ViewOptionsFields.viewType: 'workspace_filter',
        ViewOptionsFields.objectId: 'w1',
        ViewOptionsFields.groupedBy: 'priority',
      },
    );
    expect(await app.viewsRepo.watchAll().first, {
      (ViewType.project, project): view.copyWith(grouping: Grouping.label),
    });
  });

  test('«Сбросить всё» снимает сортировку, направление и группировку, '
      '«Выполненные задачи» остаются', () async {
    final changed = view.copyWith(
      grouping: Grouping.deadline,
      sorting: Sorting.priority,
      sortOrder: SortOrder.desc,
      showCompletedTasks: true,
    );
    await app.views.save(view, changed);
    expect(changed.applied, 2);

    await app.views.resetAll(changed);
    expect(await load(), view.copyWith(showCompletedTasks: true));
    expect((await load()).applied, 0);
  });

  test('фильтр «Отображения» — в «Display: N» по виду фильтра, «Сбросить всё» '
      'снимает и его (решение 5А plans/m5)', () async {
    final changed = view.copyWith(
      sorting: Sorting.priority,
      filteredBy: 'p1 & %дом',
    );
    await app.views.save(view, changed);
    expect(changed.applied, 3);

    await app.views.resetAll(changed);
    expect((await load()).filteredBy, isNull);
    expect((await load()).applied, 0);
  });

  test('фильтр «Отображения» не запрещает перетаскивание (решение 4А)', () {
    expect(view.copyWith(filteredBy: 'p1').allowsDrag, isTrue);
  });

  test('у «Предстоящего» фильтра нет: пришедший импортом не считается', () {
    const upcoming = ViewOptions(viewType: ViewType.upcoming, filteredBy: 'p1');
    expect(upcoming.filterApplies, isFalse);
    expect(upcoming.applied, 0);
  });

  test('настройки другого вида — ArgumentError, ничего не записано', () async {
    final other = ViewOptions(viewType: ViewType.label, objectId: 'l1');
    await expectLater(
      app.views.save(view, other.copyWith(showCompletedTasks: true)),
      throwsArgumentError,
    );
    expect(await stored(), isNull);
  });

  test('дубликат проекта копирует «Отображение»; у проекта без настроек '
      'копия без сущности вида', () async {
    final plain = await app.projects.duplicate(project, name: 'Копия');
    expect(
      await dev.entity(
        EntityTypes.viewOptions,
        viewOptionsId(ViewType.project.apiName, plain),
      ),
      isNull,
    );

    // С фильтром «Отображения» — он копируется вместе с остальным (6А).
    final grouped = view.copyWith(
      grouping: Grouping.priority,
      filteredBy: 'p1',
    );
    await app.views.save(view, grouped);
    final copy = await app.projects.duplicate(project, name: 'Копия 2');
    expect(
      await app.viewsRepo.load(ViewType.project, objectId: copy),
      grouped.copyWith(objectId: copy),
    );
  });

  test('дубликат фильтра копирует его фильтр «Отображения» (6А)', () async {
    final filter = await app.filters.add(name: 'Срочное', query: 'today');
    final own = ViewOptions(viewType: ViewType.filter, objectId: filter);
    await app.views.save(own, own.copyWith(filteredBy: 'p2'));
    final copy = await app.filters.duplicate(filter, name: 'Копия');
    expect(
      (await app.viewsRepo.load(ViewType.filter, objectId: copy)).filteredBy,
      'p2',
    );
  });
}
