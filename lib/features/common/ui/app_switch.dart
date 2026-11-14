import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/app_palette.dart';

/// Длительность движения кружка и смены цветов переключателя.
const Duration appSwitchDuration = Duration(milliseconds: 150);

/// Переключатель (решение 1А plans/m5 «Решения M5.3a», вид — по идее
/// переключателя Amnezia VPN, код свой): капсула 50×30 с рамкой и кружок
/// 20 px. Выключен — серый кружок слева, рамка цвета разделителя; включён —
/// кружок цвета акцента справа с мягким свечением, рамка — тёмный акцент.
/// При наведении и нажатии позади кружка проступает круг 36 px, при фокусе
/// с клавиатуры — кольцо со свечением; Enter и пробел переключают.
/// Выключенный ([onChanged] — `null`) — прозрачность 40%. Внешний размер —
/// 56×36: круг и кольцо помещаются без обрезки.
class AppSwitch extends StatefulWidget {
  const AppSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.focusNode,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final FocusNode? focusNode;

  @override
  State<AppSwitch> createState() => _AppSwitchState();
}

class _AppSwitchState extends State<AppSwitch> {
  bool _hover = false;
  bool _focus = false;
  bool _down = false;

  bool get _enabled => widget.onChanged != null;

  void _toggle() => widget.onChanged?.call(!widget.value);

  void _setDown(bool down) {
    if (_down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final on = widget.value;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : appSwitchDuration;
    final knob = on ? palette.accent : palette.textSecondary;
    // Тёмный акцент рамки — от акцента темы: свой цвет у каждой темы.
    final border = on
        ? Color.alphaBlend(Colors.black.withValues(alpha: 0.25), palette.accent)
        : palette.divider;
    // Отступ кружка от края дорожки — 5; дорожка сдвинута на 3 внутри бокса.
    final knobLeft = on ? 3.0 + 50 - 20 - 5 : 3.0 + 5;
    final halo = _enabled && (_hover || _down);
    final body = SizedBox(
      width: 56,
      height: 36,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 3,
            top: 3,
            width: 50,
            height: 30,
            child: AnimatedContainer(
              duration: duration,
              decoration: BoxDecoration(
                color: palette.raised,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: border),
              ),
            ),
          ),
          if (_focus && _enabled)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: palette.accent, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: palette.accent.withValues(alpha: 0.35),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
          AnimatedPositioned(
            duration: duration,
            left: knobLeft - 8,
            top: 0,
            width: 36,
            height: 36,
            child: AnimatedOpacity(
              duration: duration,
              opacity: halo ? 1 : 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (on ? palette.accent : palette.textPrimary).withValues(
                    alpha: _down ? 0.20 : 0.12,
                  ),
                ),
              ),
            ),
          ),
          AnimatedPositioned(
            duration: duration,
            left: knobLeft,
            top: 8,
            width: 20,
            height: 20,
            child: AnimatedContainer(
              duration: duration,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: knob,
                // Свечение — три размытые тени цвета кружка; у выключенного
                // те же тени прозрачны, чтобы оно гасло плавно.
                boxShadow: [
                  for (final (alpha, blur) in const [
                    (0.55, 4.0),
                    (0.30, 10.0),
                    (0.15, 18.0),
                  ])
                    BoxShadow(
                      color: knob.withValues(alpha: on ? alpha : 0),
                      blurRadius: blur,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    return Semantics(
      container: true,
      toggled: on,
      enabled: _enabled,
      onTap: _enabled ? _toggle : null,
      child: FocusableActionDetector(
        enabled: _enabled,
        focusNode: widget.focusNode,
        mouseCursor: _enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        // Наведение — свой `MouseRegion`: подсветку наведения детектор
        // показывает только после переключения Flutter в «мышиный» режим.
        onShowFocusHighlight: (v) => setState(() => _focus = v),
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _toggle();
              return null;
            },
          ),
        },
        child: MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _enabled ? _toggle : null,
            onTapDown: _enabled ? (_) => _setDown(true) : null,
            onTapUp: _enabled ? (_) => _setDown(false) : null,
            onTapCancel: _enabled ? () => _setDown(false) : null,
            child: Opacity(opacity: _enabled ? 1 : 0.4, child: body),
          ),
        ),
      ),
    );
  }
}

/// Строка с подписью и [AppSwitch] справа — вместо `SwitchListTile`: нажатие
/// на всю строку переключает, как подпись у Amnezia; для экранного диктора
/// подпись и переключатель — один элемент. Фокус с клавиатуры — только у
/// переключателя (одна остановка `Tab`).
class AppSwitchTile extends StatelessWidget {
  const AppSwitchTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final Widget title;
  final Widget? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;
    final onChanged = this.onChanged;
    return MergeSemantics(
      child: InkWell(
        canRequestFocus: false,
        borderRadius: BorderRadius.circular(8),
        onTap: onChanged == null ? null : () => onChanged(!value),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DefaultTextStyle.merge(
                        style: text.bodyLarge?.copyWith(
                          color: palette.textPrimary,
                        ),
                        child: title,
                      ),
                      if (subtitle case final subtitle?)
                        DefaultTextStyle.merge(
                          style: text.bodyMedium?.copyWith(
                            color: palette.textSecondary,
                          ),
                          child: subtitle,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                AppSwitch(value: value, onChanged: onChanged),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
