import '../../../domain/models.dart';
import '../../../domain/workspace.dart';
import '../../../nlp/parse_context.dart';
import '../../../nlp/quick_add.dart';
import '../../../nlp/scanner.dart';

/// Место и метки, с которыми открыт редактор: экран проекта, раздела,
/// метки или подзадача (решение 2А «Ход M3.6»).
final class QuickAddDefaults {
  const QuickAddDefaults({
    required this.projectId,
    this.sectionId,
    this.parentId,
    this.labelIds = const {},
  });

  final String projectId;
  final String? sectionId;

  /// Подзадача: место задаёт родитель, токены `#` и `/` — текст.
  final String? parentId;
  final Set<String> labelIds;
}

/// Что выбрано чипами окна; `null` у поля — не выбиралось.
final class ChipChoices {
  const ChipChoices({
    this.due,
    this.priority,
    this.labelIds,
    this.deadline,
    this.place,
  });

  /// Срок из планировщика; `due: null` внутри — «Без срока».
  final ({Due? due})? due;
  final int? priority;

  /// Метки целиком, как отмечены в выборе.
  final Set<String>? labelIds;
  final ({String? date})? deadline;
  final ({String projectId, String? sectionId})? place;

  ChipChoices copyWith({
    ({Due? due})? due,
    int? priority,
    Set<String>? labelIds,
    ({String? date})? deadline,
    ({String projectId, String? sectionId})? place,
  }) => ChipChoices(
    due: due ?? this.due,
    priority: priority ?? this.priority,
    labelIds: labelIds ?? this.labelIds,
    deadline: deadline ?? this.deadline,
    place: place ?? this.place,
  );
}

/// Задача, готовая к записи: проект и метки — id существующих или имена
/// тех, что создаются вместе с задачей (решение 1А «Ход M3.6»).
final class TaskDraft {
  const TaskDraft({
    required this.title,
    required this.description,
    required this.projectId,
    required this.newProject,
    required this.sectionId,
    required this.parentId,
    required this.labelIds,
    required this.newLabels,
    required this.priority,
    required this.due,
    required this.deadline,
    required this.duration,
  });

  final String title;
  final String description;

  /// Существующий проект; `null` — создаётся [newProject].
  final String? projectId;
  final String? newProject;
  final String? sectionId;
  final String? parentId;
  final Set<String> labelIds;

  /// Имена меток, которых ещё нет, по порядку в строке.
  final List<String> newLabels;
  final int priority;
  final Due? due;
  final String? deadline;
  final TaskDuration? duration;
}

/// Разбор строки и его итог для записи.
final class ResolvedQuickAdd {
  const ResolvedQuickAdd(this.result, this.draft, this.unresolved);

  /// Разбор, в котором неизвестные имена уже стали текстом названия.
  final QuickAddResult result;
  final TaskDraft draft;

  /// Участки токенов, имени которых нет и создание не выбрано, — текст.
  final List<Span> unresolved;
}

/// Сопоставляет имена разбора с проектами, разделами и метками [ws].
///
/// Имя ищется без учёта регистра; «Входящие» — также по [inboxNames]
/// (название на языке интерфейса). Неизвестный проект или метка, создание
/// которых не выбрано в автодополнении ([pendingProjects],
/// [pendingLabels]), и раздел, которого нет в проекте задачи, остаются
/// текстом: участок добавляется к отменённым и строка разбирается заново
/// (решение 1А «Ход M3.6»).
final class QuickAddResolver {
  QuickAddResolver({
    required this.ws,
    required this.defaults,
    this.inboxNames = const {},
  });

  final Workspace ws;
  final QuickAddDefaults defaults;
  final Set<String> inboxNames;

  ResolvedQuickAdd resolve(
    String text,
    ParseContext ctx, {
    List<Span> dismissed = const [],
    bool smartDates = true,
    ChipChoices chips = const ChipChoices(),
    Set<String> pendingProjects = const {},
    Set<String> pendingLabels = const {},
  }) {
    final unresolved = <Span>[];
    final newProjects = _lowerSet(pendingProjects);
    final newLabels = _lowerSet(pendingLabels);
    // Каждый проход отменяет хотя бы один участок, поэтому их не больше,
    // чем токенов в строке.
    for (;;) {
      final r = parseQuickAdd(
        text,
        ctx,
        dismissed: [...dismissed, ...unresolved],
        smartDates: smartDates,
      );
      final bad = _firstUnresolved(text, r, chips, newProjects, newLabels);
      if (bad == null) {
        return ResolvedQuickAdd(r, _draft(text, r, chips), unresolved);
      }
      unresolved.add(bad);
    }
  }

  Span? _firstUnresolved(
    String text,
    QuickAddResult r,
    ChipChoices chips,
    Set<String> newProjects,
    Set<String> newLabels,
  ) {
    // Сначала проект: раздел ищется в нём, где бы ни стоял токен `#`.
    String? projectId;
    var newProject = false;
    for (final h in r.highlights) {
      if (h.kind != HighlightKind.project) continue;
      if (defaults.parentId != null) return h.span;
      final name = tokenName(text, h);
      projectId = _project(name)?.id;
      newProject = projectId == null && newProjects.contains(_lower(name));
      if (projectId == null && !newProject) return h.span;
    }
    for (final h in r.highlights) {
      final name = tokenName(text, h);
      switch (h.kind) {
        case HighlightKind.section:
          if (defaults.parentId != null || newProject) return h.span;
          final place =
              projectId ?? chips.place?.projectId ?? defaults.projectId;
          if (findSection(ws, place, name) == null) return h.span;
        case HighlightKind.label:
          if (findLabel(ws, name) == null &&
              !newLabels.contains(_lower(name))) {
            return h.span;
          }
        default:
      }
    }
    return null;
  }

  TaskDraft _draft(String text, QuickAddResult r, ChipChoices chips) {
    bool has(HighlightKind kind) => r.highlights.any((h) => h.kind == kind);
    final projectName = r.project;
    final tokenProject = projectName == null ? null : _project(projectName);
    final String? projectId;
    final String? sectionId;
    if (defaults.parentId != null) {
      (projectId, sectionId) = (defaults.projectId, null);
    } else if (projectName != null) {
      projectId = tokenProject?.id;
      sectionId = tokenProject == null || r.section == null
          ? null
          : findSection(ws, tokenProject.id, r.section!)?.id;
    } else {
      final place = chips.place;
      projectId = place?.projectId ?? defaults.projectId;
      final token = r.section == null
          ? null
          : findSection(ws, projectId, r.section!)?.id;
      sectionId =
          token ?? (place == null ? defaults.sectionId : place.sectionId);
    }

    final labelIds = {...(chips.labelIds ?? defaults.labelIds)};
    final newLabels = <String>[];
    for (final name in r.labels) {
      final label = findLabel(ws, name);
      if (label != null) {
        labelIds.add(label.id);
      } else if (!newLabels.any((n) => _lower(n) == _lower(name))) {
        newLabels.add(name);
      }
    }

    final Due? due;
    if (has(HighlightKind.due)) {
      due = r.noDate ? null : r.due;
    } else if (chips.due?.due case final picked?) {
      // Время отрезка `9:30-10:00` ложится на срок из планировщика.
      final rangeTime = r.due?.time;
      due = rangeTime == null || picked.time != null
          ? picked
          : picked.copyWith(time: rangeTime);
    } else if (chips.due != null) {
      due = null;
    } else {
      due = r.due;
    }

    return TaskDraft(
      title: r.title,
      description: r.description,
      projectId: projectId,
      newProject: projectName != null && tokenProject == null
          ? projectName
          : null,
      sectionId: sectionId,
      parentId: defaults.parentId,
      labelIds: labelIds,
      newLabels: newLabels,
      priority: has(HighlightKind.priority) ? r.priority : chips.priority ?? 4,
      due: due,
      deadline: has(HighlightKind.deadline) ? r.deadline : chips.deadline?.date,
      duration: r.duration,
    );
  }

  Project? _project(String name) =>
      findProject(ws, name, inboxNames: inboxNames);
}

/// Активный проект с именем [name] без учёта регистра (первый в порядке
/// сайдбара); «Входящие» — и по [inboxNames].
Project? findProject(
  Workspace ws,
  String name, {
  Set<String> inboxNames = const {},
}) {
  final lower = _lower(name);
  final inbox = ws.inbox;
  if (inbox != null &&
      (_lower(inbox.name) == lower ||
          inboxNames.any((n) => _lower(n) == lower))) {
    return inbox;
  }
  for (final item in ws.projectTree(expandCollapsed: true)) {
    if (_lower(item.value.name) == lower) return item.value;
  }
  return null;
}

/// Активный раздел проекта [projectId] с именем [name].
Section? findSection(Workspace ws, String projectId, String name) {
  final lower = _lower(name);
  for (final s in ws.sectionsOf(projectId)) {
    if (_lower(s.name) == lower) return s;
  }
  return null;
}

/// Живая метка с именем [name].
Label? findLabel(Workspace ws, String name) {
  final lower = _lower(name);
  for (final l in ws.labels) {
    if (_lower(l.name) == lower) return l;
  }
  return null;
}

/// Имя в участке токена: без знака `#`, `/`, `%`, `@` и кавычек.
String tokenName(String text, Highlight h) {
  var name = text.substring(h.start + 1, h.end);
  if (name.length >= 2 && name.startsWith('"') && name.endsWith('"')) {
    name = name.substring(1, name.length - 1);
  }
  return name;
}

String _lower(String s) => s.trim().toLowerCase();

Set<String> _lowerSet(Set<String> names) => {for (final n in names) _lower(n)};
