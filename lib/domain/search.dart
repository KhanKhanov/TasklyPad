import 'markdown_text.dart';
import 'models.dart';
import 'text_fold.dart';
import 'view_order.dart';
import 'workspace.dart';

// Поиск по снимку в памяти (help «Introduction to search»; решение 6А
// plans/m5): задачи (название, описание), проекты, разделы, метки, фильтры;
// архивные проекты, их разделы и задачи не ищутся. Регистр не важен, «ё» =
// «е» — та же свёртка, что у фильтров ([foldText]). Допущения, где help
// молчит (О-69), — plans/m5 «Решения M5.4».

/// Строк в «Лучших совпадениях» (в help число не указано — допущение).
const int searchTopLimit = 10;

/// Слово поиска; `*` — любые буквы внутри слова (help: «Use an asterisk (*)
/// as a wildcard to match partial words»).
final class SearchWord {
  SearchWord(this.text)
    : _inText = RegExp(_body(text), unicode: true),
      _whole = RegExp('(?<!$_letter)${_body(text)}(?!$_letter)', unicode: true);

  /// Слово как введено.
  final String text;

  final RegExp _inText;
  final RegExp _whole;

  // Буквы, цифры и комбинирующие знаки (ударение; «й» из «и» и U+0306).
  static const String _letter = r'[\p{L}\p{M}\p{N}]';

  static String _body(String text) =>
      foldText(text).split('*').map(RegExp.escape).join('$_letter*');

  /// Слово — часть свёрнутого текста [folded] (у активных задач и имён).
  bool inText(String folded) => _inText.hasMatch(folded);

  /// Слово — начало свёрнутого текста [folded].
  bool startsText(String folded) => _atStart.hasMatch(folded);

  /// Слово — начало одного из слов свёрнутого текста [folded].
  bool startsWordIn(String folded) => _atWord.hasMatch(folded);

  late final RegExp _atStart = RegExp('^${_body(text)}', unicode: true);
  late final RegExp _atWord = RegExp(
    '(?<!$_letter)${_body(text)}',
    unicode: true,
  );

  /// Слово — целое слово свёрнутого текста [folded] (у выполненных задач —
  /// help: «Searching for partial keywords won't match completed tasks»).
  bool wholeIn(String folded) => _whole.hasMatch(folded);
}

/// Запрос поиска словами: все слова — в одном тексте, в любом порядке.
final class SearchQuery {
  SearchQuery._(this.text, this.words);

  /// Слова строки [text] через пробелы; слово из одних `*` ничего не сужает
  /// и отбрасывается.
  factory SearchQuery.parse(String text) => SearchQuery._(text.trim(), [
    for (final w in text.trim().split(RegExp(r'\s+')))
      if (w.replaceAll('*', '').isNotEmpty) SearchWord(w),
  ]);

  /// Строка без пробелов по краям.
  final String text;
  final List<SearchWord> words;

  /// Слова через один пробел, свёрнутые, — для точного совпадения имени.
  late final String folded = foldText(
    [for (final w in words) w.text].join(' '),
  );

  bool get isEmpty => words.isEmpty;

  /// Все слова — части свёрнутого текста [folded].
  bool inText(String folded) => words.every((w) => w.inText(folded));

  /// Все слова — целые слова свёрнутого текста [folded].
  bool wholeIn(String folded) => words.every((w) => w.wholeIn(folded));
}

/// Вкладки результатов (help: «Top», «Tasks», «Task descriptions»,
/// «Projects», «Sections», «Labels», «Filters»; «Folders» — командная работа,
/// вне scope; «Comments» — M8).
enum SearchTab { top, tasks, descriptions, projects, sections, labels, filters }

/// Найденный элемент.
sealed class SearchHit {
  const SearchHit();
}

/// Задача — по названию или (вкладка «Описания задач») по описанию.
final class TaskHit extends SearchHit {
  const TaskHit(this.task);
  final Task task;
}

final class ProjectHit extends SearchHit {
  const ProjectHit(this.project);
  final Project project;
}

/// Раздел с проектом, в котором он виден.
final class SectionHit extends SearchHit {
  const SectionHit(this.section, this.project);
  final Section section;
  final Project project;
}

final class LabelHit extends SearchHit {
  const LabelHit(this.label);
  final Label label;
}

final class FilterHit extends SearchHit {
  const FilterHit(this.filter);
  final SavedFilter filter;
}

/// Результаты поиска по вкладкам.
final class SearchResults {
  const SearchResults(this._tabs);

  static const SearchResults empty = SearchResults({});

  final Map<SearchTab, List<SearchHit>> _tabs;

  /// Найденное во вкладке [tab]; пустая вкладка — пустой список.
  List<SearchHit> of(SearchTab tab) => _tabs[tab] ?? const [];

  /// Ничего не найдено.
  bool get isEmpty => _tabs.values.every((hits) => hits.isEmpty);
}

/// Свёрнутые тексты снимка [Workspace] — считаются один раз на снимок, а
/// не на каждую букву ввода.
final class SearchIndex {
  SearchIndex(Workspace ws) : _ws = ws {
    final order = ws.taskOrder(DefaultOrder.label);
    for (final t in ws.activeTasks..sort(order.compare)) {
      _tasks.add((t, _fold(t.content), _fold(t.description)));
    }
    final inbox = ws.inbox;
    final projects = [
      if (inbox != null && !inbox.isArchived) inbox,
      for (final item in ws.projectTree(expandCollapsed: true)) item.value,
    ];
    for (final p in projects) {
      _projects.add((
        p,
        [foldText(p.name), if (p.isInbox) ...inboxAliases.map(foldText)],
      ));
      for (final s in ws.sectionsOf(p.id)) {
        _sections.add((SectionHit(s, p), foldText(s.name)));
      }
    }
    for (final l in ws.labels) {
      _labels.add((l, foldText(l.name)));
    }
    for (final f in ws.filters) {
      _filters.add((f, foldText(f.name)));
    }
  }

  final Workspace _ws;
  final List<(Task, String, String)> _tasks = [];
  final List<(Project, List<String>)> _projects = [];
  final List<(SectionHit, String)> _sections = [];
  final List<(Label, String)> _labels = [];
  final List<(SavedFilter, String)> _filters = [];

  static String _fold(String text) => foldText(plainText(text));

  /// Активное найденное по [query] по вкладкам; пустой запрос — пусто.
  SearchResults search(SearchQuery query) {
    if (query.isEmpty) return SearchResults.empty;
    final ranked = <(int, int, SearchHit)>[];
    void rank(int type, String name, SearchHit hit) =>
        ranked.add((_rank(query, name), type, hit));

    final projects = <SearchHit>[];
    for (final (p, names) in _projects) {
      final match = names.where(query.inText).firstOrNull;
      if (match == null) continue;
      final hit = ProjectHit(p);
      projects.add(hit);
      rank(0, match, hit);
    }
    final labels = <SearchHit>[];
    for (final (l, name) in _labels) {
      if (!query.inText(name)) continue;
      final hit = LabelHit(l);
      labels.add(hit);
      rank(1, name, hit);
    }
    final filters = <SearchHit>[];
    for (final (f, name) in _filters) {
      if (!query.inText(name)) continue;
      final hit = FilterHit(f);
      filters.add(hit);
      rank(2, name, hit);
    }
    final sections = <SearchHit>[];
    for (final (hit, name) in _sections) {
      if (!query.inText(name)) continue;
      sections.add(hit);
      rank(3, name, hit);
    }
    final tasks = <SearchHit>[];
    final descriptions = <SearchHit>[];
    for (final (t, title, description) in _tasks) {
      if (query.inText(title)) {
        final hit = TaskHit(t);
        tasks.add(hit);
        rank(4, title, hit);
      }
      if (query.inText(description)) descriptions.add(TaskHit(t));
    }
    // Сортировка устойчивая: при равных ранге и типе — порядок вкладки.
    final top = _stableSorted(ranked);
    return SearchResults({
      SearchTab.top: [for (final (_, _, hit) in top.take(searchTopLimit)) hit],
      SearchTab.tasks: tasks,
      SearchTab.descriptions: descriptions,
      SearchTab.projects: projects,
      SearchTab.sections: sections,
      SearchTab.labels: labels,
      SearchTab.filters: filters,
    });
  }

  /// Выполненные задачи с [query] целыми словами в названии или описании,
  /// без меток (help «Introduction to search»), позже выполненные выше.
  List<Task> completed(SearchQuery query) => query.isEmpty
      ? const []
      : [
          for (final (t, title, description) in _completed)
            if (query.wholeIn(title) || query.wholeIn(description)) t,
        ];

  /// Выполненные со свёрнутыми названием и описанием — один раз на снимок,
  /// при первом поиске в выполненных.
  late final List<(Task, String, String)> _completed = [
    for (final t in _ws.completedTasks)
      (t, _fold(t.content), _fold(t.description)),
  ];

  /// Ранг совпадения имени [name]: точное имя → начало имени → начало
  /// слова → часть слова (допущение, О-69). Первое слово, начатое `*`, —
  /// всегда «часть».
  static int _rank(SearchQuery query, String name) {
    if (name == query.folded) return 0;
    final first = query.words.first;
    if (first.text.startsWith('*')) return 3;
    if (first.startsText(name)) return 1;
    return first.startsWordIn(name) ? 2 : 3;
  }

  static List<(int, int, SearchHit)> _stableSorted(
    List<(int, int, SearchHit)> ranked,
  ) {
    final indexed = [for (var i = 0; i < ranked.length; i++) (i, ranked[i])];
    indexed.sort((a, b) {
      final (ia, (ra, ta, _)) = a;
      final (ib, (rb, tb, _)) = b;
      if (ra != rb) return ra - rb;
      if (ta != tb) return ta - tb;
      return ia - ib;
    });
    return [for (final (_, item) in indexed) item];
  }
}
