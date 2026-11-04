import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/data_providers.dart';
import '../../../app/theme/app_palette.dart';
import '../../../l10n/app_localizations.dart';
import '../../common/ui/layout.dart';
import '../state/selection.dart';
import 'selection_actions.dart';

enum _More { priority, deadline, complete, uncomplete, duplicate }

/// Панель выделения внизу (help «Add or manage multiple tasks»: «the
/// multi-select toolbar appears at the bottom»): число выделенных, «Срок»,
/// «Перенести в…», «Метки», «Удалить» и «⋯» — «Приоритет», «Дедлайн»,
/// «Выполнить» (у одних выполненных — «Вернуть»), «Дублировать». «⋯» скрыт,
/// если выделены и выполненные, и невыполненные (help: «hidden when none of
/// its actions apply»). На узком экране кнопки — значками с подсказкой.
/// [focus] — первая кнопка: на неё ведёт `,`.
class SelectionToolbar extends ConsumerWidget {
  const SelectionToolbar({super.key, required this.focus});

  final FocusNode focus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(taskSelectionProvider);
    final ws = ref.watch(workspaceProvider).value;
    final live = ws == null ? const <String>[] : selection.live(ws);
    if (live.isEmpty && !selection.touchMode) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final tasks = [for (final id in live) ?ws?.task(id)];
    final any = tasks.isNotEmpty;
    final completed = tasks.where((t) => t.isCompleted).length;
    final mixed = completed > 0 && completed < tasks.length;
    final wide = MediaQuery.sizeOf(context).width >= wideLayoutWidth;

    Widget action(
      IconData icon,
      String label,
      Future<void> Function(BuildContext, WidgetRef) run, {
      FocusNode? focusNode,
    }) {
      final onPressed = any ? () => run(context, ref) : null;
      return wide
          ? TextButton.icon(
              focusNode: focusNode,
              icon: Icon(icon, size: 18),
              label: Text(label),
              onPressed: onPressed,
            )
          : IconButton(
              focusNode: focusNode,
              tooltip: label,
              // Шесть кнопок и число — в ширину телефона.
              visualDensity: VisualDensity.compact,
              icon: Icon(icon, size: 20),
              onPressed: onPressed,
            );
    }

    return Material(
      elevation: 6,
      color: palette.raised,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        // Не влезает в ширину (крупный шрифт, узкое окно) — ужимается, а не
        // уходит за край.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: l10n.clearSelection,
                icon: const Icon(Icons.close, size: 20),
                onPressed: ref.read(taskSelectionProvider.notifier).clear,
              ),
              Padding(
                padding: const EdgeInsets.only(left: 2, right: 8),
                child: Text(
                  l10n.selectedCount(tasks.length),
                  style: TextStyle(color: palette.textPrimary),
                ),
              ),
              // Телефон: «Выделить все» (help: «tap "Select All"»).
              if (selection.touchMode && ws != null)
                IconButton(
                  tooltip: l10n.selectAll,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.select_all, size: 20),
                  onPressed: () =>
                      ref.read(taskSelectionProvider.notifier).selectAll(ws),
                ),
              action(
                Icons.event_outlined,
                l10n.fieldDue,
                selectionDue,
                focusNode: focus,
              ),
              action(
                Icons.drive_file_move_outline,
                l10n.actionMoveTo,
                selectionMove,
              ),
              action(Icons.label_outline, l10n.fieldLabels, selectionLabels),
              action(Icons.delete_outline, l10n.actionDelete, selectionDelete),
              if (any && !mixed)
                PopupMenuButton<_More>(
                  tooltip: l10n.moreActions,
                  icon: const Icon(Icons.more_horiz),
                  onSelected: (more) => switch (more) {
                    _More.priority => selectionPriority(context, ref),
                    _More.deadline => selectionDeadline(context, ref),
                    _More.complete => selectionComplete(
                      context,
                      ref,
                      uncomplete: false,
                    ),
                    _More.uncomplete => selectionComplete(
                      context,
                      ref,
                      uncomplete: true,
                    ),
                    _More.duplicate => selectionDuplicate(context, ref),
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: _More.priority,
                      child: Text(l10n.fieldPriority),
                    ),
                    PopupMenuItem(
                      value: _More.deadline,
                      child: Text(l10n.fieldDeadline),
                    ),
                    if (completed == 0)
                      PopupMenuItem(
                        value: _More.complete,
                        child: Text(l10n.completeTask),
                      )
                    else
                      PopupMenuItem(
                        value: _More.uncomplete,
                        child: Text(l10n.uncompleteTask),
                      ),
                    PopupMenuItem(
                      value: _More.duplicate,
                      child: Text(l10n.actionDuplicate),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
