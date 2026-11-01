import 'package:flutter/material.dart';

import '../../../app/theme/app_palette.dart';
import '../../../core/clock.dart';
import '../../../domain/models.dart';
import '../../../domain/workspace.dart';
import '../../../nlp/parse_context.dart';
import '../../../nlp/quick_add.dart';
import '../../../nlp/scanner.dart';
import '../logic/quick_add_draft.dart';
import '../logic/spans.dart';
import '../logic/suggestions.dart';
import 'edit_range.dart';

/// Черновик быстрого добавления — поле названия вместе с разбором: текст,
/// участки, разбор которых пользователь отменил, выбор «Создать …» в
/// автодополнении и значения чипов. Подсветку рисует [buildTextSpan].
///
/// Это состояние одного открытого редактора, как у любого
/// `TextEditingController`, поэтому не провайдер; правила разбора и
/// сопоставления имён — в lib/features/quick_add/logic.
class QuickAddController extends TextEditingController {
  QuickAddController({required this._defaults});

  QuickAddDefaults _defaults;
  Workspace? _ws;
  AppClock? _clock;
  String _lang = 'ru';
  bool _smartDates = true;
  Set<String> _inboxNames = const {};

  List<Span> _dismissed = const [];
  final Set<String> _pendingProjects = {};
  final Set<String> _pendingLabels = {};
  ChipChoices _chips = const ChipChoices();
  ResolvedQuickAdd? _resolved;

  /// Данные и настройки разбора; вызывается при каждой сборке редактора —
  /// разбор повторяется, только если что-то изменилось.
  void configure({
    required Workspace ws,
    required AppClock clock,
    required String lang,
    required bool smartDates,
    required Set<String> inboxNames,
    required QuickAddDefaults defaults,
  }) {
    if (identical(ws, _ws) &&
        lang == _lang &&
        smartDates == _smartDates &&
        identical(defaults, _defaults) &&
        _resolved != null) {
      return;
    }
    _ws = ws;
    _clock = clock;
    _lang = ParseContext.supportedLanguages.contains(lang) ? lang : 'ru';
    _smartDates = smartDates;
    _inboxNames = inboxNames;
    _defaults = defaults;
    _resolved = _resolve(text, _dismissed);
  }

  QuickAddDefaults get defaults => _defaults;
  ChipChoices get chips => _chips;
  Workspace? get workspace => _ws;

  /// Подсвеченные участки текущего текста.
  List<Highlight> get highlights =>
      _resolved?.result.highlights ?? const <Highlight>[];

  /// Задача по текущему тексту и чипам; `null` — снимка данных ещё нет.
  TaskDraft? get draft => _resolved?.draft;

  QuickAddResolver? get resolver => _ws == null
      ? null
      : QuickAddResolver(
          ws: _ws!,
          defaults: _defaults,
          inboxNames: _inboxNames,
        );

  @override
  set value(TextEditingValue newValue) {
    final old = value;
    final dismissed = _dismissOnDelete(old, newValue);
    if (dismissed != null) {
      _dismiss(dismissed);
      return;
    }
    _dismissed = shiftSpans(
      _dismissed,
      old.text,
      newValue.text,
      changed: editRange(old, newValue),
    );
    _resolved = _resolve(newValue.text, _dismissed);
    _forgetPending(newValue.text);
    super.value = newValue;
  }

  /// Имя из «Создать», токена которого в тексте больше нет, забывается:
  /// набранное заново без «Создать» снова только текст (решение 1А).
  void _forgetPending(String text) {
    final names = {
      for (final h in highlights)
        if (h.kind == HighlightKind.project || h.kind == HighlightKind.label)
          tokenName(text, h).toLowerCase(),
    };
    _pendingProjects.removeWhere((n) => !names.contains(n.toLowerCase()));
    _pendingLabels.removeWhere((n) => !names.contains(n.toLowerCase()));
  }

  /// Разобрать текст заново — перед записью: «завтра», набранное до
  /// полуночи, после неё — уже другой день.
  void refresh() => _resolved = _resolve(text, _dismissed);

  /// Help «Turn smart date recognition on or off»: Backspace сразу после
  /// распознанной даты (Delete — перед ней) превращает её в текст, а не
  /// стирает знак. Участок даты или `null` — правка обычная.
  Span? _dismissOnDelete(TextEditingValue old, TextEditingValue next) {
    final cursor = old.selection;
    // Пока IME собирает слово, подсветки на экране нет ([buildTextSpan]) —
    // Backspace стирает знак, как обычно.
    if (old.composing.isValid ||
        !cursor.isCollapsed ||
        next.text.length != old.text.length - 1) {
      return null;
    }
    final c = cursor.baseOffset;
    for (final h in highlights) {
      if (h.kind != HighlightKind.due) continue;
      final backspace =
          h.end == c &&
          c > 0 &&
          next.text == old.text.replaceRange(c - 1, c, '') &&
          next.selection.baseOffset == c - 1;
      final delete =
          h.start == c &&
          c < old.text.length &&
          next.text == old.text.replaceRange(c, c + 1, '');
      if (backspace || delete) return h.span;
    }
    return null;
  }

  /// Подсветка под позицией [offset] (знак внутри участка) или `null`.
  Highlight? highlightAt(int offset) {
    for (final h in highlights) {
      if (h.start <= offset && offset < h.end) return h;
    }
    return null;
  }

  /// Клик по подсветке: участок остаётся текстом названия.
  void dismissAt(int offset) {
    final h = highlightAt(offset);
    if (h != null) _dismiss(h.span);
  }

  void _dismiss(Span span) {
    _dismissed = [..._dismissed, span];
    _resolved = _resolve(text, _dismissed);
    notifyListeners();
  }

  /// Пункт автодополнения [s] встаёт на место набранного токена [q]; после
  /// него — пробел. «Создать …» запоминает имя: проект или метка
  /// создаются вместе с задачей (решение 1А «Ход M3.6»).
  void applySuggestion(TokenQuery q, Suggestion s) {
    if (s.create) {
      (q.kind == TokenKind.project ? _pendingProjects : _pendingLabels).add(
        s.name,
      );
    }
    final rest = text.substring(q.end);
    final gap = rest.startsWith(' ') ? '' : ' ';
    final next = text.replaceRange(q.start, q.end, '${s.insert}$gap');
    final cursor = q.start + s.insert.length + 1;
    value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: cursor),
    );
  }

  /// Выбор чипом: значение чипа действует, а распознанный участок того же
  /// поля уходит из текста (решение 4А «Ход M3.6»).
  void pickDue(Due? due) =>
      _pick(_chips.copyWith(due: (due: due)), {HighlightKind.due});

  void pickPriority(int priority) =>
      _pick(_chips.copyWith(priority: priority), {HighlightKind.priority});

  /// Метки из «Создать» в выборе меток не видны — их токены остаются.
  void pickLabels(Set<String> labelIds) => _pick(
    _chips.copyWith(labelIds: labelIds),
    {HighlightKind.label},
    keep: (h) => _pendingLabels.any(
      (n) => n.toLowerCase() == tokenName(text, h).toLowerCase(),
    ),
  );

  void pickDeadline(String? date) =>
      _pick(_chips.copyWith(deadline: (date: date)), {HighlightKind.deadline});

  void pickPlace(String projectId, String? sectionId) => _pick(
    _chips.copyWith(place: (projectId: projectId, sectionId: sectionId)),
    {HighlightKind.project, HighlightKind.section},
  );

  void _pick(
    ChipChoices chips,
    Set<HighlightKind> kinds, {
    bool Function(Highlight)? keep,
  }) {
    _chips = chips;
    final cut = [
      for (final h in highlights)
        if (kinds.contains(h.kind) && !(keep?.call(h) ?? false)) h.span,
    ];
    final removed = removeSpans(text, cut, dismissed: _dismissed);
    _dismissed = removed.dismissed;
    _resolved = _resolve(removed.text, _dismissed);
    _forgetPending(removed.text);
    super.value = TextEditingValue(
      text: removed.text,
      selection: TextSelection.collapsed(offset: removed.text.length),
    );
  }

  /// Задачи из вставленных строк [lines] (решение 3А «Ход M3.6»): каждая
  /// строка разбирается сама, а чего в ней нет — берётся из окна (чипы и
  /// токены, набранные до вставки).
  List<TaskDraft> draftsForLines(List<String> lines) {
    final base = draft;
    final resolver = this.resolver;
    if (base == null || resolver == null) return const [];
    final chips = ChipChoices(
      // Срока в окне нет — не «Без срока»: строка с `15:00-16:00` получит
      // срок из своего отрезка, как набранная вручную.
      due: _chips.due ?? (base.due == null ? null : (due: base.due)),
      priority: base.priority,
      labelIds: base.labelIds,
      deadline: (date: base.deadline),
      place: base.projectId == null
          ? null
          : (projectId: base.projectId!, sectionId: base.sectionId),
    );
    // Строка из одних токенов (`p1`) задачи не даёт — пропускается, а не
    // отменяет всю вставку отказом «пустое название».
    return [
      for (final line in lines)
        _withBase(
          resolver.resolve(
            line,
            _context(),
            smartDates: _smartDates,
            chips: chips,
            pendingProjects: _pendingProjects,
            pendingLabels: _pendingLabels,
          ),
          base,
        ),
    ].where((d) => d.title.trim().isNotEmpty).toList();
  }

  /// Новые проект и метки из текста окна переходят к строке, если своего
  /// проекта в ней нет.
  TaskDraft _withBase(ResolvedQuickAdd line, TaskDraft base) {
    final d = line.draft;
    final inherit = line.result.project == null && base.newProject != null;
    return TaskDraft(
      title: d.title,
      description: d.description,
      projectId: inherit ? null : d.projectId,
      newProject: inherit ? base.newProject : d.newProject,
      sectionId: inherit ? null : d.sectionId,
      parentId: d.parentId,
      labelIds: d.labelIds,
      newLabels: {...base.newLabels, ...d.newLabels}.toList(),
      priority: d.priority,
      due: d.due,
      deadline: d.deadline,
      duration: d.duration,
    );
  }

  /// Пустой черновик для следующей задачи; место и метки экрана остаются.
  void reset() {
    _dismissed = const [];
    _pendingProjects.clear();
    _pendingLabels.clear();
    _chips = const ChipChoices();
    _resolved = _resolve('', const []);
    super.value = TextEditingValue.empty;
  }

  ParseContext _context() => ParseContext(now: _clock!.nowWall(), lang: _lang);

  ResolvedQuickAdd? _resolve(String text, List<Span> dismissed) =>
      resolver?.resolve(
        text,
        _context(),
        dismissed: dismissed,
        smartDates: _smartDates,
        chips: _chips,
        pendingProjects: _pendingProjects,
        pendingLabels: _pendingLabels,
      );

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    // Пока IME собирает слово (подчёркнутый набор), рисует Flutter: иначе
    // сломалось бы подчёркивание набора.
    if (withComposing && value.isComposingRangeValid || highlights.isEmpty) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    final palette = AppPalette.of(context);
    final marked = style?.merge(
      TextStyle(
        color: palette.accent,
        backgroundColor: palette.accent.withValues(alpha: 0.14),
      ),
    );
    final children = <TextSpan>[];
    var at = 0;
    for (final h in highlights) {
      if (h.start < at || h.end > text.length) continue;
      if (h.start > at) {
        children.add(TextSpan(text: text.substring(at, h.start)));
      }
      children.add(
        TextSpan(text: text.substring(h.start, h.end), style: marked),
      );
      at = h.end;
    }
    if (at < text.length) children.add(TextSpan(text: text.substring(at)));
    return TextSpan(style: style, children: children);
  }
}
