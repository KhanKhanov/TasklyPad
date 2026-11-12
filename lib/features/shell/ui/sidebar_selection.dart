import 'package:flutter/material.dart';

import '../../../app/theme/app_palette.dart';

/// Оформление пункта сайдбара: выбранный — фон, рамка и тень (объём, решение
/// 12Б M4.10a, отступление от вида Todoist), остальные — без них. Одно место
/// для видов, проектов, меток и заголовков групп.
class SidebarSelectable extends StatelessWidget {
  const SidebarSelectable({
    super.key,
    required this.selected,
    required this.child,
  });

  final bool selected;

  /// Содержимое; обычно `InkWell` с тем же скруглением [sidebarItemRadius].
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: sidebarItemRadius,
        border: Border.all(
          color: selected ? palette.selectedBorder : Colors.transparent,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: palette.selectedShadow,
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Material(
        color: selected ? palette.selected : Colors.transparent,
        borderRadius: sidebarItemRadius,
        child: child,
      ),
    );
  }
}

/// Скругление пункта сайдбара.
final BorderRadius sidebarItemRadius = BorderRadius.circular(6);
