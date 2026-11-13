import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/data_providers.dart';
import '../../../domain/models.dart';
import '../../../domain/rules.dart';
import '../../../domain/tree.dart';
import '../../../domain/workspace.dart';
import '../../common/state/drag_session.dart';
import '../../common/ui/drag_layer.dart';
import '../../common/ui/drag_rows.dart';
import '../../common/ui/ui_kit.dart';

/// Шаг уровня подпроекта в строке [ProjectTile] (отступ на уровень).
const double projectIndentStep = 16;

/// Перетаскиваемый проект: сам, с подпроектами.
final class ProjectDrag implements DragPayload {
  ProjectDrag({
    required this.project,
    required this.depth,
    required this.height,
  });

  final Project project;

  /// Уровень проекта в дереве (0 — верхний): от него считается уровень после
  /// сдвига вбок.
  final int depth;

  /// Высота поддерева: проект с подпроектами глубже не встанет.
  final int height;

  @override
  Offset? startAt;

  @override
  Set<String> get sources => {project.id};
}

/// Бросок проекта: на место в дереве [ProjectCommands.reorder]. Без тоста
/// «Отменить»: help говорит о нём только у задач (решение 8 плана M4).
final class ReorderProjectPlace implements DropPlace {
  const ReorderProjectPlace({
    required this.id,
    required this.parentId,
    required this.afterId,
    required this.indicator,
  });

  final String id;
  final String? parentId;
  final String? afterId;

  @override
  final DropIndicator indicator;

  @override
  Future<void> perform(BuildContext context, WidgetRef ref) => runCommand(
    context,
    () => ref
        .read(projectCommandsProvider)
        .reorder(id, parentId: parentId, afterId: afterId),
  );
}

/// Строка проекта с перетаскиванием (help «Introduction to projects»: «There's
/// no separate drag handle, so you drag the project itself»): тянется вся
/// строка — мышью после небольшого сдвига, касанием после долгого нажатия;
/// клик и короткое касание работают как раньше. Строка же — место броска:
/// линия до или после неё, уровень — сдвигом по X (шаг [projectIndentStep],
/// три уровня).
///
/// [items] — все строки дерева, где стоит эта; [surface] — где (сайдбар или
/// экран «Мои проекты»): линия рисуется на той поверхности, над которой
/// указатель. «Входящие», избранное и архивные проекты не оборачиваются: они
/// не источник.
class ProjectDragTile extends StatelessWidget {
  const ProjectDragTile({
    super.key,
    required this.item,
    required this.items,
    required this.ws,
    required this.surface,
    required this.child,
  });

  final TreeItem<Project> item;
  final List<TreeItem<Project>> items;
  final Workspace ws;
  final String surface;
  final Widget child;

  String get _owner => '$surface:${item.value.id}';

  /// Место броска [query] над этой строкой (`null` — чужой груз или места
  /// нет: предел уровней).
  DropPlace? _resolve(DropQuery query, RenderBox box) {
    final payload = query.payload;
    if (payload is! ProjectDrag) return null;
    final moved = ws.projectSubtree(payload.project.id).toSet();
    final row = items.indexWhere((i) => i.value.id == item.value.id);
    if (row < 0) return null;
    final upper = box.globalToLocal(query.pointer).dy < box.size.height / 2;
    bool keeps(TreeItem<Project> i) => !moved.contains(i.value.id);
    final shown = items.where(keeps).toList();
    if (shown.isEmpty) return null;
    final index = dropIndex(items, row, upper: upper, keeps: keeps);
    final at = treeDropPlace(
      shown,
      (p) => p.id,
      index: index,
      wantedDepth: payload.depth + (query.delta.dx / projectIndentStep).round(),
      movedHeight: payload.height,
      maxLevels: Limits.projectLevels,
    );
    if (at == null) return null;
    return ReorderProjectPlace(
      id: payload.project.id,
      parentId: at.parentId,
      afterId: at.afterId,
      indicator: lineBefore(
        [for (final i in shown) '$surface:${i.value.id}'],
        index,
        indent: 8 + at.depth * projectIndentStep,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => WholeRowDrag(
    owner: _owner,
    resolve: _resolve,
    id: item.value.id,
    payload: ProjectDrag(
      project: item.value,
      depth: item.depth,
      height: ws.projectHeight(item.value.id),
    ),
    title: item.value.name,
    child: child,
  );
}
