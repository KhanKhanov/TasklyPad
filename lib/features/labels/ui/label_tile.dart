import 'package:flutter/material.dart';

import '../../../app/theme/app_palette.dart';
import '../../../domain/models.dart';
import '../../common/ui/ui_kit.dart';
import 'label_menu.dart';

/// Строка метки в сайдбаре («Избранное») и на странице «Фильтры и метки»:
/// значок метки её цвета, название и число активных задач; при наведении
/// счётчик сменяется меню «⋯».
class LabelTile extends StatefulWidget {
  const LabelTile({
    super.key,
    required this.label,
    required this.count,
    this.selected = false,
  });

  final Label label;
  final int count;
  final bool selected;

  @override
  State<LabelTile> createState() => _LabelTileState();
}

class _LabelTileState extends State<LabelTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final l = widget.label;
    final textColor = widget.selected
        ? palette.onSelected
        : palette.textPrimary;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Material(
        color: widget.selected ? palette.selected : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => navigate(context, '/label/${l.id}'),
          child: SizedBox(
            height: 34,
            child: Row(
              children: [
                const SizedBox(width: 8),
                Icon(
                  Icons.sell_outlined,
                  size: 18,
                  color: projectColor(l.color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: textColor, fontSize: 14),
                  ),
                ),
                // Меню всегда в дереве (как у проекта): открытое меню
                // перекрывает строку, и кнопка, убранная из дерева при уходе
                // мыши, не получила бы выбранный пункт.
                SizedBox(
                  width: 36,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (!_hover && widget.count > 0)
                        Text(
                          '${widget.count}',
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      Visibility(
                        visible: _hover,
                        maintainState: true,
                        maintainAnimation: true,
                        maintainSize: true,
                        child: LabelMenuButton(label: l),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
