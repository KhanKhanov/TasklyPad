import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/data_providers.dart';
import '../../../domain/models.dart';
import '../../common/state/drag_session.dart';
import '../../common/ui/drag_layer.dart';
import '../../common/ui/drag_rows.dart';
import '../../common/ui/ui_kit.dart';

/// Перетаскиваемый фильтр.
final class FilterDrag implements DragPayload {
  FilterDrag(this.filter);

  final SavedFilter filter;

  @override
  Offset? startAt;

  @override
  Set<String> get sources => {filter.id};
}

/// Бросок фильтра: после [afterId] (`null` — первым) в «Моих фильтрах»
/// ([FilterCommands.reorder]). Без тоста «Отменить», как у метки.
final class ReorderFilterPlace implements DropPlace {
  const ReorderFilterPlace({
    required this.id,
    required this.afterId,
    required this.indicator,
  });

  final String id;
  final String? afterId;

  @override
  final DropIndicator indicator;

  @override
  Future<void> perform(BuildContext context, WidgetRef ref) => runCommand(
    context,
    () => ref.read(filterCommandsProvider).reorder(id, afterId: afterId),
  );
}

/// Строка фильтра в «Моих фильтрах» с перетаскиванием (help «Introduction to
/// filters»: «drag a filter to a new place in the list»): тянется вся строка,
/// как у метки. Список плоский: линия до или после строки.
///
/// [filters] — все фильтры по порядку страницы.
class FilterDragTile extends StatelessWidget {
  const FilterDragTile({
    super.key,
    required this.filter,
    required this.filters,
    required this.child,
  });

  final SavedFilter filter;
  final List<SavedFilter> filters;
  final Widget child;

  DropPlace? _resolve(DropQuery query, RenderBox box) {
    final payload = query.payload;
    if (payload is! FilterDrag) return null;
    final dragged = payload.filter.id;
    final upper = box.globalToLocal(query.pointer).dy < box.size.height / 2;
    if (filter.id == dragged) return null;
    final row = filters.indexWhere((f) => f.id == filter.id);
    if (row < 0) return null;
    bool keeps(SavedFilter f) => f.id != dragged;
    // Над строкой — перед ней, под строкой — после неё.
    return ReorderFilterPlace(
      id: dragged,
      afterId: afterIdAt([
        for (final f in filters.where(keeps)) f.id,
      ], dropIndex(filters, row, upper: upper, keeps: keeps)),
      indicator: DropIndicator(
        owner: 'filter:${filter.id}',
        mark: upper ? DropMark.above : DropMark.below,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => WholeRowDrag(
    owner: 'filter:${filter.id}',
    resolve: _resolve,
    id: filter.id,
    payload: FilterDrag(filter),
    title: filter.name,
    child: child,
  );
}
