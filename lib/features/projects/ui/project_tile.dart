import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/data_providers.dart';
import '../../../app/theme/app_palette.dart';
import '../../../domain/models.dart';
import '../../common/ui/ui_kit.dart';
import 'project_menu.dart';

/// Строка проекта в сайдбаре и на экране «Мои проекты»: отступ по уровню,
/// стрелка свернуть / развернуть подпроекты, `#` цвета проекта, название и
/// счётчик активных задач; при наведении счётчик сменяется меню «⋯».
class ProjectTile extends ConsumerStatefulWidget {
  const ProjectTile({
    super.key,
    required this.project,
    required this.count,
    this.depth = 0,
    this.childCount = 0,
    this.selected = false,
    this.archived = false,
  });

  final Project project;
  final int count;
  final int depth;
  final int childCount;
  final bool selected;
  final bool archived;

  @override
  ConsumerState<ProjectTile> createState() => _ProjectTileState();
}

class _ProjectTileState extends ConsumerState<ProjectTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final p = widget.project;
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
          onTap: () => navigate(context, '/project/${p.id}'),
          child: SizedBox(
            height: 34,
            child: Row(
              children: [
                SizedBox(width: 4.0 + widget.depth * 16),
                SizedBox(
                  width: 22,
                  child: widget.childCount == 0
                      ? null
                      : InkWell(
                          onTap: () => runCommand(
                            context,
                            () => ref
                                .read(projectCommandsProvider)
                                .setCollapsed(p.id, !p.isCollapsed),
                          ),
                          child: Icon(
                            p.isCollapsed
                                ? Icons.chevron_right
                                : Icons.expand_more,
                            size: 18,
                            color: palette.textSecondary,
                          ),
                        ),
                ),
                ProjectHash(color: p.color),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    p.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: textColor, fontSize: 14),
                  ),
                ),
                // Меню всегда в дереве, при наведении — видно вместо счётчика.
                // Открытое меню перекрывает строку, наведение пропадает, и
                // кнопка, удалённая из дерева, не получила бы выбранный пункт.
                SizedBox(
                  width: 36,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (!_hover && !widget.archived && widget.count > 0)
                        Text(
                          '${widget.count}',
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      Visibility(
                        visible: _hover || widget.archived,
                        maintainState: true,
                        maintainAnimation: true,
                        maintainSize: true,
                        child: ProjectMenuButton(
                          project: p,
                          archived: widget.archived,
                        ),
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
