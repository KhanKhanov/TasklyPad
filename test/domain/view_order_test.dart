import 'package:flutter_test/flutter_test.dart';
import 'package:planner/domain/models.dart';
import 'package:planner/domain/view_options.dart';
import 'package:planner/domain/view_order.dart';

// Порядок и группы задач вида: help «Sort or group tasks» и «Default sorting
// order»; допущения — О-69 (plans/m4 «Ход M4.4»).
Task _task(
  String id, {
  String? content,
  String order = 'a',
  String dayOrder = '',
  int priority = 4,
  String? date,
  String? time,
  String? deadline,
  String? added,
  List<String> labels = const [],
  String? project,
}) => Task(
  id: id,
  content: content ?? id,
  description: '',
  projectId: project,
  orderKey: order,
  dayOrderKey: dayOrder,
  priority: priority,
  due: date == null ? null : Due(date: date, time: time),
  deadline: deadline,
  isCollapsed: false,
  isCompleted: false,
  addedAt: added,
  labelIds: labels,
);

/// Порядок проектов не важен для случая.
int _noRank(Task t) => 0;

List<String> _ids(Iterable<Task> tasks) => [for (final t in tasks) t.id];

/// Группа в ожидании теста: задачи — строкой (запись сравнивает список по
/// ссылке).
(TaskGroupKey, String) g(TaskGroupKey key, List<String> ids) =>
    (key, ids.join(','));

List<String> _sorted(List<Task> tasks, TaskOrder order) =>
    _ids([...tasks]..sort(order.compare));

void main() {
  group('сортировка «Отображения» — первый критерий, затем порядок вида', () {
    final tasks = [
      _task(
        'a',
        content: 'банан',
        order: 'b',
        priority: 2,
        date: '2026-11-05',
        deadline: '2026-11-20',
        added: '2026-10-02T10:00:00.000Z',
      ),
      _task(
        'b',
        content: 'Апельсин',
        order: 'c',
        priority: 1,
        date: '2026-11-04',
        added: '2026-10-03T10:00:00.000Z',
      ),
      _task(
        'c',
        content: 'апельсин',
        order: 'a',
        priority: 4,
        deadline: '2026-11-10',
        added: '2026-10-01T10:00:00.000Z',
      ),
      _task('d', content: 'Вишня', order: 'd', priority: 1),
    ];
    // (сортировка, направление, ожидаемый порядок): ручной порядок вида
    // разбивает равенство и не меняется с направлением.
    final cases = <(Sorting, SortOrder, List<String>)>[
      (Sorting.byDefault, SortOrder.asc, ['c', 'a', 'b', 'd']),
      // У «Вручную» направления нет (help: меню направления скрывается) —
      // `desc` из импорта порядок не разворачивает.
      (Sorting.manual, SortOrder.desc, ['c', 'a', 'b', 'd']),
      // Без учёта регистра, при равенстве — заглавная раньше (допущение).
      (Sorting.alphabetically, SortOrder.asc, ['b', 'c', 'a', 'd']),
      (Sorting.alphabetically, SortOrder.desc, ['d', 'a', 'c', 'b']),
      // Без даты — внизу, при обратном направлении — вверху (help).
      (Sorting.dueDate, SortOrder.asc, ['b', 'a', 'c', 'd']),
      (Sorting.dueDate, SortOrder.desc, ['c', 'd', 'a', 'b']),
      (Sorting.addedDate, SortOrder.asc, ['c', 'a', 'b', 'd']),
      (Sorting.addedDate, SortOrder.desc, ['d', 'b', 'a', 'c']),
      // Дедлайн — как дата (допущение).
      (Sorting.deadline, SortOrder.asc, ['c', 'a', 'b', 'd']),
      (Sorting.deadline, SortOrder.desc, ['b', 'd', 'a', 'c']),
      // Приоритет: по возрастанию — P1 сверху (help).
      (Sorting.priority, SortOrder.asc, ['b', 'd', 'a', 'c']),
      (Sorting.priority, SortOrder.desc, ['c', 'a', 'b', 'd']),
    ];
    for (final (sorting, direction, expected) in cases) {
      test('$sorting ${direction.apiName} → $expected', () {
        final order = TaskOrder(
          fallback: DefaultOrder.manual,
          projectRank: _noRank,
          sorting: sorting,
          sortOrder: direction,
        );
        expect(_sorted(tasks, order), expected);
      });
    }
  });

  test('имя для сортировки — функцией (видимый текст markdown)', () {
    final order = TaskOrder(
      fallback: DefaultOrder.manual,
      projectRank: _noRank,
      sorting: Sorting.alphabetically,
      nameOf: (t) => t.content.replaceAll('*', ''),
    );
    expect(
      _sorted([_task('x', content: '**я**'), _task('y', content: 'б')], order),
      ['y', 'x'],
    );
  });

  test(
    'умный порядок «Сегодня»: дата и время → приоритет → дедлайн → '
    'порядок дня → создание; срок без времени — перед сроком со временем',
    () {
      final tasks = [
        _task('later', date: '2026-11-04', time: '09:00'),
        _task('allday', date: '2026-11-04', priority: 4),
        _task('p1', date: '2026-11-04', time: '08:00', priority: 2),
        _task('p1b', date: '2026-11-04', time: '08:00', priority: 1),
        _task('dl', date: '2026-11-03', deadline: '2026-11-05'),
        _task('nodl', date: '2026-11-03'),
        _task('m2', date: '2026-11-02', dayOrder: 'b'),
        _task('m1', date: '2026-11-02', dayOrder: 'a'),
        _task('m0', date: '2026-11-02', added: '2026-10-01T00:00:00.000Z'),
        _task('m00', date: '2026-11-02', added: '2026-09-01T00:00:00.000Z'),
      ];
      expect(
        _sorted(
          tasks,
          const TaskOrder(fallback: DefaultOrder.smart, projectRank: _noRank),
        ),
        ['m1', 'm2', 'm00', 'm0', 'dl', 'nodl', 'allday', 'p1b', 'p1', 'later'],
      );
    },
  );

  test('по имени «ё» — как «е»: «Ёлка» между «Еда» и «Яблоко»', () {
    final order = TaskOrder(
      fallback: DefaultOrder.manual,
      projectRank: _noRank,
      sorting: Sorting.alphabetically,
    );
    expect(
      _sorted([
        _task('я', content: 'Яблоко'),
        _task('ё', content: 'Ёлка'),
        _task('е', content: 'Еда'),
      ], order),
      ['е', 'ё', 'я'],
    );
  });

  test(
    '«Вручную» вне проекта — порядок вида; «Просрочено» — без порядка дня',
    () {
      final tasks = [
        _task('late', order: 'a', date: '2026-11-04', time: '18:00'),
        _task('early', order: 'b', date: '2026-11-04', time: '09:00'),
      ];
      const manual = TaskOrder(
        fallback: DefaultOrder.smart,
        projectRank: _noRank,
        sorting: Sorting.manual,
      );
      expect(_sorted(tasks, manual), ['early', 'late']);

      final day = [
        _task('x', date: '2026-11-01', dayOrder: 'b', added: '2026-09-01'),
        _task('y', date: '2026-11-01', dayOrder: 'a', added: '2026-10-01'),
      ];
      expect(
        _sorted(
          day,
          const TaskOrder(fallback: DefaultOrder.smart, projectRank: _noRank),
        ),
        ['y', 'x'],
      );
      expect(
        _sorted(
          day,
          const TaskOrder(fallback: DefaultOrder.overdue, projectRank: _noRank),
        ),
        ['x', 'y'],
      );
    },
  );

  test('порядок метки: приоритет → дата → дедлайн → порядок проектов', () {
    final rank = {'x': 1, 'y': 0, 'z': 2, 'w': 3};
    final tasks = [
      _task('x', priority: 1),
      _task('y', priority: 1),
      _task('z', priority: 1, date: '2026-11-04'),
      _task('w', priority: 3, date: '2026-11-01', deadline: '2026-11-02'),
    ];
    final order = TaskOrder(
      fallback: DefaultOrder.label,
      projectRank: (t) => rank[t.id]!,
    );
    expect(_sorted(tasks, order), ['z', 'y', 'x', 'w']);
  });

  group('группы — порядок групп и задач в группе', () {
    const today = '2026-11-03';
    const order = TaskOrder(
      fallback: DefaultOrder.manual,
      projectRank: _noRank,
      sorting: Sorting.priority,
    );
    List<(TaskGroupKey, String)> groups(
      List<Task> tasks,
      Grouping grouping, {
      List<String> labels = const [],
      List<String> projects = const [],
    }) => [
      for (final g in groupTasks(
        tasks,
        grouping,
        order: order,
        today: today,
        labelOrder: labels,
        projectOrder: projects,
        localDay: (utc) => utc.substring(0, 10),
      ))
        (g.key, _ids(g.tasks).join(',')),
    ];

    test('по сроку: «Просрочено», дни по порядку, «Без срока» последней; '
        'внутри — сортировка вида', () {
      final tasks = [
        _task('none'),
        _task('late2', date: '2026-11-01'),
        _task('late1', date: '2026-10-30', priority: 1),
        _task('d5', date: '2026-11-05'),
        _task('d3', date: today, priority: 3),
        _task('d3p1', date: today, priority: 1),
      ];
      expect(groups(tasks, Grouping.dueDate), [
        g(const TaskGroupKey.overdue(), ['late1', 'late2']),
        g(const TaskGroupKey.day(today), ['d3p1', 'd3']),
        g(const TaskGroupKey.day('2026-11-05'), ['d5']),
        g(const TaskGroupKey.empty(), ['none']),
      ]);
    });

    test('по дедлайну — так же, по дате добавления — новые дни сверху', () {
      final tasks = [
        _task('a', deadline: '2026-11-01', added: '2026-10-01T09:00:00Z'),
        _task('b', deadline: '2026-11-09', added: '2026-10-05T09:00:00Z'),
        _task('c'),
      ];
      expect(groups(tasks, Grouping.deadline), [
        g(const TaskGroupKey.overdue(), ['a']),
        g(const TaskGroupKey.day('2026-11-09'), ['b']),
        g(const TaskGroupKey.empty(), ['c']),
      ]);
      expect(groups(tasks, Grouping.addedDate), [
        g(const TaskGroupKey.day('2026-10-05'), ['b']),
        g(const TaskGroupKey.day('2026-10-01'), ['a']),
        g(const TaskGroupKey.empty(), ['c']),
      ]);
    });

    test('выполненные в группе — после активных, позже выполненные выше', () {
      Task done(String id, String at) =>
          _task(id, priority: 1).copyWith(isCompleted: true, completedAt: at);
      final tasks = [
        done('old', '2026-11-01T10:00:00Z'),
        _task('active', priority: 1),
        done('new', '2026-11-02T10:00:00Z'),
      ];
      expect(groups(tasks, Grouping.priority), [
        g(const TaskGroupKey.priority(1), ['active', 'new', 'old']),
      ]);
    });

    test('по приоритету — P1 → P4', () {
      final tasks = [
        _task('p4'),
        _task('p2', priority: 2),
        _task('p1', priority: 1),
      ];
      expect(groups(tasks, Grouping.priority), [
        g(const TaskGroupKey.priority(1), ['p1']),
        g(const TaskGroupKey.priority(2), ['p2']),
        g(const TaskGroupKey.priority(4), ['p4']),
      ]);
    });

    test('по метке — порядок меток, задача с двумя метками в обеих, «Без '
        'метки» последней; неизвестная метка — после известных', () {
      final tasks = [
        _task('both', labels: ['home', 'work']),
        _task('work', labels: ['work']),
        _task('none'),
        _task('ghost', labels: ['ghost']),
      ];
      expect(groups(tasks, Grouping.label, labels: ['work', 'home']), [
        g(const TaskGroupKey.label('work'), ['both', 'work']),
        g(const TaskGroupKey.label('home'), ['both']),
        g(const TaskGroupKey.label('ghost'), ['ghost']),
        g(const TaskGroupKey.empty(), ['none']),
      ]);
    });

    test('по проекту — порядок проектов; без группировки — одна группа', () {
      final tasks = [_task('w', project: 'work'), _task('i', project: 'inbox')];
      expect(groups(tasks, Grouping.project, projects: ['inbox', 'work']), [
        g(const TaskGroupKey.project('inbox'), ['i']),
        g(const TaskGroupKey.project('work'), ['w']),
      ]);
      expect(groups(tasks, Grouping.none), [
        g(const TaskGroupKey.empty(), ['i', 'w']),
      ]);
    });
  });
}
