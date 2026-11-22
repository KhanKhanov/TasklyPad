import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/drag_session.dart';
import 'drag_layer.dart';
import 'drag_rows.dart';
import 'ui_kit.dart';

// Плоский список, который переставляют перетаскиванием (фильтры и метки на
// странице «Фильтры и метки», О-100): строка тянется целиком, уровней нет,
// линия броска — до или после строки, без тоста «Отменить».

/// Перенос [id] сразу после [afterId] (`null` — первым) — команда списка.
typedef FlatReorder = Future<void> Function(
  WidgetRef ref,
  String id, {
  String? afterId,
});

/// Перетаскиваемая строка плоского списка вида [kind] (`filter`, `label`):
/// груз чужого вида список не принимает.
final class FlatDrag implements DragPayload {
  FlatDrag(this.kind, this.id);

  final String kind;
  final String id;

  @override
  Offset? startAt;

  @override
  Set<String> get sources => {id};
}

/// Бросок строки [id] после [afterId] (`null` — первой) командой [reorder].
final class FlatReorderPlace implements DropPlace {
  const FlatReorderPlace({
    required this.id,
    required this.afterId,
    required this.reorder,
    required this.indicator,
  });

  final String id;
  final String? afterId;
  final FlatReorder reorder;

  @override
  final DropIndicator indicator;

  @override
  Future<void> perform(BuildContext context, WidgetRef ref) =>
      runCommand(context, () => reorder(ref, id, afterId: afterId));
}

/// Строка [id] плоского списка вида [kind] с перетаскиванием: тянется вся
/// строка ([WholeRowDrag]), над серединой строки — место перед ней, под
/// серединой — после. [order] — id всех строк по порядку страницы, [title] —
/// название в образе под указателем, [reorder] — команда переноса.
class FlatDragTile extends StatelessWidget {
  const FlatDragTile({
    super.key,
    required this.kind,
    required this.id,
    required this.title,
    required this.order,
    required this.reorder,
    required this.child,
  });

  final String kind;
  final String id;
  final String title;
  final List<String> order;
  final FlatReorder reorder;
  final Widget child;

  /// Владелец линии броска: `<вид>:<id>`.
  String get _owner => '$kind:$id';

  DropPlace? _resolve(DropQuery query, RenderBox box) {
    final payload = query.payload;
    if (payload is! FlatDrag || payload.kind != kind) return null;
    final dragged = payload.id;
    final upper = box.globalToLocal(query.pointer).dy < box.size.height / 2;
    if (id == dragged) return null;
    final row = order.indexOf(id);
    if (row < 0) return null;
    bool keeps(String other) => other != dragged;
    return FlatReorderPlace(
      id: dragged,
      afterId: afterIdAt(
        order.where(keeps).toList(),
        dropIndex(order, row, upper: upper, keeps: keeps),
      ),
      reorder: reorder,
      indicator: DropIndicator(
        owner: _owner,
        mark: upper ? DropMark.above : DropMark.below,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => WholeRowDrag(
    owner: _owner,
    resolve: _resolve,
    id: id,
    payload: FlatDrag(kind, id),
    title: title,
    child: child,
  );
}
