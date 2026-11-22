import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'toast_lamp.g.dart';

/// Где «лампа» нижних уведомлений: виджет с ключом [key], точка [anchor] в
/// нём и ширина горлышка [mouth] (`null` — половина ширины виджета).
typedef ToastLampSpot = ({GlobalKey key, Alignment anchor, double? mouth});

/// «Лампа», из которой выходят и в которую втекают нижние уведомления
/// (решения 1А–5А plans/m5 «Решения M5.3a»): на компьютере — вкладка
/// «Уведомления» внизу справа, на телефоне — правый нижний угол окна.
/// Провайдер, а не наследуемый виджет оболочки: тосты окна задачи и карточек
/// конфликтов живут в маршрутах диалогов, вне оболочки. Регистрирует её
/// `ToastLampAnchor`; положение берётся в момент запроса
/// ([toastLampGlobal]) и не устаревает при смене размера окна.
@Riverpod(keepAlive: true)
class ToastLamp extends _$ToastLamp {
  @override
  ToastLampSpot? build() => null;

  void attach(ToastLampSpot spot) => state = spot;
}

/// Горлышко лампы [spot] в координатах окна и его ширина; лампы нет на
/// экране — `null` (тост втягивается под себя, как раньше).
({Offset point, double mouth})? toastLampGlobal(ToastLampSpot? spot) {
  final box = spot?.key.currentContext?.findRenderObject();
  if (spot == null || box is! RenderBox || !box.attached || !box.hasSize) {
    return null;
  }
  return (
    point: box.localToGlobal(spot.anchor.alongSize(box.size)),
    mouth: spot.mouth ?? box.size.width / 2,
  );
}
