import 'package:material_ui/material_ui.dart';

import '../../../app/data_providers.dart';
import '../../../domain/models.dart';
import '../../common/ui/flat_drag.dart';

/// Строка метки на странице «Фильтры и метки» с перетаскиванием: тянется вся
/// строка, без ручки (порядок меток перетаскиванием в help не описан —
/// допущение, О-69), мышью после небольшого сдвига и касанием после долгого
/// нажатия. Список плоский, уровней нет: линия до или после строки
/// ([FlatDragTile]); перенос — [LabelCommands.reorder], без тоста «Отменить»
/// (решение 8 плана M4).
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

  @override
  Widget build(BuildContext context) => FlatDragTile(
    kind: 'label',
    id: label.id,
    title: label.name,
    order: [for (final l in labels) l.id],
    reorder: (ref, id, {afterId}) =>
        ref.read(labelCommandsProvider).reorder(id, afterId: afterId),
    child: child,
  );
}
