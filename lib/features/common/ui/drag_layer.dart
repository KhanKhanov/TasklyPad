import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/drag_session.dart';
import 'drag_slots.dart';

export 'drag_slots.dart';

/// Один приёмник перетаскивания на окно (оболочка приложения) и на окно
/// задачи: ведёт сессию [dragSessionProvider], ищет слот под указателем на
/// каждое движение, на каждый шаг автопрокрутки и в момент броска.
///
/// Автопрокрутка своя, а не `EdgeDraggingAutoScroller`: тот двигает область
/// через `animateTo`, а пока идёт такая анимация, `Scrollable` не пропускает
/// указатель к содержимому — проверка попадания не видела бы ни одного слота.
/// Здесь область сдвигается `jumpTo` по тику кадра.
///
/// [hitRoot] — виджет, внутри которого ищутся слоты (содержимое окна без
/// нижнего уведомления): `Scaffold` ставит тост поверх содержимого, и тот
/// перехватил бы попадание — бросок под видимым тостом пропадал бы. Без него
/// проверка идёт по всему окну.
class DragLayer extends ConsumerStatefulWidget {
  const DragLayer({super.key, required this.child, this.hitRoot});

  final Widget child;
  final GlobalKey? hitRoot;

  @override
  ConsumerState<DragLayer> createState() => _DragLayerState();
}

class _DragLayerState extends ConsumerState<DragLayer>
    with SingleTickerProviderStateMixin {
  /// Расстояние от края области, на котором начинается автопрокрутка.
  static const double _edge = 40;

  /// Предельная скорость автопрокрутки, пикселей в секунду.
  static const double _maxSpeed = 900;

  DragPayload? _payload;
  Offset? _pointer;
  bool _active = false;

  /// Общий маршрут указателя добавлен ([PointerRouter] не терпит снятия
  /// чужого маршрута).
  bool _routed = false;
  ScrollableState? _scrollable;
  late final Ticker _ticker = createTicker(_onTick);
  Duration _lastTick = Duration.zero;

  /// Позиция прокрутки, за которой следим: место под неподвижным
  /// указателем пересчитывается после каждого её шага.
  ScrollPosition? _watched;
  bool _refreshQueued = false;
  late final DragSession _session;

  @override
  void initState() {
    super.initState();
    // Берётся сразу: в `dispose` читать провайдеры уже нельзя.
    _session = ref.read(dragSessionProvider.notifier);
  }

  @override
  void dispose() {
    _unroute();
    _watched?.removeListener(_onScrollStep);
    _ticker.dispose();
    // Слой снят посреди перетаскивания: сессию нужно закрыть, но состояние
    // нельзя менять, пока дерево разбирается.
    if (_active) Future.microtask(_session.clearIfMounted);
    _active = false;
    super.dispose();
  }

  /// Первое попавшееся место под указателем: слот, чей ответ не `null`.
  DropPlace? _place() {
    final payload = _payload;
    final pointer = _pointer;
    if (payload == null || pointer == null) return null;
    final root = widget.hitRoot?.currentContext?.findRenderObject();
    final HitTestResult result;
    if (root is RenderBox && root.attached && root.hasSize) {
      final inRoot = BoxHitTestResult();
      root.hitTest(inRoot, position: root.globalToLocal(pointer));
      result = inRoot;
    } else {
      result = HitTestResult();
      WidgetsBinding.instance.hitTestInView(
        result,
        pointer,
        View.of(context).viewId,
      );
    }
    final query = DropQuery(
      payload: payload,
      pointer: pointer,
      start: payload.startAt ?? pointer,
    );
    for (final entry in result.path) {
      final target = entry.target;
      if (target is! RenderMetaData || target.metaData is! DropSlot) continue;
      final slot = target.metaData as DropSlot;
      if (slot.context.mounted) {
        _scrollable =
            Scrollable.maybeOf(slot.context, axis: Axis.vertical) ??
            _scrollable;
      }
      final place = slot.resolve(query, target);
      if (place != null) return place;
    }
    return null;
  }

  void _refresh() {
    final payload = _payload;
    if (payload == null) return;
    _session.update(payload.sources, _place()?.indicator);
  }

  /// Указатель идёт над слоем: начало перетаскивания или его продолжение.
  void _onMove(DragTargetDetails<DragPayload> details) {
    if (!_active) {
      _active = true;
      // Указатель и за пределами слоя, и над другим слоем: события движения
      // и отпускания приходят сюда, пока перетаскивание не кончилось.
      if (!_routed) {
        GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
        _routed = true;
      }
    }
    _payload = details.data;
    _pointer = details.offset;
    _refresh();
    _watch();
    _kick();
  }

  /// Все события указателя, пока идёт перетаскивание: движение за краем
  /// слоя не теряется (автопрокрутка идёт, линия снимается), а отпускание
  /// вне слоя, как и отмена, закрывает сессию.
  void _onPointer(PointerEvent event) {
    if (!_active) return;
    if (event is PointerMoveEvent) {
      _pointer = event.position;
      _refresh();
      _kick();
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      // Бросок на слой обработан раньше (маршрут самого перетаскивания идёт
      // перед общими); если слой ещё жив — отпустили вне его.
      scheduleMicrotask(() {
        if (_active) _end();
      });
    }
  }

  void _unroute() {
    if (!_routed) return;
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointer);
    _routed = false;
  }

  /// Запустить тикер автопрокрутки, если указатель у края области.
  void _kick() {
    if (!_ticker.isActive && _scrollSpeed() != 0) {
      _lastTick = Duration.zero;
      _ticker.start();
    }
  }

  /// Следить за шагами прокрутки области, над которой идёт перетаскивание.
  void _watch() {
    final scrollable = _scrollable;
    if (scrollable == null || !scrollable.mounted) return;
    if (!identical(_watched, scrollable.position)) {
      _watched?.removeListener(_onScrollStep);
      _watched = scrollable.position..addListener(_onScrollStep);
    }
  }

  /// Область сдвинулась: место под указателем пересчитывается после кадра,
  /// когда раскладка уже новая.
  void _onScrollStep() {
    if (!_active || _refreshQueued) return;
    _refreshQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshQueued = false;
      if (_active && mounted) _refresh();
    });
  }

  /// Скорость автопрокрутки области под перетаскиванием, пикселей в секунду
  /// (минус — вверх): у края области — тем быстрее, чем ближе указатель к
  /// краю и чем дальше за ним. 0 — указатель не у края.
  double _scrollSpeed() {
    final scrollable = _scrollable;
    final pointer = _pointer;
    if (!_active || pointer == null || scrollable == null) return 0;
    if (!scrollable.mounted) return 0;
    final box = scrollable.context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || box.size.height < _edge * 2) {
      return 0;
    }
    final top = box.localToGlobal(Offset.zero).dy;
    final bottom = top + box.size.height;
    if (pointer.dy < top + _edge) {
      return -((top + _edge - pointer.dy) / _edge).clamp(0, 1) * _maxSpeed;
    }
    if (pointer.dy > bottom - _edge) {
      return ((pointer.dy - (bottom - _edge)) / _edge).clamp(0, 1) * _maxSpeed;
    }
    return 0;
  }

  /// Кадр автопрокрутки. Тикер живёт, только пока указатель у края: иначе
  /// он бесконечно просил бы кадры.
  void _onTick(Duration elapsed) {
    final seconds = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    final speed = _scrollSpeed();
    if (speed == 0) {
      _ticker.stop();
      return;
    }
    final position = _scrollable!.position;
    final target = (position.pixels + speed * seconds).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (target != position.pixels) position.jumpTo(target);
  }

  void _onDrop(DragTargetDetails<DragPayload> details) {
    _payload = details.data;
    _pointer = details.offset;
    final place = _place();
    _end();
    if (place != null && mounted) unawaited(place.perform(context, ref));
  }

  /// Перетаскивание закончено или отменено.
  void _end() {
    _active = false;
    _payload = null;
    _pointer = null;
    _ticker.stop();
    _watched?.removeListener(_onScrollStep);
    _watched = null;
    _unroute();
    _session.clear();
  }

  @override
  Widget build(BuildContext context) => DragTarget<DragPayload>(
    onWillAcceptWithDetails: (_) => true,
    onMove: _onMove,
    onAcceptWithDetails: _onDrop,
    builder: (_, _, _) => widget.child,
  );
}
