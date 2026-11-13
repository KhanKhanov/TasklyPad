import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/data_providers.dart';
import '../../../domain/view_options.dart';
import '../../../l10n/app_localizations.dart';
import '../../common/state/drag_session.dart';
import '../../common/ui/drag_layer.dart';
import '../../common/ui/drag_rows.dart';
import '../state/selection.dart';
import 'task_actions.dart';
import 'task_drag.dart';
import 'task_drop_calc.dart';

/// Бросок задач на место в списке или в конец проекта (сайдбар), раздел.
/// Проект, раздел и родитель пишутся командой [TaskCommands.placeAll].
final class MoveTasksPlace implements DropPlace {
  const MoveTasksPlace({
    required this.ids,
    required this.projectId,
    this.sectionId,
    this.parentId,
    this.afterId,
    this.atTop = false,
    required this.indicator,
  });

  final List<String> ids;
  final String projectId;
  final String? sectionId;
  final String? parentId;
  final String? afterId;

  /// В начало места, если [afterId] не задан; иначе — в конец.
  final bool atTop;

  @override
  final DropIndicator indicator;

  @override
  Future<void> perform(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final many = ids.length > 1;
    final selection = ref.read(taskSelectionProvider.notifier);
    final undo = await runWithUndo(
      context,
      l10n.taskMoved,
      () => many
          ? ref
                .read(bulkTaskCommandsProvider)
                .moveMany(
                  ids,
                  projectId: projectId,
                  sectionId: sectionId,
                  parentId: parentId,
                  afterId: afterId,
                  atTop: atTop,
                )
          : ref
                .read(taskCommandsProvider)
                .placeAll(
                  ids,
                  projectId: projectId,
                  sectionId: sectionId,
                  parentId: parentId,
                  afterId: afterId,
                  atTop: atTop,
                ),
    );
    // Выделенные брошены — выделение сделало своё дело. Бросок на то же место
    // и отказ команды его не снимают.
    if (many && undo != null) selection.clear();
  }
}

/// Бросок на место среди задач дня ([TaskCommands.reorderInDay]); у задачи с
/// другого дня меняется и срок — тост «Срок изменён».
final class ReorderInDayPlace implements DropPlace {
  const ReorderInDayPlace({
    required this.id,
    required this.date,
    required this.afterId,
    required this.sorting,
    required this.changesDate,
    required this.indicator,
  });

  final String id;
  final String date;
  final String? afterId;
  final Sorting sorting;
  final bool changesDate;

  @override
  final DropIndicator indicator;

  @override
  Future<void> perform(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return runWithUndo(
      context,
      changesDate ? l10n.dueChanged : l10n.taskMoved,
      () => ref
          .read(taskCommandsProvider)
          .reorderInDay(id, date, afterId: afterId, sorting: sorting),
    );
  }
}

/// Бросок на день целиком — заголовок дня, зона «на завтра»
/// ([TaskCommands.moveToDay]): меняется только дата.
final class MoveToDayPlace implements DropPlace {
  const MoveToDayPlace({
    required this.id,
    required this.date,
    required this.indicator,
  });

  final String id;
  final String date;

  @override
  final DropIndicator indicator;

  @override
  Future<void> perform(BuildContext context, WidgetRef ref) => runWithUndo(
    context,
    AppLocalizations.of(context).dueChanged,
    () => ref.read(taskCommandsProvider).moveToDay(id, date),
  );
}

/// Пункт сайдбара — проект, куда можно бросить задачи: в конец его задач без
/// раздела; срок не меняется (решение 3А «Ход M4.9»).
class ProjectDropSlot extends StatelessWidget {
  const ProjectDropSlot({
    super.key,
    required this.projectId,
    required this.child,
  });

  final String projectId;
  final Widget child;

  @override
  Widget build(BuildContext context) => DropArea(
    owner: 'project:$projectId',
    resolve: (query, _) => query.payload is TaskDrag
        ? MoveTasksPlace(
            ids: (query.payload as TaskDrag).ids,
            projectId: projectId,
            indicator: DropIndicator(
              owner: 'project:$projectId',
              mark: DropMark.frame,
            ),
          )
        : null,
    child: child,
  );
}

/// Заголовок раздела: задачи встают в его начало.
class SectionDropSlot extends StatelessWidget {
  const SectionDropSlot({
    super.key,
    required this.projectId,
    required this.sectionId,
    required this.child,
    this.enabled = true,
  });

  final String projectId;
  final String sectionId;
  final Widget child;

  /// `false` — слот отвечает «не моё» (перетаскивание задач выключено): дерево
  /// остаётся тем же, и смена сортировки не пересоздаёт заголовок раздела.
  final bool enabled;

  @override
  Widget build(BuildContext context) => DropArea(
    owner: 'section:$sectionId',
    resolve: (query, _) {
      final payload = query.payload;
      final origin = payload is TaskDrag ? payload.origin : null;
      if (!enabled ||
          payload is! TaskDrag ||
          origin is! ProjectDrop ||
          origin.parentId != null ||
          origin.projectId != projectId) {
        return null;
      }
      return MoveTasksPlace(
        ids: payload.ids,
        projectId: projectId,
        sectionId: sectionId,
        atTop: true,
        indicator: DropIndicator(
          owner: 'section:$sectionId',
          mark: DropMark.frame,
        ),
      );
    },
    child: child,
  );
}

/// Заголовок дня в «Предстоящем»: бросок на него меняет только дату.
class DayDropSlot extends StatelessWidget {
  const DayDropSlot({super.key, required this.date, required this.child});

  final String date;
  final Widget child;

  @override
  Widget build(BuildContext context) => DropArea(
    owner: 'day:$date',
    resolve: (query, _) => dayHeaderPlace(query.payload, date),
    child: child,
  );
}
