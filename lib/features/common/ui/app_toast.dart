import 'dart:async';

import 'package:flutter/material.dart';

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
/// наше дополнение, в Todoist тост проявляется и гаснет). Вид — как у
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
      // Уходит сам [_AppToast]; это — запас, если анимация не закончится.
      duration: duration + toastGenieDuration * 2 + const Duration(seconds: 1),
      persist: false,
      onVisible: onVisible,
    ),
  );
  return toast = AppToast._(controller);
}

class _AppToast extends StatefulWidget {
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
  State<_AppToast> createState() => _AppToastState();
}

class _AppToastState extends State<_AppToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _genie = AnimationController(
    vsync: this,
    duration: toastGenieDuration,
  );
  Timer? _timer;
  bool _leaving = false;

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
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // «Уменьшить движение» в системе — без анимации.
    if (_genie.isDismissed && !_leaving) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _genie.value = 1;
      } else {
        _genie.forward();
      }
    }
  }

  void _dismiss() {
    if (_leaving || !mounted) return;
    _leaving = true;
    _timer?.cancel();
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
    return GenieTransition(
      progress: _genie,
      child: widget.wrap?.call(body) ?? body,
    );
  }
}
