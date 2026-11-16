import 'package:flutter_test/flutter_test.dart';
import 'package:planner/domain/models.dart';
import 'package:planner/domain/search.dart';
import 'package:planner/domain/workspace.dart';

// Поиск по снимку (help «Introduction to search»; решения 6А, 5А plans/m5):
// части слов, регистр и «ё», `*`, описания отдельной вкладкой, архив не
// ищется, «Лучшие совпадения», выполненные — целыми словами.

Project _project(
  String id,
  String name, {
  String? parent,
  bool inbox = false,
  bool archived = false,
  String order = 'a',
}) => Project(
  id: id,
  name: name,
  color: 'charcoal',
  parentId: parent,
  orderKey: order,
  isFavorite: false,
  isArchived: archived,
  isInbox: inbox,
  viewStyle: 'list',
  isCollapsed: false,
);

Task _task(
  String id,
  String content, {
  String project = 'work',
  String description = '',
  bool completed = false,
  String? completedAt,
  List<String> labels = const [],
  String order = 'a',
}) => Task(
  id: id,
  content: content,
  description: description,
  projectId: project,
  orderKey: order,
  priority: 4,
  isCollapsed: false,
  isCompleted: completed,
  completedAt: completedAt,
  labelIds: labels,
);

Workspace _ws({List<Task> tasks = const []}) => Workspace(
  projects: [
    _project('inbox', 'Inbox', inbox: true),
    _project('work', 'Работа', order: 'b'),
    _project('old', 'Отчёты старые', archived: true, order: 'c'),
    _project('oldchild', 'Отчёты вложенные', parent: 'old'),
  ],
  sections: const [
    Section(
      id: 's1',
      name: 'Отчёты',
      projectId: 'work',
      orderKey: 'a',
      isCollapsed: false,
      isArchived: false,
    ),
    Section(
      id: 's2',
      name: 'Отчёты архив',
      projectId: 'old',
      orderKey: 'a',
      isCollapsed: false,
      isArchived: false,
    ),
  ],
  labels: const [
    Label(
      id: 'l1',
      name: 'отчёт',
      color: 'red',
      orderKey: 'a',
      isFavorite: false,
    ),
  ],
  filters: const [
    SavedFilter(
      id: 'f1',
      name: 'Отчёты недели',
      query: 'p1',
      description: '',
      color: 'red',
      orderKey: 'a',
      isFavorite: false,
    ),
  ],
  tasks: tasks,
);

List<String> _names(List<SearchHit> hits) => [
  for (final h in hits)
    switch (h) {
      TaskHit(:final task) => 'task:${task.content}',
      ProjectHit(:final project) => 'project:${project.name}',
      SectionHit(:final section) => 'section:${section.name}',
      LabelHit(:final label) => 'label:${label.name}',
      FilterHit(:final filter) => 'filter:${filter.name}',
    },
];

void main() {
  SearchResults search(Workspace ws, String text) =>
      SearchIndex(ws).search(SearchQuery.parse(text));

  test('часть слова в середине названия; регистр и «ё» не важны', () {
    final ws = _ws(tasks: [_task('t', 'Сдать ОТЧЁТ')]);
    for (final text in ['тче', 'отчет', 'ОТЧЁТ', 'сдать']) {
      expect(_names(search(ws, text).of(SearchTab.tasks)), [
        'task:Сдать ОТЧЁТ',
      ], reason: text);
    }
  });

  test('несколько слов — все в одном названии, в любом порядке', () {
    final ws = _ws(
      tasks: [_task('a', 'купить молоко'), _task('b', 'купить хлеб')],
    );
    expect(_names(search(ws, 'молоко купить').of(SearchTab.tasks)), [
      'task:купить молоко',
    ]);
  });

  test('`*` — любые буквы внутри слова, но не через пробел', () {
    final ws = _ws(tasks: [_task('a', 'отчёт'), _task('b', 'отдых в чате')]);
    expect(_names(search(ws, 'от*т').of(SearchTab.tasks)), ['task:отчёт']);
  });

  test('ищется видимый текст markdown, а не символы разметки', () {
    final ws = _ws(tasks: [_task('a', '[Квартальный план](https://x.ru)')]);
    expect(search(ws, 'план').of(SearchTab.tasks), hasLength(1));
    expect(search(ws, 'https').of(SearchTab.tasks), isEmpty);
  });

  test('совпадение в описании — только во вкладке «Описания задач»', () {
    final ws = _ws(tasks: [_task('a', 'Звонок', description: 'про бюджет')]);
    final results = search(ws, 'бюджет');
    expect(results.of(SearchTab.tasks), isEmpty);
    expect(results.of(SearchTab.top), isEmpty);
    expect(_names(results.of(SearchTab.descriptions)), ['task:Звонок']);
  });

  test('архивный проект, его подпроект, разделы и задачи не ищутся', () {
    final ws = _ws(tasks: [_task('a', 'Отчёт в архиве', project: 'old')]);
    final results = search(ws, 'отчёт');
    expect(_names(results.of(SearchTab.projects)), isEmpty);
    expect(_names(results.of(SearchTab.sections)), ['section:Отчёты']);
    expect(results.of(SearchTab.tasks), isEmpty);
  });

  test('выполненные задачи среди активных не ищутся', () {
    final ws = _ws(tasks: [_task('a', 'Отчёт', completed: true)]);
    expect(search(ws, 'отчёт').of(SearchTab.tasks), isEmpty);
  });

  test('«Входящие» находятся по своему имени, «Inbox» и «Входящие»', () {
    final ws = _ws();
    for (final text in ['inbox', 'входящ']) {
      expect(_names(search(ws, text).of(SearchTab.projects)), [
        'project:Inbox',
      ], reason: text);
    }
  });

  test('метки и фильтры — по имени', () {
    final results = search(_ws(), 'отчёт');
    expect(_names(results.of(SearchTab.labels)), ['label:отчёт']);
    expect(_names(results.of(SearchTab.filters)), ['filter:Отчёты недели']);
  });

  test('«Лучшие совпадения»: точное имя → начало имени → начало слова → '
      'часть; при равенстве — проект, метка, фильтр, раздел, задача', () {
    final ws = _ws(
      tasks: [
        _task('a', 'Сдать отчёт', order: 'a'),
        _task('b', 'Отчёты за год', order: 'b'),
        _task('c', 'подотчётные', order: 'c'),
      ],
    );
    expect(_names(search(ws, 'отчёт').of(SearchTab.top)), [
      'label:отчёт',
      'filter:Отчёты недели',
      'section:Отчёты',
      'task:Отчёты за год',
      'task:Сдать отчёт',
      'task:подотчётные',
    ]);
  });

  test('«Лучших совпадений» не больше $searchTopLimit', () {
    final ws = _ws(
      tasks: [for (var i = 0; i < 15; i++) _task('t$i', 'Задача $i')],
    );
    final results = search(ws, 'задача');
    expect(results.of(SearchTab.top), hasLength(searchTopLimit));
    expect(results.of(SearchTab.tasks), hasLength(15));
  });

  test('ранг: лишние пробелы не мешают точному имени; слово с `*` в начале '
      '— «часть»', () {
    final ws = _ws(
      tasks: [
        _task('a', 'Сдать отчёт', order: 'a'),
        _task('b', 'отчёт сдать', order: 'b'),
      ],
    );
    expect(
      _names(search(ws, 'сдать   отчёт').of(SearchTab.top)).first,
      'task:Сдать отчёт',
    );
    expect(_names(search(ws, '*чёт').of(SearchTab.top)).first, 'label:отчёт');
  });

  test(
    'целое слово не находится внутри буквы из двух знаков (й = и + U+0306)',
    () {
      final ws = _ws(
        tasks: [_task('a', 'мой план', completed: true, completedAt: '1')],
      );
      expect(SearchIndex(ws).completed(SearchQuery.parse('мои')), isEmpty);
    },
  );

  test('пустой запрос — пусто', () {
    expect(search(_ws(tasks: [_task('a', 'x')]), '  ').isEmpty, isTrue);
  });

  group('выполненные', () {
    List<String> completed(Workspace ws, String text) => [
      for (final t in SearchIndex(ws).completed(SearchQuery.parse(text)))
        t.content,
    ];

    test('только целые слова: «отч» не находит выполненный «Отчёт»', () {
      final ws = _ws(
        tasks: [_task('a', 'Отчёт', completed: true, completedAt: '1')],
      );
      expect(completed(ws, 'отч'), isEmpty);
      expect(completed(ws, 'ОТЧЕТ'), ['Отчёт']);
    });

    test('описание ищется, метки — нет; позже выполненные выше', () {
      final ws = _ws(
        tasks: [
          _task(
            'a',
            'Раньше',
            description: 'бюджет',
            completed: true,
            completedAt: '2026-11-01T10:00:00Z',
          ),
          _task(
            'b',
            'Позже бюджет',
            completed: true,
            completedAt: '2026-11-02T10:00:00Z',
          ),
          _task(
            'c',
            'С меткой',
            labels: ['l1'],
            completed: true,
            completedAt: '2026-11-03T10:00:00Z',
          ),
        ],
      );
      expect(completed(ws, 'бюджет'), ['Позже бюджет', 'Раньше']);
      expect(completed(ws, 'отчёт'), isEmpty);
    });

    test('выполненные в архивном проекте не ищутся', () {
      final ws = _ws(
        tasks: [
          _task(
            'a',
            'Отчёт',
            project: 'old',
            completed: true,
            completedAt: '1',
          ),
        ],
      );
      expect(completed(ws, 'отчёт'), isEmpty);
    });
  });
}
