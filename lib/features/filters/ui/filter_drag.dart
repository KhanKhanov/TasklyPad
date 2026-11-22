import 'package:material_ui/material_ui.dart';

import '../../../app/data_providers.dart';
import '../../../domain/models.dart';
import '../../common/ui/flat_drag.dart';

/// Строка фильтра в «Моих фильтрах» с перетаскиванием (help «Introduction to
/// filters»: «drag a filter to a new place in the list»): тянется вся строка,
/// как у метки; плоский список ([FlatDragTile]), перенос —
/// [FilterCommands.reorder], без тоста «Отменить», как у метки.
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

  @override
  Widget build(BuildContext context) => FlatDragTile(
    kind: 'filter',
    id: filter.id,
    title: filter.name,
    order: [for (final f in filters) f.id],
    reorder: (ref, id, {afterId}) =>
        ref.read(filterCommandsProvider).reorder(id, afterId: afterId),
    child: child,
  );
}
