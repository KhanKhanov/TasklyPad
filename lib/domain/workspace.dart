import 'models.dart';
import 'tree.dart';

/// Снимок всех данных пользователя с вычисленными производными: что живо,
/// что в архиве, деревья проектов и задач, счётчики.
///
/// Каскад вычисляемый: удаление проекта, раздела или родительской задачи —
/// одна op на нём самом, а потомки скрываются здесь. Поэтому отмена удаления —
/// тоже одна op, а подзадача, добавленная в это время на другом устройстве,
/// не остаётся «сиротой» (docs/plans/m2-core-app.md, решения 2–4).
///
/// Правила:
/// - родитель, который удалён, скрывает потомков; родитель, которого нет
///   (ещё не пришёл с другого устройства), не действует — элемент корневой;
/// - подзадача живёт и показывается по дереву `parent_id`: её собственные
///   проект и раздел важны только для корневых задач;
/// - цикл родителей разрывается одинаково на всех устройствах ([resolveParents]);
/// - порядок — по `order_key`, при равенстве — по id.
final class Workspace {
  Workspace({
    required Iterable<Project> projects,
    required Iterable<Section> sections,
    required Iterable<Label> labels,
    required Iterable<Task> tasks,
    Set<String> deletedProjectIds = const {},
    Set<String> deletedSectionIds = const {},
    Set<String> deletedTaskIds = const {},
  }) {
    _initProjects(projects, deletedProjectIds);
    _initSections(sections, deletedProjectIds);
    for (final label in [...labels]..sort(_byOrder(_labelKey))) {
      _labels[label.id] = label;
    }
    _initTasks(tasks, deletedProjectIds, deletedSectionIds, deletedTaskIds);
  }

  // Проекты: живые (без удалённых предков) и действующий родитель.
  final Map<String, Project> _projects = {};
  final Map<String, String?> _projectParent = {};
  final Map<String?, List<Project>> _projectChildren = {};

  final Map<String, Section> _sections = {};
  final Map<String, Label> _labels = {};

  // Задачи: живые, действующий родитель, дети по порядку.
  final Map<String, Task> _tasks = {};
  final Map<String, String?> _taskParent = {};
  final Map<String, List<Task>> _taskChildren = {};

  /// Корневые задачи: (проект, раздел) → задачи по порядку. Проект `null` у
  /// задачи — «Входящие»; раздел, которого нет, — «без раздела».
  final Map<(String, String?), List<Task>> _roots = {};

  String? _inboxId;

  // Id всех переданных живых проектов и разделов, в том числе скрытых
  // каскадом. Ссылка на неизвестный (ещё не пришедший) проект или раздел
  // задачу не скрывает, на известный, но скрытый — скрывает.
  final Set<String> _knownProjects = {};
  final Set<String> _knownSections = {};

  // --- Проекты ---

  /// «Входящие»; `null` — до первого запуска ядра данных (в тестах).
  Project? get inbox => _inboxId == null ? null : _projects[_inboxId];

  /// Живой проект (в том числе архивный) или `null`.
  Project? project(String id) => _projects[id];

  /// Активные проекты деревом в порядке сайдбара, без «Входящих» и архива.
  /// Подпроекты свёрнутого проекта не выводятся.
  List<TreeItem<Project>> projectTree({bool expandCollapsed = false}) =>
      flattenTree(
        _activeChildProjects(null).where((p) => !p.isInbox),
        (p) => _activeChildProjects(p.id),
        collapsed: expandCollapsed ? null : (p) => p.isCollapsed,
      );

  /// Архивные проекты верхнего уровня архива (их подпроекты — внутри).
  List<Project> get archivedProjects => [
    for (final p in _projects.values)
      if (p.isArchived && !_isArchived(_projectParent[p.id])) p,
  ]..sort(_byOrder(_projectKey));

  /// Избранные активные проекты по порядку сайдбара.
  List<Project> get favoriteProjects => [
    for (final item in projectTree(expandCollapsed: true))
      if (item.value.isFavorite) item.value,
  ];

  /// Проект в архиве — сам или через предка.
  bool isProjectArchived(String id) => _isArchived(id);

  /// Активные дочерние проекты [parentId] (`null` — верхний уровень).
  List<Project> childProjects(String? parentId) =>
      _activeChildProjects(parentId);

  /// Уровень проекта: 1 — верхний.
  int projectDepth(String id) {
    var depth = 0;
    for (String? p = id; p != null; p = _projectParent[p]) {
      depth++;
    }
    return depth;
  }

  /// Высота поддерева проекта: 1 — без подпроектов.
  int projectHeight(String id) {
    final children = _projectChildren[id] ?? const [];
    return 1 + children.fold(0, (h, c) => _max(h, projectHeight(c.id)));
  }

  /// Проект и все его живые подпроекты (включая архивные).
  List<String> projectSubtree(String id) => [
    id,
    for (final child in _projectChildren[id] ?? const <Project>[])
      ...projectSubtree(child.id),
  ];

  // --- Разделы ---

  Section? section(String id) => _sections[id];

  /// Разделы проекта по порядку; [archived] — только архивные, иначе только
  /// активные.
  List<Section> sectionsOf(String projectId, {bool archived = false}) => [
    for (final s in _sections.values)
      if (_projectOf(s.projectId) == projectId && s.isArchived == archived) s,
  ]..sort(_byOrder(_sectionKey));

  // --- Метки ---

  /// Живые метки по порядку.
  List<Label> get labels => _labels.values.toList();

  Label? label(String id) => _labels[id];

  /// Активные задачи с меткой (с подзадачами, без архивных проектов), по
  /// порядку проектов и задач.
  List<Task> labelTasks(String labelId) {
    final order = {
      for (final (i, item) in projectTree(expandCollapsed: true).indexed)
        item.value.id: i,
      ?_inboxId: -1,
    };
    final result = [
      for (final t in _tasks.values)
        if (t.labelIds.contains(labelId) && _isActive(t)) t,
    ];
    int rank(Task t) => order[_rootProject(t)] ?? order.length;
    return result..sort((a, b) {
      final byProject = rank(a).compareTo(rank(b));
      return byProject != 0 ? byProject : _byOrder(_taskKey)(a, b);
    });
  }

  // --- Задачи ---

  /// Живая задача или `null`.
  Task? task(String id) => _tasks[id];

  /// Список проекта: задачи без раздела, затем разделы со своими задачами.
  /// Завершённые и их подзадачи — только при [showCompleted], после
  /// активных соседей. Подзадачи свёрнутой задачи не выводятся.
  ProjectView projectView(String projectId, {bool showCompleted = false}) {
    List<TreeItem<Task>> tree(String? sectionId) => flattenTree(
      _visible(_roots[(projectId, sectionId)] ?? const [], showCompleted),
      (t) => _visible(_taskChildren[t.id] ?? const [], showCompleted),
      collapsed: (t) => t.isCollapsed,
    );
    return ProjectView(
      projectId: projectId,
      unsectioned: tree(null),
      sections: [
        for (final s in sectionsOf(projectId)) (section: s, tasks: tree(s.id)),
      ],
    );
  }

  /// Подзадачи задачи деревом (для панели задачи), без учёта свёрнутости.
  List<TreeItem<Task>> subtasksOf(
    String taskId, {
    bool showCompleted = false,
  }) => flattenTree(
    _visible(_taskChildren[taskId] ?? const [], showCompleted),
    (t) => _visible(_taskChildren[t.id] ?? const [], showCompleted),
  );

  /// Прямые живые дети задачи (`null` — корни раздела [sectionId] проекта
  /// [projectId]), включая завершённые, по порядку.
  List<Task> children(
    String? parentId, {
    String? projectId,
    String? sectionId,
  }) => parentId != null
      ? (_taskChildren[parentId] ?? const [])
      : (_roots[(projectId ?? _inboxId ?? '', sectionId)] ?? const []);

  /// Задача и все её живые потомки.
  List<String> taskSubtree(String id) => [
    id,
    for (final child in _taskChildren[id] ?? const <Task>[])
      ...taskSubtree(child.id),
  ];

  /// Действующий родитель проекта (`null` — верхний уровень).
  String? projectParent(String id) => _projectParent[id];

  /// Действующий родитель задачи.
  String? taskParent(String id) => _taskParent[id];

  /// Уровень задачи: 1 — корневая.
  int taskDepth(String id) {
    var depth = 0;
    for (String? t = id; t != null; t = _taskParent[t]) {
      depth++;
    }
    return depth;
  }

  /// Высота поддерева задачи: 1 — без подзадач.
  int taskHeight(String id) {
    final children = _taskChildren[id] ?? const [];
    return 1 + children.fold(0, (h, c) => _max(h, taskHeight(c.id)));
  }

  /// Проект, в котором задача видна: проект её корневой задачи.
  String rootProjectOf(String taskId) => _rootProject(_tasks[taskId]!);

  /// Число активных задач проекта (с подзадачами) — счётчик в сайдбаре.
  int activeTaskCount(String projectId) => _tasks.values
      .where((t) => _rootProject(t) == projectId && _isActive(t))
      .length;

  // --- Построение ---

  void _initProjects(Iterable<Project> projects, Set<String> deleted) {
    final byId = {for (final p in projects) p.id: p};
    final parents = resolveParents({
      for (final p in byId.values) p.id: p.parentId,
    });
    final dead = <String, bool>{};
    bool isDead(String id) => dead[id] ??= () {
      final p = byId[id]!;
      if (deleted.contains(p.parentId)) return true;
      final parent = parents[id];
      return parent != null && isDead(parent);
    }();
    _knownProjects.addAll(byId.keys);
    for (final p in byId.values) {
      if (isDead(p.id)) continue;
      _projects[p.id] = p;
      _projectParent[p.id] = parents[p.id];
      if (p.isInbox) _inboxId ??= p.id;
    }
    for (final p in _projects.values) {
      (_projectChildren[_projectParent[p.id]] ??= []).add(p);
    }
    for (final list in _projectChildren.values) {
      list.sort(_byOrder(_projectKey));
    }
  }

  void _initSections(Iterable<Section> sections, Set<String> deletedProjects) {
    for (final s in sections) {
      _knownSections.add(s.id);
      if (_projectAlive(s.projectId, deletedProjects)) _sections[s.id] = s;
    }
  }

  void _initTasks(
    Iterable<Task> tasks,
    Set<String> deletedProjects,
    Set<String> deletedSections,
    Set<String> deleted,
  ) {
    final byId = {for (final t in tasks) t.id: t};
    final parents = resolveParents({
      for (final t in byId.values) t.id: t.parentId,
    });
    final dead = <String, bool>{};
    bool isDead(String id) => dead[id] ??= () {
      final t = byId[id]!;
      if (deleted.contains(t.parentId)) return true;
      final parent = parents[id];
      if (parent != null) return isDead(parent);
      // Корневая задача в живом разделе живёт по разделу (его проект жив),
      // в удалённом или скрытом каскадом — скрыта; иначе важен её проект.
      final section = t.sectionId;
      if (section != null) {
        if (_sections.containsKey(section)) return false;
        if (deletedSections.contains(section) ||
            _knownSections.contains(section)) {
          return true;
        }
      }
      return !_projectAlive(t.projectId, deletedProjects);
    }();
    for (final t in byId.values) {
      if (isDead(t.id)) continue;
      _tasks[t.id] = t.copyWith(
        labelIds: [
          for (final id in t.labelIds)
            if (_labels.containsKey(id)) id,
        ]..sort((a, b) => _byOrder(_labelKey)(_labels[a]!, _labels[b]!)),
      );
      _taskParent[t.id] = parents[t.id];
    }
    for (final t in _tasks.values) {
      final parent = _taskParent[t.id];
      if (parent != null) {
        (_taskChildren[parent] ??= []).add(t);
      } else {
        final section = _sections.containsKey(t.sectionId) ? t.sectionId : null;
        (_roots[(_homeProject(t), section)] ??= []).add(t);
      }
    }
    for (final list in [..._taskChildren.values, ..._roots.values]) {
      list.sort(_byOrder(_taskKey));
    }
  }

  bool _projectAlive(String? projectId, Set<String> deleted) {
    if (projectId == null) return true;
    if (deleted.contains(projectId)) return false;
    // Проект не пришёл — не скрываем; пришёл и мёртв по каскаду — скрываем.
    return _projects.containsKey(projectId) ||
        !_knownProjects.contains(projectId);
  }

  String? _projectOf(String? projectId) => projectId ?? _inboxId;

  String _rootProject(Task t) {
    var root = t;
    for (var p = _taskParent[root.id]; p != null; p = _taskParent[p]) {
      root = _tasks[p]!;
    }
    return _homeProject(root);
  }

  /// Проект корневой задачи: в живом разделе — проект раздела (раздел могли
  /// перенести на другом устройстве после того, как в него добавили задачу),
  /// иначе — её собственный, а без проекта — «Входящие».
  String _homeProject(Task root) {
    final section = _sections[root.sectionId];
    return (section != null
            ? _projectOf(section.projectId)
            : _projectOf(root.projectId)) ??
        '';
  }

  bool _isArchived(String? projectId) {
    for (String? p = projectId; p != null; p = _projectParent[p]) {
      if (_projects[p]?.isArchived ?? false) return true;
    }
    return false;
  }

  /// Задача видна в обычных списках: не завершена, её корень в активном
  /// проекте и в активном разделе.
  bool _isActive(Task t) {
    if (t.isCompleted) return false;
    var root = t;
    for (var p = _taskParent[t.id]; p != null; p = _taskParent[p]) {
      root = _tasks[p]!;
      if (root.isCompleted) return false;
    }
    final section = _sections[root.sectionId];
    return !_isArchived(_homeProject(root)) && !(section?.isArchived ?? false);
  }

  List<Project> _activeChildProjects(String? parentId) => [
    for (final p in _projectChildren[parentId] ?? const <Project>[])
      if (!p.isArchived) p,
  ];

  static List<Task> _visible(List<Task> tasks, bool showCompleted) => [
    for (final t in tasks)
      if (!t.isCompleted) t,
    if (showCompleted)
      ...[
        for (final t in tasks)
          if (t.isCompleted) t,
      ]..sort((a, b) {
        // Позже завершённые выше; завершённые вместе (родитель с
        // подзадачами) — в обычном порядке.
        final byTime = (b.completedAt ?? '').compareTo(a.completedAt ?? '');
        return byTime != 0 ? byTime : _byOrder(_taskKey)(a, b);
      }),
  ];

  static String _projectKey(Project p) => p.orderKey;
  static String _sectionKey(Section s) => s.orderKey;
  static String _labelKey(Label l) => l.orderKey;
  static String _taskKey(Task t) => t.orderKey;

  static int Function(T, T) _byOrder<T>(String Function(T) key) => (a, b) {
    final byKey = key(a).compareTo(key(b));
    return byKey != 0 ? byKey : _id(a).compareTo(_id(b));
  };

  static String _id(Object? item) => switch (item) {
    Project(:final id) || Section(:final id) || Label(:final id) => id,
    Task(:final id) => id,
    _ => '',
  };

  static int _max(int a, int b) => a > b ? a : b;
}

/// Список проекта: задачи без раздела и разделы со своими задачами.
final class ProjectView {
  const ProjectView({
    required this.projectId,
    required this.unsectioned,
    required this.sections,
  });

  final String projectId;
  final List<TreeItem<Task>> unsectioned;
  final List<({Section section, List<TreeItem<Task>> tasks})> sections;
}
