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

  /// Настройки всех видов, которые когда-либо меняли, сейчас и после каждого
  /// изменения: одна подписка на таблицу на всё приложение, а не по запросу на
  /// каждый открытый вид. Вид незнакомого типа (от более новой версии)
  /// пропускается; вида нет в словаре — у него настройки по умолчанию.
  Stream<Map<(ViewType, String?), ViewOptions>> watchAll() => _db
      .select(_db.viewOptions)
      .watch()
      .map(
        (rows) => {
          for (final row in rows)
            if (_typeOf(row.viewType) case final type?)
              (type, row.objectId): _options(type, row.objectId, row),
        },
      );

  static ViewType? _typeOf(String? apiName) {
    for (final type in ViewType.values) {
      if (type.apiName == apiName) return type;
    }
    return null;
  }

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
