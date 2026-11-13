import 'package:flutter_test/flutter_test.dart';
import 'package:planner/domain/models.dart';
import 'package:planner/domain/tree.dart';
import 'package:planner/domain/view_options.dart';
import 'package:planner/domain/view_order.dart';
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
  int priority = 4,
  String? date,
  String? time,
  String? completedAt,
}) => Task(
  id: id,
  content: id,
  description: '',
  projectId: project,
  sectionId: section,
  parentId: parent,
  orderKey: order,
  priority: priority,
  due: date == null ? null : Due(date: date, time: time),
  isCollapsed: collapsed,
  isCompleted: completed,
  completedAt: completedAt,
  labelIds: labels,
);

Label _label(String id, {String order = 'a'}) => Label(
  id: id,
  name: id,
  color: 'charcoal',
  orderKey: order,
  isFavorite: false,
);

SavedFilter _filter(String id, {String order = 'a', bool favorite = false}) =>
    SavedFilter(
      id: id,
      name: id,
      query: 'p1',
      description: '',
      color: 'charcoal',
      orderKey: order,
      isFavorite: favorite,
    );

List<String> _plain(Iterable<Task> tasks) => [for (final t in tasks) t.id];

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

  test('задачи метки с «Выполненными задачами» — выполненные после активных, '
      'позже выполненные выше; в архиве и под выполненным родителем — нет', () {
    final ws = Workspace(
      projects: [inbox, _project('p'), _project('old', archived: true)],
      sections: const [],
      labels: [_label('x')],
      tasks: [
        _task('open', labels: ['x']),
        _task(
          'done_early',
          completed: true,
          labels: ['x'],
        ).copyWith(completedAt: '2026-10-01T10:00:00.000Z'),
        _task(
          'done_late',
          completed: true,
          labels: ['x'],
        ).copyWith(completedAt: '2026-10-02T10:00:00.000Z'),
        _task(
          'archived_done',
          project: 'old',
          completed: true,
          labels: ['x'],
        ).copyWith(completedAt: '2026-10-03T10:00:00.000Z'),
        _task('parent', completed: true),
        _task('open_under_done', parent: 'parent', labels: ['x']),
      ],
    );
    expect(_plain(ws.labelTasks('x')), ['open']);
    expect(_plain(ws.labelTasks('x', showCompleted: true)), [
      'open',
      'done_late',
      'done_early',
    ]);
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

  test('subtaskProgress — выполнено и всего среди прямых подзадач', () {
    final ws = Workspace(
      projects: [inbox, _project('p')],
      sections: const [],
      labels: const [],
      tasks: [
        _task('a'),
        _task('a1', parent: 'a', completed: true),
        _task('a2', parent: 'a'),
        _task('a21', parent: 'a2'),
      ],
    );
    expect(ws.subtaskProgress('a'), (done: 1, total: 2));
    expect(ws.subtaskProgress('a21'), (done: 0, total: 0));
  });

  test('rootSectionOf — раздел корневой задачи, собственный раздел '
      'подзадачи не важен', () {
    final ws = Workspace(
      projects: [inbox, _project('p')],
      sections: [_section('s', 'p')],
      labels: const [],
      tasks: [
        _task('a', section: 's'),
        _task('a1', parent: 'a'),
        _task('b'),
      ],
    );
    expect(ws.rootSectionOf('a1')?.id, 's');
    expect(ws.rootSectionOf('b'), isNull);
  });

  test('удалённая метка — видна на задаче, выполненной до удаления (по HLC); '
      'на активной и выполненной после удаления скрыта; в списке меток и '
      'счётчиках её нет', () {
    final ws = Workspace(
      projects: [inbox, _project('p')],
      sections: const [],
      labels: [_label('x', order: 'b')],
      deletedLabels: [_label('gone', order: 'a')],
      tasks: [
        _task('open', labels: ['gone', 'x']),
        _task('done', labels: ['x', 'gone', 'unknown'], completed: true),
        _task('late', labels: ['gone'], completed: true),
        _task('no_version', labels: ['gone'], completed: true),
      ],
      completionVersions: {
        'done': '000000000000000100:0000:a',
        'late': '000000000000000300:0000:b',
      },
      labelDeletionVersions: {'gone': '000000000000000200:0000:c'},
    );
    expect(ws.task('open')!.labelIds, ['x']);
    expect(ws.task('done')!.labelIds, ['gone', 'x']);
    expect(ws.task('late')!.labelIds, isEmpty);
    expect(ws.task('no_version')!.labelIds, isEmpty);
    expect(ws.label('gone'), isNull);
    expect(ws.deletedLabel('gone')?.name, 'gone');
    expect(ws.deletedLabel('x'), isNull);
    final done = ws.task('done')!;
    expect(ws.taskLabel(done, 'gone')?.name, 'gone');
    expect(ws.taskLabel(done, 'x')?.name, 'x');
    expect([for (final l in ws.labels) l.id], ['x']);
    expect(ws.labelTaskCount('gone'), 0);
  });

  test('имя метки на выполненной задаче — из снимка на момент завершения; '
      'метки без снимка и пустое имя в снимке — текущее имя', () {
    final ws = Workspace(
      projects: [inbox, _project('p')],
      sections: const [],
      labels: [_label('x'), _label('y'), _label('z')],
      tasks: [
        _task(
          'done',
          labels: ['x', 'y', 'z'],
          completed: true,
        ).copyWith(completedLabelNames: {'x': 'старое', 'z': ''}),
      ],
    );
    final done = ws.task('done')!;
    expect(
      [for (final id in done.labelIds) ws.taskLabel(done, id)?.name],
      ['старое', 'y', 'z'],
    );
    expect(ws.taskLabel(done, 'x')?.color, 'charcoal');
    expect(ws.label('x')?.name, 'x', reason: 'сама метка не меняется');
    expect(ws.taskLabel(done, 'unknown'), isNull);
  });

  test('projectView: архивные разделы — только при showCompleted и после '
      'активных', () {
    final ws = Workspace(
      projects: [inbox, _project('p')],
      sections: [_section('old', 'p', archived: true), _section('week', 'p')],
      labels: const [],
      tasks: [_task('t', section: 'old', completed: true)],
    );
    List<String> sections({required bool completed}) => [
      for (final s in ws.projectView('p', showCompleted: completed).sections)
        s.section.id,
    ];
    expect(sections(completed: false), ['week']);
    expect(sections(completed: true), ['week', 'old']);
    expect(
      ws
          .projectView('p', showCompleted: true)
          .sections
          .last
          .tasks
          .single
          .value
          .id,
      't',
    );
  });

  test('фильтры — по ключу порядка, при равенстве по id; избранные — в том '
      'же порядке', () {
    final ws = Workspace(
      projects: [inbox],
      sections: const [],
      labels: const [],
      tasks: const [],
      filters: [
        _filter('f3', order: 'b', favorite: true),
        _filter('f2', order: 'a'),
        _filter('f1', order: 'a', favorite: true),
      ],
    );
    expect([for (final f in ws.filters) f.id], ['f1', 'f2', 'f3']);
    expect([for (final f in ws.favoriteFilters) f.id], ['f1', 'f3']);
    expect(ws.filter('f2')!.query, 'p1');
    expect(ws.filter('нет'), isNull);
  });

  test('labelTaskCount — столько же задач, сколько в labelTasks', () {
    final ws = Workspace(
      projects: [inbox, _project('p')],
      sections: const [],
      labels: [_label('l')],
      tasks: [
        _task('a', labels: ['l']),
        _task('b', labels: ['l'], completed: true),
        _task('c', parent: 'a', labels: ['l']),
      ],
    );
    expect(ws.labelTaskCount('l'), ws.labelTasks('l').length);
    expect(ws.labelTaskCount('l'), 2);
    expect(ws.labelTaskCount('нет'), 0);
  });

  group('«Сегодня», «Просрочено», «Предстоящее» (M4.4)', () {
    const today = '2026-11-03';
    Workspace ws() => Workspace(
      projects: [inbox, _project('p'), _project('old', archived: true)],
      sections: const [],
      labels: const [],
      tasks: [
        _task('nine', date: today, time: '09:00'),
        _task('allday', date: today, priority: 1),
        _task('late', date: '2026-11-01'),
        _task('later', date: '2026-10-20', priority: 1),
        _task('tomorrow', date: '2026-11-04'),
        _task('far', date: '2028-11-02'),
        _task('beyond', date: '2028-11-03'),
        _task('nodate'),
        _task('done', date: today, completed: true),
        _task('archived', project: 'old', date: today),
        _task('parent', date: '2026-11-10'),
        _task('child', parent: 'parent', date: today),
      ],
    );

    test('просрочено — по дате, а не по времени: «сегодня 9:00» не '
        'просрочено (О-25); умный порядок', () {
      expect(_plain(ws().overdueTasks(today)), ['later', 'late']);
    });

    test(
      'сегодня — только активные со сроком на сегодня; подзадача своей '
      'строкой, хоть родитель не на сегодня; без времени — перед временем',
      () {
        expect(_plain(ws().todayTasks(today)), ['allday', 'child', 'nine']);
        expect(ws().todayCount(today), 5);
      },
    );

    test('предстоящее — дни от сегодня на два года вперёд, по порядку', () {
      final days = ws().upcomingDays(today);
      expect(days.keys, [today, '2026-11-04', '2026-11-10', '2028-11-02']);
      expect(_plain(days[today]!), ['allday', 'child', 'nine']);
    });
  });

  group('«Выполненные задачи» в «Сегодня» и «Предстоящем» (M4.6)', () {
    const today = '2026-11-04';
    Workspace ws() => Workspace(
      projects: [inbox, _project('p'), _project('old', archived: true)],
      sections: const [],
      labels: const [],
      tasks: [
        _task('open', date: today),
        _task(
          'early',
          date: '2026-11-10',
          completed: true,
          completedAt: '2026-11-04T07:00:00.000Z',
        ),
        _task(
          'late',
          date: today,
          completed: true,
          completedAt: '2026-11-04T18:00:00.000Z',
        ),
        _task(
          'yesterday',
          date: today,
          completed: true,
          completedAt: '2026-11-03T18:00:00.000Z',
        ),
        _task(
          'archived',
          project: 'old',
          completed: true,
          completedAt: '2026-11-04T09:00:00.000Z',
        ),
      ],
    );
    String utcDay(String utc) => utc.substring(0, 10);

    test('сегодня — выполненные в этот день по времени выполнения, после '
        'активных, позже выполненные выше; без дня выполнения — только '
        'активные', () {
      expect(_plain(ws().todayTasks(today, completedDay: utcDay)), [
        'open',
        'late',
        'early',
      ]);
      expect(_plain(ws().todayTasks(today)), ['open']);
    });

    test('предстоящее — выполненные внизу дня своего срока', () {
      final days = ws().upcomingDays(today, showCompleted: true);
      expect(_plain(days[today]!), ['open', 'late', 'yesterday']);
      expect(_plain(days['2026-11-10']!), ['early']);
      expect(ws().upcomingDays(today).keys, [today]);
    });
  });

  test(
    'порядок метки по help: приоритет → дата → порядок проектов и задач',
    () {
      final ws = Workspace(
        projects: [
          inbox,
          _project('p', order: 'b'),
          _project('q', order: 'a'),
        ],
        sections: [_section('s', 'q')],
        labels: [_label('x')],
        tasks: [
          _task('q_late', project: 'q', order: 'b', labels: ['x']),
          _task('q_sec', project: 'q', section: 's', labels: ['x']),
          _task('q_first', project: 'q', order: 'a', labels: ['x']),
          _task('p_dated', labels: ['x'], date: '2026-11-04'),
          _task('p_p1', labels: ['x'], priority: 1),
          _task('in_inbox', project: null, labels: ['x']),
        ],
      );
      expect(_plain(ws.labelTasks('x')), [
        'p_p1',
        'p_dated',
        'in_inbox',
        'q_first',
        'q_late',
        'q_sec',
      ]);
    },
  );

  test('список проекта с сортировкой — внутри раздела и среди соседей '
      'родителя; группировка — подзадача в группе своих значений', () {
    final ws = Workspace(
      projects: [inbox, _project('p')],
      sections: [_section('s', 'p')],
      labels: const [],
      tasks: [
        _task('a', order: 'a', priority: 3),
        _task('b', order: 'b', priority: 1),
        // Ключ «a2» больше ключа «b»: ручной порядок в группе — по дереву.
        _task('a2', parent: 'a', order: 'c', priority: 1),
        _task('a1', parent: 'a', order: 'a', priority: 2),
        _task('s1', section: 's', order: 'a', priority: 4),
        _task('s2', section: 's', order: 'b', priority: 2),
      ],
    );
    final order = ws.taskOrder(DefaultOrder.manual, sorting: Sorting.priority);
    final view = ws.projectView('p', order: order);
    expect(_ids(view.unsectioned), ['b', 'a', 'a2', 'a1']);
    expect(_ids(view.sections.single.tasks), ['s2', 's1']);

    final groups = ws.groupsOf(
      ws.projectTasks('p'),
      Grouping.priority,
      order: order,
      today: '2026-11-03',
    );
    // «Вручную» в группе — тоже по дереву, как порядок по умолчанию.
    final manual = ws.groupsOf(
      ws.projectTasks('p'),
      Grouping.priority,
      order: ws.taskOrder(DefaultOrder.manual, sorting: Sorting.manual),
      today: '2026-11-03',
    );
    expect(_plain(manual.first.tasks), ['a2', 'b']);
    expect(
      [for (final g in groups) (g.key, _plain(g.tasks).join(','))],
      [
        // Ручной порядок в группе — по дереву: подзадача «a» раньше «b».
        (const TaskGroupKey.priority(1), 'a2,b'),
        (const TaskGroupKey.priority(2), 'a1,s2'),
        (const TaskGroupKey.priority(3), 'a'),
        (const TaskGroupKey.priority(4), 's1'),
      ],
    );
  });

  test('архивный проект — ручной порядок в группе по дереву; день добавления '
      'передаётся явно', () {
    final ws = Workspace(
      projects: [inbox, _project('old', archived: true)],
      sections: const [],
      labels: const [],
      tasks: [
        for (final t in [
          _task('a', project: 'old', order: 'a'),
          _task('b', project: 'old', order: 'b'),
          _task('a1', project: 'old', parent: 'a', order: 'c'),
        ])
          t.copyWith(addedAt: '2026-11-01T23:30:00.000Z'),
      ],
    );
    final groups = ws.groupsOf(
      ws.projectTasks('old'),
      Grouping.addedDate,
      order: ws.taskOrder(DefaultOrder.manual),
      today: '2026-11-03',
      // День по часам приложения: такого не даст ни один пояс устройства
      // (из 23:30 UTC 1 ноября выходит 1 или 2 ноября).
      localDay: (_) => '2026-10-30',
    );
    expect(
      [for (final g in groups) (g.key, _plain(g.tasks).join(','))],
      [(const TaskGroupKey.day('2026-10-30'), 'a,a1,b')],
    );
  });
}
