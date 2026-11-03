import 'package:drift/drift.dart';

import '../../domain/view_options.dart';
import '../app_database.dart';
import '../projection/entity_fields.dart';

/// Чтение настроек «Отображения» вида из таблицы-проекции `view_options`.
///
/// Строки нет (настройки ни разу не меняли) или она удалена — настройки по
/// умолчанию. Запись — командами через `Mutator` (M4.5).
final class ViewOptionsRepository {
  ViewOptionsRepository(this._db);

  final AppDatabase _db;

  /// Настройки вида [viewType] объекта [objectId] сейчас.
  Future<ViewOptions> load(ViewType viewType, {String? objectId}) async =>
      _options(
        viewType,
        objectId,
        await _query(viewType, objectId).getSingleOrNull(),
      );

  /// [load] сейчас и после каждого изменения — своего и пришедшего
  /// синхронизацией; одинаковые значения отбрасываются.
  Stream<ViewOptions> watch(ViewType viewType, {String? objectId}) =>
      _query(viewType, objectId)
          .watchSingleOrNull()
          .map((row) => _options(viewType, objectId, row))
          .distinct();

  SimpleSelectStatement<$ViewOptionsTable, ViewOptionsRow> _query(
    ViewType viewType,
    String? objectId,
  ) {
    final id = viewOptionsId(viewType.apiName, objectId);
    return _db.select(_db.viewOptions)..where((t) => t.id.equals(id));
  }

  static ViewOptions _options(
    ViewType viewType,
    String? objectId,
    ViewOptionsRow? row,
  ) => row == null || row.deleted
      ? ViewOptions(viewType: viewType, objectId: objectId)
      : ViewOptions(
          viewType: viewType,
          objectId: objectId,
          grouping: Grouping.fromApi(row.groupedBy),
          sorting: Sorting.fromApi(row.sortedBy),
          sortOrder: SortOrder.fromApi(row.sortOrder),
          showCompletedTasks: row.showCompletedTasks,
        );
}
