import '../../../data/projection/entity_fields.dart';
import '../../../domain/view_options.dart';
import '../../../sync/mutator.dart';

/// Сохранение «Отображения» вида (решения 1 и 2 плана M4): одна сущность
/// `view_options` на вид с детерминированным id, поля — как в Todoist API.
/// Тип молчащий: спор двух устройств о виде списка решает LWW по полю, без
/// карточки конфликта.
final class ViewOptionsCommands {
  ViewOptionsCommands({required this._mutator, required this._read});

  final Mutator _mutator;
  final Future<ViewOptions> Function(ViewType viewType, {String? objectId})
  _read;

  /// Записать [next] поверх [from] — настроек, которые пользователь видел,
  /// когда менял: пишутся только изменённые им поля, и правка другого поля
  /// на другом устройстве остаётся. Сортировку без направления («Вручную»
  /// или порядок вида) пользователь выбрал — пишется «по возрастанию» (help
  /// «Sort or group tasks»: меню направления скрывается). Сортировку и
  /// направление не трогал — направление не пишется: оно может быть от
  /// незнакомой этой версии сортировки другого устройства.
  Future<void> save(ViewOptions from, ViewOptions next) async {
    if ((from.viewType, from.objectId) != (next.viewType, next.objectId)) {
      throw ArgumentError.value(next, 'next', 'настройки другого вида');
    }
    final sortingTouched =
        next.sorting != from.sorting || next.sortOrder != from.sortOrder;
    final order = sortingTouched && !next.sorting.hasDirection
        ? SortOrder.asc
        : next.sortOrder;
    final fields = <String, Object?>{
      if (next.grouping != from.grouping)
        ViewOptionsFields.groupedBy: next.grouping.apiName,
      if (next.sorting != from.sorting)
        ViewOptionsFields.sortedBy: next.sorting.apiName,
      if (order != from.sortOrder) ViewOptionsFields.sortOrder: order.apiName,
      if (next.showCompletedTasks != from.showCompletedTasks)
        ViewOptionsFields.showCompletedTasks: next.showCompletedTasks,
    };
    // Пустая правка — без `Mutator.update`: он будит синхронизацию.
    if (fields.isEmpty) return;
    // Вид и объект пишутся вместе с первой правкой: у известной сущности
    // `Mutator.update` отбросит их как неизменённые.
    await _mutator.update(
      EntityTypes.viewOptions,
      viewOptionsId(next.viewType.apiName, next.objectId),
      {
        ViewOptionsFields.viewType: next.viewType.apiName,
        ViewOptionsFields.objectId: ?next.objectId,
        ...fields,
      },
    );
  }

  /// «Сбросить всё» — без сортировки и группировки (help «Sort or group
  /// tasks»: «To remove all sorting and grouping options … select Reset
  /// all»); «Выполненные задачи» остаются как были.
  Future<void> resetAll(ViewOptions from) => save(
    from,
    from.copyWith(
      grouping: Grouping.none,
      sorting: Sorting.byDefault,
      sortOrder: SortOrder.asc,
    ),
  );

  /// Настройки проекта [sourceId] — копии [copyId] (дубликат проекта, help
  /// «Introduction to projects»): пишутся поля, отличные от умолчаний.
  Future<void> copyProject(String sourceId, String copyId) async {
    final source = await _read(ViewType.project, objectId: sourceId);
    await save(
      ViewOptions(viewType: ViewType.project, objectId: copyId),
      source.copyWith(objectId: copyId),
    );
  }
}
