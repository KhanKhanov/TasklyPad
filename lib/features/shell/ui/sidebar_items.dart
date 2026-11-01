import 'package:flutter/material.dart';

import '../../../app/theme/app_palette.dart';

/// Пункт сайдбара: значок, название, число задач.
class SidebarNavItem extends StatelessWidget {
  const SidebarNavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.countColor,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  /// Цвет числа; по умолчанию — вторичный текст.
  final Color? countColor;

  /// Цвет значка; по умолчанию — как у текста.
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final color = selected ? palette.onSelected : palette.textPrimary;
    return Material(
      color: selected ? palette.selected : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: SizedBox(
          height: 34,
          child: Row(
            children: [
              const SizedBox(width: 8),
              Icon(icon, size: 20, color: iconColor ?? color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label, style: TextStyle(color: color)),
              ),
              if (count > 0)
                SizedBox(
                  width: 36,
                  child: Text(
                    '$count',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: countColor ?? palette.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Заголовок группы сайдбара («Избранное», «Мои проекты»).
class SidebarGroupHeader extends StatelessWidget {
  const SidebarGroupHeader({
    super.key,
    required this.label,
    this.onTap,
    this.trailing,
    this.selected = false,
  });

  final String label;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Material(
        color: selected ? palette.selected : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: SizedBox(
            height: 34,
            child: Row(
              children: [
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
