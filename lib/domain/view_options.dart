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

  /// Сколько выбрано сортировок и группировок — «Отображение: N» (help «Sort
  /// or group tasks»: выбранное показывается вверху вида); «Выполненные
  /// задачи» не считаются — «Сбросить всё» их не снимает.
  int get applied =>
      (grouping == Grouping.none ? 0 : 1) + (sorting.hasDirection ? 1 : 0);
}
