import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/data_providers.dart';
import '../../../domain/view_options.dart';
import '../../common/ui/ui_kit.dart';
import '../../shell/ui/shell_keys.dart';
import '../../tasks/ui/task_actions.dart';
import '../state/view_options.dart';

class SortByDateIntent extends Intent {
  const SortByDateIntent();
}

class SortByPriorityIntent extends Intent {
  const SortByPriorityIntent();
}

class SortByNameIntent extends Intent {
  const SortByNameIntent();
}

/// `D`, `P`, `N` — help «Use keyboard shortcuts», «Sort tasks»; `R` — по
/// исполнителю, вне scope (TODOIST_PARITY §11).
const Map<ShortcutActivator, Intent> viewSortShortcuts = {
  SingleActivator(LogicalKeyboardKey.keyD): SortByDateIntent(),
  SingleActivator(LogicalKeyboardKey.keyP): SortByPriorityIntent(),
  SingleActivator(LogicalKeyboardKey.keyN): SortByNameIntent(),
};

/// Клавиши сортировки вида над [child]: ставят сортировку по дате,
/// приоритету или имени в «Отображении» вида; повторное нажатие ничего не
/// меняет (допущение, О-69). Не срабатывают при вводе текста и после `g`
/// (`g p` — «Проекты»).
class ViewSortKeys extends ConsumerWidget {
  const ViewSortKeys({
    super.key,
    required this.viewType,
    this.objectId,
    required this.child,
  });

  final ViewType viewType;
  final String? objectId;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void sort(Sorting sorting) {
      final options = ref.read(viewOptionsProvider(viewType, objectId));
      if (options.sorting == sorting) return;
      runCommand(
        context,
        () => ref
            .read(viewOptionsCommandsProvider)
            .save(options, options.copyWith(sorting: sorting)),
      );
    }

    bool blocked() => ShellKeys.sequencePending(context);
    return Shortcuts(
      shortcuts: viewSortShortcuts,
      child: Actions(
        actions: {
          SortByDateIntent: HotkeyAction<SortByDateIntent>(
            blocked: blocked,
            () => sort(Sorting.dueDate),
          ),
          SortByPriorityIntent: HotkeyAction<SortByPriorityIntent>(
            blocked: blocked,
            () => sort(Sorting.priority),
          ),
          SortByNameIntent: HotkeyAction<SortByNameIntent>(
            blocked: blocked,
            () => sort(Sorting.alphabetically),
          ),
        },
        child: child,
      ),
    );
  }
}
