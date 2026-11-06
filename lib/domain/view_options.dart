import 'package:freezed_annotation/freezed_annotation.dart';

part 'view_options.freezed.dart';

// Настройки вида («Отображение») — help «Sort or group tasks», значения
// полей — как у `view_options` Todoist API (решения 1 и 2 плана M4).
// Значение, которого эта версия не знает (группировка `assignee` от более
// новой версии или из импорта), читается как значение по умолчанию; само
// оно остаётся в журнале.

/// Вид, у которого есть «Отображение». «Входящие» — [project].
enum ViewType {
  today('today'),
  upcoming('upcoming'),
  project('project'),
  label('label'),
  filter('filter');

  const ViewType(this.apiName);

  /// Значение `view_type` в Todoist API.
  final String apiName;
}

/// Группировка задач вида.
enum Grouping {
  /// Без группировки — `grouped_by` нет.
  none(null),
  dueDate('due_date'),
  addedDate('added_date'),
  deadline('deadline'),
  priority('priority'),
  label('label'),

  /// По проекту — только вне проекта.
  project('project');

  const Grouping(this.apiName);

  /// Значение `grouped_by` в Todoist API; `null` — поля нет.
  final String? apiName;

  /// Группировка по значению API; незнакомое и `null` — [none].
  static Grouping fromApi(String? value) =>
      values.firstWhere((g) => g.apiName == value, orElse: () => none);
}

/// Сортировка задач вида.
enum Sorting {
  /// Порядок вида по умолчанию — `sorted_by` нет: в проекте — ручной, в
  /// «Сегодня» и «Предстоящем» — умный с ручным порядком дня, у метки —
  /// help «Default sorting order».
  byDefault(null),
  manual('manual'),

  /// По имени.
  alphabetically('alphabetically'),
  dueDate('due_date'),
  addedDate('added_date'),
  deadline('deadline'),
  priority('priority');

  const Sorting(this.apiName);

  /// Значение `sorted_by` в Todoist API; `null` — поля нет.
  final String? apiName;

  /// У сортировки есть направление: у «Вручную» и порядка вида его нет
  /// (help «Sort or group tasks»: меню направления скрывается).
  bool get hasDirection => this != byDefault && this != manual;

  /// Сортировка по значению API; незнакомое и `null` — [byDefault].
  static Sorting fromApi(String? value) =>
      values.firstWhere((s) => s.apiName == value, orElse: () => byDefault);
}

/// Направление сортировки.
enum SortOrder {
  asc('asc'),
  desc('desc');

  const SortOrder(this.apiName);

  /// Значение `sort_order` в Todoist API.
  final String apiName;

  /// Направление по значению API; незнакомое и `null` — [asc].
  static SortOrder fromApi(String? value) => value == desc.apiName ? desc : asc;
}

/// Настройки «Отображения» одного вида; поля по умолчанию — как у вида, где
/// настройки ни разу не меняли.
@freezed
abstract class ViewOptions with _$ViewOptions {
  const factory ViewOptions({
    required ViewType viewType,

    /// Id проекта, метки или фильтра; у «Сегодня» и «Предстоящего» — `null`.
    String? objectId,
    @Default(Grouping.none) Grouping grouping,
    @Default(Sorting.byDefault) Sorting sorting,
    @Default(SortOrder.asc) SortOrder sortOrder,

    /// «Выполненные задачи» в списке вида.
    @Default(false) bool showCompletedTasks,
  }) = _ViewOptions;

  const ViewOptions._();

  /// Задачи вида можно перетаскивать: не метка и не фильтр, нет группировки
  /// и сортировки с направлением (help «Sort or group tasks»: «If a grouping
  /// option is applied to a project or view, you can't drag or manually
  /// reorder»; «Filter and label views ... can't be manually reordered»). У
  /// «Предстоящего» группировка не действует (из импорта), как и в [applied].
  bool get allowsDrag =>
      viewType != ViewType.label &&
      viewType != ViewType.filter &&
      (grouping == Grouping.none || viewType == ViewType.upcoming) &&
      !sorting.hasDirection;

  /// Сколько выбрано сортировок и группировок — «Отображение: N» (help «Sort
  /// or group tasks»: выбранное показывается вверху вида); «Выполненные
  /// задачи» не считаются — «Сбросить всё» их не снимает. У «Предстоящего»
  /// группировки нет (help «Customize views»): пришедшая импортом не
  /// действует и не считается.
  int get applied =>
      (grouping == Grouping.none || viewType == ViewType.upcoming ? 0 : 1) +
      (sortingChosen ? 1 : 0);

  /// Выбрана сортировка, отличная от порядка вида по умолчанию. «Вручную» —
  /// выбор только в «Сегодня» и «Предстоящем», где по умолчанию умный порядок
  /// (help «Default sorting order»); в проекте «Вручную» и есть умолчание, у
  /// метки и фильтра её нет.
  bool get sortingChosen =>
      sorting.hasDirection ||
      (sorting == Sorting.manual &&
          (viewType == ViewType.today || viewType == ViewType.upcoming));
}
