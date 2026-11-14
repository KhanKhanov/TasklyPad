import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/notification_log.dart';
import '../../../app/toast_lamp.dart';
import 'genie_transition.dart';

/// Длительность эффекта «джин» — как сворачивание окна в macOS.
const Duration toastGenieDuration = Duration(milliseconds: 500);

/// Кнопка нижнего уведомления («Отменить», «Открыть»).
typedef ToastAction = ({String label, VoidCallback onPressed});

/// Показанное уведомление: [dismiss] убирает его с эффектом «джин», [closed]
/// — когда его не стало на экране.
final class AppToast {
  AppToast._(this._controller);

  final ScaffoldFeatureController<SnackBar, SnackBarClosedReason> _controller;
  _AppToastState? _state;
  bool _dismissed = false;

  Future<SnackBarClosedReason> get closed => _controller.closed;

  /// Убрать: на экране — втянуть «джином»; в очереди за другим тостом —
  /// закрыть, как только дойдёт очередь (закрыть сразу `ScaffoldMessenger`
  /// даёт только тост на экране).
  void dismiss() {
    _dismissed = true;
    _state?._dismiss();
  }

  /// Убрать сразу, без анимации (уведомление больше не нужно).
  void close() => _controller.close();
}

/// Нижнее уведомление приложения: появляется и уходит эффектом «джин», как
/// окно в Dock на macOS (решение пользователя 1А «Анимация уведомлений» —
/// наше дополнение, в Todoist тост проявляется и гаснет), — выходит из
/// «лампы» [ToastLamp] (вкладки «Уведомления») и втекает в неё; показанное
/// уведомление записывается в журнал «Уведомления» (решения 1А–4А plans/m5
/// «Решения M5.3a»). Вид — как у
/// `SnackBar` темы; висит [duration], затем втягивается. [action] — кнопка
/// справа. Оболочку `SnackBar` даёт `ScaffoldMessenger` (очередь и место
/// внизу) — прозрачной: тост рисует и анимирует [_AppToast]. Свою короткую
/// анимацию оболочки не отключаем: стиль анимации у `ScaffoldMessenger` общий
/// для всех тостов окна, а без неё не вызывается `onVisible`; её проявление
/// идёт вместе с «джином», а уход — когда тост уже втянут.
/// [wrap] — обёртка содержимого (например, слушатель `Ctrl+Z`).
AppToast showAppToast(
  ScaffoldMessengerState messenger, {
  required String text,
  ToastAction? action,
  Duration duration = const Duration(seconds: 4),
  VoidCallback? onVisible,
  Widget Function(Widget toast)? wrap,
}) {
  late final AppToast toast;
  final controller = messenger.showSnackBar(
    SnackBar(
      content: _AppToast(
        text: text,
        action: action,
        duration: duration,
        handle: () => toast,
        wrap: wrap,
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      padding: EdgeInsets.zero,
      behavior: SnackBarBehavior.floating,
      width: 360,
      // Полоски «джина» уходят к лампе за пределы тоста.
      clipBehavior: Clip.none,
      // Уходит сам [_AppToast]; это — запас, если анимация не закончится.
      duration: duration + toastGenieDuration * 2 + const Duration(seconds: 1),
      persist: false,
      onVisible: onVisible,
    ),
  );
  return toast = AppToast._(controller);
}

class _AppToast extends ConsumerStatefulWidget {
  const _AppToast({
    required this.text,
    required this.action,
    required this.duration,
    required this.handle,
    required this.wrap,
  });

  final String text;
  final ToastAction? action;
  final Duration duration;
  final AppToast Function() handle;
  final Widget Function(Widget toast)? wrap;

  @override
  ConsumerState<_AppToast> createState() => _AppToastState();
}

class _AppToastState extends ConsumerState<_AppToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _genie = AnimationController(
    vsync: this,
    duration: toastGenieDuration,
  );
  final GlobalKey _bodyKey = GlobalKey(debugLabel: 'AppToast');
  Timer? _timer;
  bool _leaving = false;

  /// Горлышко лампы в координатах тоста и его ширина; `null` — лампы нет.
  Offset? _target;
  double? _mouth;

  @override
  void initState() {
    super.initState();
    final toast = widget.handle();
    toast._state = this;
    if (toast._dismissed) {
      // Убрали, пока ждал в очереди.
      WidgetsBinding.instance.addPostFrameCallback((_) => toast.close());
      return;
    }
    _timer = Timer(widget.duration, _dismiss);
    // Первый кадр появления — все полоски ещё в лампе, невидимы: цель
    // достаточно найти после него.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _aim();
    });
  }

  bool _recorded = false;

  /// В журнал — тост, который появился целиком: подавленный сразу после
  /// показа (конфликт уже решён, `AppToast.close`) не записывается.
  void _record() {
    if (_recorded || !mounted) return;
    _recorded = true;
    ref.read(notificationLogControllerProvider.notifier).record(widget.text);
  }

  /// Найти лампу относительно тоста: окно могли растянуть, сайдбар — скрыть.
  void _aim() {
    final lamp = toastLampGlobal(ref.read(toastLampProvider));
    final box = _bodyKey.currentContext?.findRenderObject();
    if (lamp == null || box is! RenderBox || !box.hasSize) return;
    final target = box.globalToLocal(lamp.point);
    if (target == _target && lamp.mouth == _mouth) return;
    setState(() {
      _target = target;
      _mouth = lamp.mouth;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // «Уменьшить движение» в системе — без анимации.
    if (_genie.isDismissed && !_leaving) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _genie.value = 1;
        // Менять провайдер во время сборки нельзя — после кадра.
        WidgetsBinding.instance.addPostFrameCallback((_) => _record());
      } else {
        _genie.forward().then((_) => _record());
      }
    }
  }

  void _dismiss() {
    if (_leaving || !mounted) return;
    _leaving = true;
    _timer?.cancel();
    _aim();
    final toast = widget.handle();
    if (MediaQuery.disableAnimationsOf(context)) {
      toast.close();
      return;
    }
    _genie.reverse().whenComplete(() {
      if (mounted) toast.close();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    final toast = widget.handle();
    if (identical(toast._state, this)) toast._state = null;
    _genie.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final snack = theme.snackBarTheme;
    final action = widget.action;
    final body = Material(
      color: snack.backgroundColor ?? colors.inverseSurface,
      elevation: snack.elevation ?? 6,
      shape:
          snack.shape ??
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          start: 16,
          end: action == null ? 16 : 8,
          top: action == null ? 14 : 4,
          bottom: action == null ? 14 : 4,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.text,
                style:
                    snack.contentTextStyle ??
                    theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onInverseSurface,
                    ),
              ),
            ),
            if (action != null)
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor:
                      snack.actionTextColor ?? colors.inversePrimary,
                ),
                onPressed: () {
                  action.onPressed();
                  _dismiss();
                },
                child: Text(action.label),
              ),
          ],
        ),
      ),
    );
    // Ключ — снаружи «джина»: внутри [child] рисуется многими полосками.
    return KeyedSubtree(
      key: _bodyKey,
      child: GenieTransition(
        progress: _genie,
        target: _target,
        mouthWidth: _mouth,
        child: widget.wrap?.call(body) ?? body,
      ),
    );
  }
}
