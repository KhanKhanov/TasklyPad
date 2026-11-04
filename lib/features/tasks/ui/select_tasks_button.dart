import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../state/selection.dart';
import 'task_order.dart';

/// «⋯» вида с одним пунктом «Выбрать задачи» — там, где у вида своего меню
/// нет («Входящие», «Сегодня», «Предстоящее»). Показывается без мыши:
/// выделять кликом с `Ctrl` или `Shift` там нечем (решение 9 плана M4).
class SelectTasksMenuButton extends ConsumerWidget {
  const SelectTasksMenuButton({super.key, this.size = 22});

  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // Пункт со значением `null` меню считает отменой — значение `true`.
    return PopupMenuButton<bool>(
      tooltip: l10n.moreActions,
      iconSize: size,
      padding: EdgeInsets.zero,
      icon: const Icon(Icons.more_horiz),
      onSelected: (_) => startTaskSelection(context, ref),
      itemBuilder: (context) => [
        PopupMenuItem(value: true, child: Text(l10n.selectTasks)),
      ],
    );
  }
}

/// «Выбрать задачи»: режим выделения касанием в виде [context] — его порядок
/// нужен «Выделить все».
void startTaskSelection(BuildContext context, WidgetRef ref) => ref
    .read(taskSelectionProvider.notifier)
    .startTouchMode(order: TaskOrderScope.maybeOf(context));
