import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'drag_slots.dart';

/// Запоминает, где началось перетаскивание, в [DragPayload.startAt]: уровень
/// задачи считается от сдвига указателя, а не от места входа в окно. Образ
/// стоит под указателем (как `pointerDragAnchorStrategy`), а у
/// [AnchoredPayload] — на месте строки.
Offset recordStartAnchor(
  Draggable<Object> draggable,
  BuildContext context,
  Offset position,
) {
  final data = draggable.data;
  if (data is DragPayload) data.startAt = position;
  if (data is AnchoredPayload) {
    final box = context.findRenderObject();
    if (box is RenderBox && box.hasSize) {
      return data.ghostAnchor(box.globalToLocal(position));
    }
  }
  return Offset.zero;
}

/// Состояние указателя мыши с порогом [slop]: жест принимается, когда мышь
/// ушла дальше него.
class _SlopPointerState extends MultiDragPointerState {
  _SlopPointerState(
    super.initialPosition,
    super.kind,
    super.gestureSettings,
    this.slop,
  );

  final double slop;

  @override
  void checkForResolutionAfterMove() {
    if (pendingDelta!.distance > slop) resolve(GestureDisposition.accepted);
  }

  @override
  void accepted(GestureMultiDragStartCallback starter) =>
      starter(initialPosition);
}

/// Распознаватель перетаскивания с порогом [slop] вместо порога мыши: тот
/// равен 1 px, и клик со сдвигом в пару пикселей превращался бы в перенос.
class _SlopDragRecognizer extends ImmediateMultiDragGestureRecognizer {
  _SlopDragRecognizer({
    required this.slop,
    super.supportedDevices,
    super.allowedButtonsFilter,
  });

  final double slop;

  @override
  MultiDragPointerState createNewPointerState(PointerDownEvent event) =>
      _SlopPointerState(event.position, event.kind, gestureSettings, slop);
}

/// Источник перетаскивания мышью: на ручке, сразу после небольшого сдвига
/// (help Todoist: «Click and hold the drag handle beside the task»). Для
/// строки без ручки (проект, метка) [rowDrag] включает порог, равный порогу
/// касания: клик со сдвигом в несколько пикселей остаётся кликом, а стрелка
/// и «⋯» в строке работают. Устройство определяет распознаватель, а не
/// ширина экрана.
class MouseDraggable extends Draggable<DragPayload> {
  const MouseDraggable({
    super.key,
    required super.child,
    required super.feedback,
    super.data,
    this.rowDrag = false,
  }) : super(dragAnchorStrategy: recordStartAnchor, rootOverlay: true);

  /// Тянется вся строка: порог [kTouchSlop], а не порог мыши.
  final bool rowDrag;

  @override
  MultiDragGestureRecognizer createRecognizer(
    GestureMultiDragStartCallback onStart,
  ) => rowDrag
      ? (_SlopDragRecognizer(
          slop: kTouchSlop,
          supportedDevices: const {PointerDeviceKind.mouse},
          allowedButtonsFilter: allowedButtonsFilter,
        )..onStart = onStart)
      : (ImmediateMultiDragGestureRecognizer(
          supportedDevices: const {PointerDeviceKind.mouse},
          allowedButtonsFilter: allowedButtonsFilter,
        )..onStart = onStart);
}

/// Источник перетаскивания касанием: долгое нажатие на всей строке, короткое
/// касание и прокрутка работают как раньше. Касание и стилус; вибрация — при
/// начале, как у Todoist на телефоне.
class TouchDraggable extends LongPressDraggable<DragPayload> {
  const TouchDraggable({
    super.key,
    required super.child,
    required super.feedback,
    super.data,
  }) : super(
         dragAnchorStrategy: recordStartAnchor,
         rootOverlay: true,
         hapticFeedbackOnStart: false,
       );

  @override
  DelayedMultiDragGestureRecognizer createRecognizer(
    GestureMultiDragStartCallback onStart,
  ) =>
      DelayedMultiDragGestureRecognizer(
          delay: delay,
          supportedDevices: const {
            PointerDeviceKind.touch,
            PointerDeviceKind.stylus,
            PointerDeviceKind.invertedStylus,
          },
          allowedButtonsFilter: allowedButtonsFilter,
        )
        ..onStart = (position) {
          final drag = onStart(position);
          if (drag != null) HapticFeedback.selectionClick();
          return drag;
        };
}
