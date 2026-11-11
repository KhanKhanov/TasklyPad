import 'package:flutter/widgets.dart';

import '../../../domain/models.dart';
import '../../../domain/tree.dart';
import '../../common/ui/drag_slots.dart';
import 'task_drag.dart';

/// Перетаскиваемые задачи: одна или выделенные вместе.
final class TaskDrag implements AnchoredPayload {
  TaskDrag({
    required this.task,
    required this.depth,
    required this.origin,
    required this._pick,
    this.ghostOrigin = Offset.zero,
    this.measure,
  });

  /// Задача, за которую взялись.
  final Task task;

  /// Её уровень в списке: от него считается уровень после сдвига вбок.
  final int depth;
  final TaskListDrop origin;
  final List<String> Function() _pick;

  /// Где у источника (ручки или строки) начинается образ — кружок строки:
  /// образ встаёт на место строки, а не под указатель.
  final Offset ghostOrigin;

  /// Ширина строки для образа; меряется в начале перетаскивания — во время
  /// жеста, когда размер строки известен, а не при построении образа.
  final double Function()? measure;

  /// Ширина образа ([measure] в начале перетаскивания).
  double? get ghostWidth => _ghostWidth;
  double? _ghostWidth;

  /// Выбираются при первом обращении — в начале перетаскивания, а не при
  /// построении строки: выделение за это время могло измениться.
  late final List<String> ids = _pick();

  Offset? _startAt;
  int _shift = 0;

  /// Каждое новое перетаскивание начинается с прежнего уровня.
  @override
  Offset? get startAt => _startAt;

  @override
  set startAt(Offset? value) {
    _startAt = value;
    _shift = 0;
  }

  @override
  Offset ghostAnchor(Offset grab) {
    _ghostWidth = measure?.call();
    return _anchor = grab - ghostOrigin;
  }

  @override
  Offset get anchor => _anchor;
  Offset _anchor = Offset.zero;

  /// Сдвиг уровня при сдвиге указателя на [dx] от начала: с гистерезисом
  /// ([levelShift]), поэтому помнит прошлый сдвиг этого перетаскивания.
  int indentShift(double dx) =>
      _shift = levelShift(dx: dx, step: taskIndentStep, last: _shift);

  @override
  late final Set<String> sources = ids.toSet();
}

/// Сдвиг уровня с гистерезисом (решение 5А «M4.10a» plans/m4, пороги —
/// уточнение пользователя 12.11.2026): глубже — когда указатель ушёл вправо
/// на 1¼ шага за текущий уровень, выше — влево на шаг (слева у подзадачи мало
/// места до края строки, а за краем место броска теряется); обратно к
/// исходному уровню — вернувшись на ½ шага. Случайный сдвиг мыши подзадачу не
/// делает, а на границе уровень не дрожит. Повторный вызов с тем же [dx] и
/// результатом прошлого как [last] ничего не меняет: за одно движение
/// указателя место считают несколько слотов.
int levelShift({required double dx, required double step, required int last}) {
  const deeper = 1.25;
  const higher = 1.0;
  const back = 0.5;
  final raw = dx / step;
  var shift = last;
  while (true) {
    if (shift >= 0 && raw >= shift + deeper) {
      shift++;
    } else if (shift <= 0 && raw <= shift - higher) {
      shift--;
    } else if (shift > 0 && raw <= shift - back) {
      shift--;
    } else if (shift < 0 && raw >= shift + back) {
      shift++;
    } else {
      return shift;
    }
  }
}

/// Строки списка, которые в перетаскивании не участвуют: выполненные и всё
/// поддерево выполненной (активная подзадача выполненной остаётся внутри неё:
/// её не взять и между ней и родителем линии нет).
Set<String> frozenIds(List<TreeItem<Task>> items) {
  final frozen = <String>{};
  int? under;
  for (final item in items) {
    if (under != null && item.depth > under) {
      frozen.add(item.value.id);
      continue;
    }
    under = null;
    if (item.value.isCompleted) {
      frozen.add(item.value.id);
      under = item.depth;
    }
  }
  return frozen;
}
