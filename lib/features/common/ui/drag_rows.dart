import 'package:flutter/material.dart';

import '../state/drag_session.dart';
import 'drag_layer.dart';
import 'drag_source.dart';

// Общее у строк, которые перетаскивают: поле под ручку, место броска с его
// линией, строка, которую тянут целиком, и расчёт места в списке (О-82).

/// Поле слева от строки под ручку перетаскивания (задачи, разделы).
const double dragGutter = 20;

/// Сдвиг вправо на [dragGutter] у того, что стоит рядом со строками в списке
/// с полем под ручку: заголовки, «Добавить раздел», «Пусто».
class DragGutter extends StatelessWidget {
  const DragGutter({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: dragGutter),
    child: child,
  );
}

/// Место броска [child]: слот [resolve] решает, чей груз и куда он встанет, а
/// линию или рамку рисует, если место принадлежит [owner].
class DropArea extends StatelessWidget {
  const DropArea({
    super.key,
    required this.owner,
    required this.resolve,
    required this.child,
  });

  final Object owner;
  final DropResolver resolve;
  final Widget child;

  @override
  Widget build(BuildContext context) => DropMarker(
    owner: owner,
    child: DropSlotRegion(resolve: resolve, child: child),
  );
}

/// Строка, которую тянут целиком, без ручки (проекты, метки): мышью после
/// небольшого сдвига, касанием после долгого нажатия; клик и короткое касание
/// работают как у строки без перетаскивания. Строка же — место броска ([DropArea]); пока её тащат,
/// она бледнеет, а пока тащат что-то, [child] не получает указатель.
class WholeRowDrag extends StatelessWidget {
  const WholeRowDrag({
    super.key,
    required this.owner,
    required this.resolve,
    required this.id,
    required this.payload,
    required this.title,
    required this.child,
  });

  final Object owner;
  final DropResolver resolve;

  /// Id строки: её бледнит [DragSourceDim].
  final String id;
  final DragPayload payload;

  /// Название в образе под указателем.
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ghost = DragGhost(title: title, payload: payload);
    return DropArea(
      owner: owner,
      resolve: resolve,
      child: DragSourceDim(
        id: id,
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
    );
  }
}

/// Сколько строк из [rows] до [row]-й, которые [keeps] оставляет, стоит перед
/// местом броска: в верхней половине строки ([upper]) — место перед ней, в
/// нижней — после.
int dropIndex<T>(
  Iterable<T> rows,
  int row, {
  required bool upper,
  required bool Function(T row) keeps,
}) => rows.take(row + (upper ? 0 : 1)).where(keeps).length;

/// Линия места «перед [index]-й» из [shown]: под предыдущей строкой, а у
/// первой — над ней; [endOwner] — список пуст. Без [endOwner] — только
/// непустой [shown].
DropIndicator lineBefore(
  List<Object> shown,
  int index, {
  Object? endOwner,
  double indent = 0,
}) {
  assert(shown.isNotEmpty || endOwner != null, 'пустой список без endOwner');
  if (index > 0) {
    return DropIndicator(
      owner: shown[index - 1],
      mark: DropMark.below,
      indent: indent,
    );
  }
  return DropIndicator(
    owner: shown.isEmpty ? endOwner! : shown.first,
    mark: DropMark.above,
    indent: indent,
  );
}

/// В плоском списке [others] (без перетаскиваемого) — после кого встанет
/// элемент, поставленный перед [index]-й строкой; `null` — первым.
String? afterIdAt(List<String> others, int index) =>
    index == 0 ? null : others[index - 1];
