import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/data_providers.dart';
import '../../../domain/models.dart';
import '../../common/state/drag_session.dart';
import '../../common/ui/drag_layer.dart';
import '../../common/ui/drag_source.dart';
import '../../common/ui/ui_kit.dart';

/// Перетаскиваемая метка.
final class LabelDrag implements DragPayload {
  LabelDrag(this.label);

  final Label label;

  @override
  Offset? startAt;

  @override
  Set<String> get sources => {label.id};
}

/// Бросок метки: после [afterId] (`null` — первой) в плоском списке
/// ([LabelCommands.reorder]). Без тоста «Отменить» (решение 8 плана M4).
final class ReorderLabelPlace implements DropPlace {
  const ReorderLabelPlace({
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
    () => ref.read(labelCommandsProvider).reorder(id, afterId: afterId),
  );
}

/// Строка метки на странице «Фильтры и метки» с перетаскиванием: тянется вся
/// строка, без ручки (порядок меток перетаскиванием в help не описан —
/// допущение, О-69), мышью после небольшого сдвига и касанием после долгого
/// нажатия. Список плоский, уровней нет: линия до или после строки.
///
/// [labels] — все метки по порядку страницы.
class LabelDragTile extends StatelessWidget {
  const LabelDragTile({
    super.key,
    required this.label,
    required this.labels,
    required this.child,
  });

  final Label label;
  final List<Label> labels;
  final Widget child;

  DropPlace? _resolve(DropQuery query, RenderBox box) {
    final payload = query.payload;
    if (payload is! LabelDrag) return null;
    final dragged = payload.label.id;
    final upper = box.globalToLocal(query.pointer).dy < box.size.height / 2;
    final others = [
      for (final l in labels)
        if (l.id != dragged) l,
    ];
    if (label.id == dragged) return null;
    final at = others.indexWhere((l) => l.id == label.id);
    if (at < 0) return null;
    // Над строкой — перед ней, под строкой — после неё.
    return ReorderLabelPlace(
      id: dragged,
      afterId: upper ? (at == 0 ? null : others[at - 1].id) : label.id,
      indicator: DropIndicator(
        owner: 'label:${label.id}',
        mark: upper ? DropMark.above : DropMark.below,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final payload = LabelDrag(label);
    final ghost = DragGhost(title: label.name, payload: payload);
    return DropMarker(
      owner: 'label:${label.id}',
      child: DropSlotRegion(
        resolve: _resolve,
        child: DragSourceDim(
          id: label.id,
          child: MouseDraggable(
            data: payload,
            feedback: ghost,
            rowDrag: true,
            child: TouchDraggable(
              data: payload,
              feedback: ghost,
              child: DragBlocker(child: child),
            ),
          ),
        ),
      ),
    );
  }
}
