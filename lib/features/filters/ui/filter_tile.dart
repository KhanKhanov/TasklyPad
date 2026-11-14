import 'package:flutter/material.dart';

import '../../../app/theme/app_palette.dart';
import '../../../domain/conflicts.dart';
import '../../../domain/models.dart';
import '../../conflicts/ui/conflict_mark.dart';
import '../../common/ui/ui_kit.dart';
import '../../shell/ui/sidebar_selection.dart';
import 'filter_menu.dart';

/// Значок фильтра его цвета — в строке и в заголовке экрана.
const IconData filterIcon = Icons.filter_alt_outlined;

/// Строка фильтра в сайдбаре («Избранное») и в «Моих фильтрах»: значок
/// фильтра его цвета и название; при наведении — меню «⋯». Счётчика задач нет
/// (решено в M5.3: у проектов его тоже пока нет).
class FilterTile extends StatefulWidget {
  const FilterTile({super.key, required this.filter, this.selected = false});

  final SavedFilter filter;
  final bool selected;

  @override
  State<FilterTile> createState() => _FilterTileState();
}

class _FilterTileState extends State<FilterTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final f = widget.filter;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: SidebarSelectable(
        selected: widget.selected,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => navigate(context, '/filter/${f.id}'),
          child: SizedBox(
            height: 34,
            child: Row(
              children: [
                const SizedBox(width: 8),
                Icon(filterIcon, size: 18, color: projectColor(f.color)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    f.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: widget.selected
                          ? palette.onSelected
                          : palette.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                ),
                ConflictMark(
                  entity: ConflictEntity.filter,
                  id: f.id,
                  iconOnly: true,
                ),
                // Меню всегда в дереве (как у метки): открытое меню перекрывает
                // строку, и кнопка, убранная при уходе мыши, не получила бы
                // выбранный пункт.
                SizedBox(
                  width: 36,
                  child: Visibility(
                    visible: _hover,
                    maintainState: true,
                    maintainAnimation: true,
                    maintainSize: true,
                    child: FilterMenuButton(filter: f),
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
