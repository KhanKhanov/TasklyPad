import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/toast_lamp.dart';

/// Отмечает [child] как «лампу» нижних уведомлений ([ToastLamp]): точка
/// [anchor] в нём — горлышко, [mouth] — его ширина. Регистрируется после
/// первого кадра (менять провайдер во время сборки нельзя). При удалении
/// ничего не пишет: лампы без виджета на экране нет ([toastLampGlobal] вернёт
/// `null`), а следующий якорь перезапишет запись.
class ToastLampAnchor extends ConsumerStatefulWidget {
  const ToastLampAnchor({
    super.key,
    required this.anchor,
    this.mouth,
    required this.child,
  });

  final Alignment anchor;
  final double? mouth;
  final Widget child;

  @override
  ConsumerState<ToastLampAnchor> createState() => _ToastLampAnchorState();
}

class _ToastLampAnchorState extends ConsumerState<ToastLampAnchor> {
  final GlobalKey _key = GlobalKey(debugLabel: 'ToastLamp');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(toastLampProvider.notifier).attach((
        key: _key,
        anchor: widget.anchor,
        mouth: widget.mouth,
      ));
    });
  }

  @override
  Widget build(BuildContext context) =>
      KeyedSubtree(key: _key, child: widget.child);
}
