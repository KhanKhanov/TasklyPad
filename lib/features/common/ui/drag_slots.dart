import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/drag_session.dart';

/// Что тащат: задачи, а позже проекты, разделы и метки. Приёмник общий и о
/// содержимом не знает — слоты на строках сами решают, их это груз или нет.
abstract interface class DragPayload {
  /// Id перетаскиваемых элементов: их строки бледнеют.
  Set<String> get sources;

  /// Где указатель был в начале перетаскивания; пишет источник
  /// ([recordStartAnchor]) при каждом новом перетаскивании. Уровень задачи
  /// считается от сдвига указателя вправо или влево от этой точки, а не от
  /// абсолютного X, и выход указателя за окно её не меняет.
  Offset? get startAt;
  set startAt(Offset? value);
}

/// Груз, образ которого стоит не под указателем, а на месте строки, за
/// которую взялись: указатель остаётся в той же точке образа, что и строки.
abstract interface class AnchoredPayload implements DragPayload {
  /// Точка образа под указателем, если взялись в точке [grab] источника;
  /// запоминается в [anchor].
  Offset ghostAnchor(Offset grab);

  /// Точка образа под указателем в этом перетаскивании: угол образа плюс она —
  /// сам указатель.
  Offset get anchor;
}

/// Куда бросят и как это показать. Создаётся слотом на каждое движение;
/// пишет в данные только [perform] (через команды, не напрямую).
abstract interface class DropPlace {
  DropIndicator get indicator;

  /// Выполнить бросок: команда с тостом «Отменить». [context] живёт, пока
  /// открыт [DragLayer].
  Future<void> perform(BuildContext context, WidgetRef ref);
}

/// Вопрос слоту: можно ли бросить [payload] под указатель.
final class DropQuery {
  const DropQuery({
    required this.payload,
    required this.pointer,
    required this.start,
  });

  final DragPayload payload;

  /// Положение указателя в окне.
  final Offset pointer;

  /// Где указатель был в начале перетаскивания.
  final Offset start;

  Offset get delta => pointer - start;
}

/// Ответ слота: место броска или `null` — «не моё», и выбор переходит к
/// внешнему слоту.
typedef DropResolver = DropPlace? Function(DropQuery query, RenderBox box);

/// Метка в дереве: «здесь можно бросить». Находится проверкой попадания под
/// указателем, а не событиями `DragTarget` — они приходят только при
/// движении указателя, а при автопрокрутке место под ним меняется само.
final class DropSlot {
  const DropSlot(this.resolve, this.context);

  final DropResolver resolve;

  /// Контекст внутри слота: по нему ищется прокручиваемая область.
  final BuildContext context;
}

/// Делает [child] местом броска: область строки, заголовка, пункта сайдбара.
class DropSlotRegion extends StatelessWidget {
  const DropSlotRegion({super.key, required this.resolve, required this.child});

  final DropResolver resolve;
  final Widget child;

  @override
  Widget build(BuildContext context) => Builder(
    builder: (context) => MetaData(
      metaData: DropSlot(resolve, context),
      behavior: HitTestBehavior.translucent,
      child: child,
    ),
  );
}
