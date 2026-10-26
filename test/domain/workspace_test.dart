import 'package:flutter_test/flutter_test.dart';
import 'package:planner/domain/models.dart';
import 'package:planner/domain/tree.dart';
import 'package:planner/domain/workspace.dart';

Project _project(
  String id, {
  String? parent,
  String order = 'a',
  bool inbox = false,
  bool archived = false,
}) => Project(
  id: id,
  name: id,
  color: 'charcoal',
  parentId: parent,
  orderKey: order,
  isFavorite: false,
  isArchived: archived,
  isInbox: inbox,
  viewStyle: 'list',
  isCollapsed: false,
);

Section _section(String id, String project, {bool archived = false}) => Section(
  id: id,
  name: id,
  projectId: project,
  orderKey: 'a',
  isCollapsed: false,
  isArchived: archived,
);

Task _task(
  String id, {
  String? project = 'p',
  String? section,
  String? parent,
  String order = 'a',
  bool completed = false,
  bool collapsed = false,
  List<String> labels = const [],
}) => Task(
  id: id,
  content: id,
  description: '',
  projectId: project,
  sectionId: section,
  parentId: parent,
  orderKey: order,
  priority: 4,
  isCollapsed: collapsed,
  isCompleted: completed,
  labelIds: labels,
);

Label _label(String id, {String order = 'a'}) => Label(
  id: id,
  name: id,
  color: 'charcoal',
  orderKey: order,
  isFavorite: false,
);

List<String> _ids(Iterable<TreeItem<Task>> items) => [
  for (final i in items) i.value.id,
];

void main() {
  final inbox = _project('inbox', inbox: true);

  test('удалённый проект скрывает свои задачи и подпроекты; отмена удаления '
      'возвращает всё', () {
    final projects = [inbox, _project('p'), _project('sub', parent: 'p')];
    final tasks = [_task('t1'), _task('t2', project: 'sub')];

    final deleted = Workspace(
      projects: projects.where((p) => p.id != 'p'),
      sections: const [],
      labels: const [],
      tasks: tasks,
      deletedProjectIds: {'p'},
    );
    expect(deleted.project('sub'), isNull);
    expect(deleted.task('t1'), isNull);
    expect(deleted.task('t2'), isNull);

    final restored = Workspace(
      projects: projects,
      sections: const [],
      labels: const [],
      tasks: tasks,
    );
    expect(restored.task('t1'), isNotNull);
    expect(restored.task('t2'), isNotNull);
  });

  test(
    'удалённая задача скрывает подзадачи; удалённый раздел — свои задачи',
    () {
      final ws = Workspace(
        projects: [inbox, _project('p')],
        sections: [_section('s1', 'p')],
        labels: const [],
        tasks: [
          _task('child', parent: 'gone'),
          _task('grandchild', parent: 'child'),
          _task('in_deleted_section', section: 's2'),
          _task('in_section', section: 's1'),
        ],
        deletedTaskIds: {'gone'},
        deletedSectionIds: {'s2'},
      );
      expect(ws.task('child'), isNull);
      expect(ws.task('grandchild'), isNull);
      expect(ws.task('in_deleted_section'), isNull);
      expect(ws.task('in_section'), isNotNull);
    },
  );

  test('проект, раздел или родитель ещё не пришли — задача видна', () {
    final ws = Workspace(
      projects: [inbox, _project('p')],
      sections: const [],
      labels: const [],
      tasks: [
        _task('orphan', parent: 'not_yet'),
        _task('unknown_section', section: 'not_yet'),
      ],
    );
    final view = ws.projectView('p');
    expect(_ids(view.unsectioned), ['orphan', 'unknown_section']);
  });

  test('подзадача видна под родителем, даже если её проект после '
      'параллельного переноса другой', () {
    final ws = Workspace(
      projects: [inbox, _project('p'), _project('q')],
      sections: const [],
      labels: const [],
      tasks: [
        _task('parent'),
        _task('child', project: 'q', parent: 'parent'),
      ],
    );
    expect(_ids(ws.projectView('p').unsectioned), ['parent', 'child']);
    expect(ws.projectView('q').unsectioned, isEmpty);
    expect(ws.rootProjectOf('child'), 'p');
  });

  test('цикл подзадач — видны обе, одинаково при любом порядке данных', () {
    final a = _task('a', parent: 'b');
    final b = _task('b', parent: 'a');
    List<String> view(List<Task> tasks) => _ids(
      Workspace(
        projects: [inbox, _project('p')],
        sections: const [],
        labels: const [],
        tasks: tasks,
      ).projectView('p').unsectioned,
    );
    expect(view([a, b]), ['a', 'b']);
    expect(view([b, a]), ['a', 'b']);
  });

  test('список проекта: без раздела, затем разделы; порядок по ключу, при '
      'равенстве по id; завершённые — только по запросу и после активных', () {
    final ws = Workspace(
      projects: [inbox, _project('p')],
      sections: [_section('s1', 'p'), _section('old', 'p', archived: true)],
      labels: const [],
      tasks: [
        _task('t2', order: 'b'),
        _task('t1', order: 'a'),
        _task('t0', order: 'b'),
        _task('done', order: '0V', completed: true),
        _task('s_task', section: 's1'),
        _task('archived_task', section: 'old'),
      ],
    );
    final view = ws.projectView('p');
    expect(_ids(view.unsectioned), ['t1', 't0', 't2']);
    expect([for (final s in view.sections) s.section.id], ['s1']);
    expect(_ids(view.sections.single.tasks), ['s_task']);
    expect(_ids(ws.projectView('p', showCompleted: true).unsectioned), [
      't1',
      't0',
      't2',
      'done',
    ]);
    expect(ws.activeTaskCount('p'), 4);
  });

  test('свёрнутая задача скрывает подзадачи в списке, но считает их', () {
    final ws = Workspace(
      projects: [inbox, _project('p')],
      sections: const [],
      labels: const [],
      tasks: [
        _task('parent', collapsed: true),
        _task('kid', parent: 'parent'),
      ],
    );
    final items = ws.projectView('p').unsectioned;
    expect(_ids(items), ['parent']);
    expect(items.single.childCount, 1);
    expect(ws.subtasksOf('parent').single.value.id, 'kid');
  });

  test(
    'архивный проект: подпроекты в архиве, задачи не считаются активными',
    () {
      final ws = Workspace(
        projects: [
          inbox,
          _project('p', archived: true),
          _project('sub', parent: 'p'),
        ],
        sections: const [],
        labels: [_label('l')],
        tasks: [
          _task('t', project: 'sub', labels: ['l']),
        ],
      );
      expect(ws.projectTree(), isEmpty);
      expect([for (final p in ws.archivedProjects) p.id], ['p']);
      expect(ws.isProjectArchived('sub'), isTrue);
      expect(ws.activeTaskCount('sub'), 0);
      expect(ws.labelTasks('l'), isEmpty);
    },
  );

  test('метки задачи: только живые, по порядку меток; задачи метки — по '
      'порядку проектов', () {
    final ws = Workspace(
      projects: [
        inbox,
        _project('p', order: 'b'),
        _project('q', order: 'a'),
      ],
      sections: const [],
      labels: [
        _label('x', order: 'b'),
        _label('y', order: 'a'),
      ],
      tasks: [
        _task('in_p', labels: ['x', 'deleted_label', 'y']),
        _task('in_q', project: 'q', labels: ['x']),
        _task('in_inbox', project: null, labels: ['x']),
      ],
    );
    expect(ws.task('in_p')!.labelIds, ['y', 'x']);
    expect(
      [for (final t in ws.labelTasks('x')) t.id],
      ['in_inbox', 'in_q', 'in_p'],
    );
  });

  test('уровни и высоты деревьев', () {
    final ws = Workspace(
      projects: [
        inbox,
        _project('p'),
        _project('p2', parent: 'p'),
        _project('p3', parent: 'p2'),
      ],
      sections: const [],
      labels: const [],
      tasks: [
        _task('a'),
        _task('b', parent: 'a'),
        _task('c', parent: 'b'),
      ],
    );
    expect(ws.projectDepth('p3'), 3);
    expect(ws.projectHeight('p'), 3);
    expect(ws.taskDepth('c'), 3);
    expect(ws.taskHeight('a'), 3);
    expect(ws.taskSubtree('a'), ['a', 'b', 'c']);
    expect(
      [for (final i in ws.projectTree()) (i.value.id, i.depth)],
      [('p', 0), ('p2', 1), ('p3', 2)],
    );
  });

  test('корневая задача в живом разделе — в проекте раздела, даже если её '
      'project_id другой (раздел перенесли на другом устройстве)', () {
    final ws = Workspace(
      projects: [inbox, _project('from'), _project('to')],
      sections: [_section('s', 'to')],
      labels: const [],
      tasks: [_task('t', project: 'from', section: 's')],
    );
    expect(_ids(ws.projectView('to').sections.single.tasks), ['t']);
    expect(ws.projectView('from').unsectioned, isEmpty);
    expect(ws.rootProjectOf('t'), 'to');
    expect((ws.activeTaskCount('to'), ws.activeTaskCount('from')), (1, 0));
  });

  test('корневая задача в разделе удалённого проекта скрыта, хоть её '
      'project_id и жив', () {
    final ws = Workspace(
      projects: [inbox, _project('alive')],
      sections: [_section('s', 'gone')],
      labels: const [],
      tasks: [_task('t', project: 'alive', section: 's')],
      deletedProjectIds: {'gone'},
    );
    expect(ws.task('t'), isNull);
  });

  test('activeTaskCountIn — активные задачи раздела с подзадачами', () {
    final ws = Workspace(
      projects: [inbox, _project('p')],
      sections: [_section('s', 'p')],
      labels: const [],
      tasks: [
        _task('a', section: 's'),
        _task('a1', parent: 'a'),
        _task('done', section: 's', completed: true),
        _task('free'),
      ],
    );
    expect(ws.activeTaskCountIn('p', 's'), 2);
    expect(ws.activeTaskCountIn('p', null), 1);
  });
}
