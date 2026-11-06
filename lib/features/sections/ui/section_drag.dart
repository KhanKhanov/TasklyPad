import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/data_providers.dart';
import '../../../domain/models.dart';
import '../../common/state/drag_session.dart';
import '../../common/ui/drag_layer.dart';
import '../../common/ui/drag_source.dart';
import '../../common/ui/ui_kit.dart';
import '../../tasks/ui/task_drag.dart';

/// Перетаскиваемый раздел: сам, вместе с задачами (они вычисляются по
/// разделу, и пишется только его порядок).
final class SectionDrag implements DragPayload {
  SectionDrag({required this.section, required this.projectId});

  final Section section;
  final String projectId;

  @override
  Offset? startAt;

  @override
  Set<String> get sources => {section.id};
}

/// Бросок раздела: после [afterId] (`null` — первым) в проекте
/// ([SectionCommands.reorder]). Без тоста «Отменить» (решение 8 плана M4).
final class ReorderSectionPlace implements DropPlace {
  const ReorderSectionPlace({
    required this.id,
    required this.afterId,
    required this.indicator,
  });

  final String id;
  final String? afterId;

  @override
  final DropIndicator indicator;

  @override
  Future<void> perform(BuildContext context, WidgetRef ref) => runCommand(
    context,
    () => ref.read(sectionCommandsProvider).reorder(id, afterId: afterId),
  );
}

/// Заголовок раздела с перетаскиванием (help «Introduction to sections»:
/// «Click the drag handle icon to the left of the section»): ручка слева при
/// наведении мыши, долгое нажатие на заголовке — касанием. Сам заголовок —
/// место броска раздела «перед этим разделом» (у свёрнутого — нижняя
/// половина «после него»). Поле слева под ручку — [dragGutter], как у задач.
///
/// [sections] — активные разделы проекта по порядку (архивные не цель);
/// [child] — сам заголовок. Задачи, брошенные на заголовок, принимает слот
/// внутри [child].
class SectionHeaderDrag extends ConsumerStatefulWidget {
  const SectionHeaderDrag({
    super.key,
    required this.section,
    required this.projectId,
    required this.sections,
    required this.child,
  });

  final Section section;
  final String projectId;
  final List<Section> sections;
  final Widget child;

  @override
  ConsumerState<SectionHeaderDrag> createState() => _SectionHeaderDragState();
}

class _SectionHeaderDragState extends ConsumerState<SectionHeaderDrag> {
  bool _hover = false;

  Section get _section => widget.section;

  DropPlace? _resolve(DropQuery query, RenderBox box) {
    final payload = query.payload;
    if (payload is! SectionDrag ||
        payload.projectId != widget.projectId ||
        payload.section.id == _section.id) {
      return null;
    }
    final after =
        _section.isCollapsed &&
        box.globalToLocal(query.pointer).dy >= box.size.height / 2;
    if (after) {
      return ReorderSectionPlace(
        id: payload.section.id,
        afterId: _section.id,
        indicator: DropIndicator(
          owner: 'sec:${_section.id}',
          mark: DropMark.below,
          indent: dragGutter,
        ),
      );
    }
    final others = [
      for (final s in widget.sections)
        if (s.id != payload.section.id) s,
    ];
    final at = others.indexWhere((s) => s.id == _section.id);
    if (at < 0) return null;
    return ReorderSectionPlace(
      id: payload.section.id,
      afterId: at == 0 ? null : others[at - 1].id,
      indicator: DropIndicator(
        owner: 'sec:${_section.id}',
        mark: DropMark.above,
        indent: dragGutter,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final payload = SectionDrag(section: _section, projectId: widget.projectId);
    final ghost = DragGhost(title: _section.name, payload: payload);
    return DropMarker(
      owner: 'sec:${_section.id}',
      child: DropSlotRegion(
        resolve: _resolve,
        child: MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: DragSourceDim(
            id: _section.id,
            child: Stack(
              children: [
                TouchDraggable(
                  data: payload,
                  feedback: ghost,
                  child: Padding(
                    padding: const EdgeInsets.only(left: dragGutter),
                    child: widget.child,
                  ),
                ),
                if (_hover)
                  Positioned(
                    left: 0,
                    top: 16,
                    width: dragGutter,
                    height: 40,
                    child: MouseDraggable(
                      data: payload,
                      feedback: ghost,
                      child: const DragGrip(),
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

/// Задачи раздела (со «Добавить задачу»): бросок раздела на них — «после
/// этого раздела»; линия под концом списка.
class SectionTasksSlot extends StatelessWidget {
  const SectionTasksSlot({
    super.key,
    required this.section,
    required this.projectId,
    required this.child,
  });

  final Section section;
  final String projectId;
  final Widget child;

  @override
  Widget build(BuildContext context) => DropMarker(
    owner: 'secend:${section.id}',
    child: DropSlotRegion(
      resolve: (query, _) {
        final payload = query.payload;
        if (payload is! SectionDrag ||
            payload.projectId != projectId ||
            payload.section.id == section.id) {
          return null;
        }
        return ReorderSectionPlace(
          id: payload.section.id,
          afterId: section.id,
          indicator: DropIndicator(
            owner: 'secend:${section.id}',
            mark: DropMark.below,
            indent: dragGutter,
          ),
        );
      },
      child: child,
    ),
  );
}

/// Заголовок раздела с полем слева: с перетаскиванием раздела при [enabled],
/// иначе — просто сдвинутый на поле под ручку.
Widget sectionHeaderSlot({
  required bool enabled,
  required Section section,
  required String projectId,
  required List<Section> sections,
  required Widget child,
}) => enabled
    ? SectionHeaderDrag(
        key: ValueKey('drag-${section.id}'),
        section: section,
        projectId: projectId,
        sections: sections,
        child: child,
      )
    : DragGutter(child: child);

/// Задачи раздела — место броска раздела «после него» при [enabled].
Widget sectionTasksSlot({
  required bool enabled,
  required Section section,
  required String projectId,
  required Widget child,
}) => enabled
    ? SectionTasksSlot(section: section, projectId: projectId, child: child)
    : child;
