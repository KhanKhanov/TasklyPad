import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../shell/ui/shell_keys.dart';
import '../../tasks/ui/task_actions.dart';
import 'week_strip.dart';

class GoToTodayIntent extends Intent {
  const GoToTodayIntent();
}

class NextWeekIntent extends Intent {
  const NextWeekIntent();
}

class PreviousWeekIntent extends Intent {
  const PreviousWeekIntent();
}

/// Клавиши «Предстоящего» (help «Use keyboard shortcuts», таблица «Upcoming
/// view», Windows): `Home` — «Go to today in Upcoming», `Shift+→` /
/// `Shift+←` — следующая / предыдущая неделя. Делают то же, что «Сегодня» и
/// стрелки полосы недели ([WeekStrip]), и подчиняются тем же границам: в
/// прошлое не уходят. Не срабатывают при вводе текста и после `g` / `o`.
class UpcomingKeys extends StatelessWidget {
  const UpcomingKeys({
    super.key,
    required this.selected,
    required this.today,
    required this.onSelect,
    required this.onAdd,
    required this.child,
  });

  final DateTime selected;
  final DateTime today;
  final ValueChanged<DateTime> onSelect;

  /// `a` и `Shift+A` — «Добавить задачу» в выбранный день.
  final VoidCallback onAdd;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    bool blocked() => ShellKeys.sequencePending(context);
    return Shortcuts(
      shortcuts: const {
        ...projectShortcuts,
        SingleActivator(LogicalKeyboardKey.home): GoToTodayIntent(),
        SingleActivator(LogicalKeyboardKey.arrowRight, shift: true):
            NextWeekIntent(),
        SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true):
            PreviousWeekIntent(),
      },
      child: Actions(
        actions: {
          AddTaskBottomIntent: HotkeyAction<AddTaskBottomIntent>(
            blocked: blocked,
            onAdd,
          ),
          AddTaskTopIntent: HotkeyAction<AddTaskTopIntent>(
            blocked: blocked,
            onAdd,
          ),
          GoToTodayIntent: HotkeyAction<GoToTodayIntent>(blocked: blocked, () {
            if (selected != today) onSelect(today);
          }),
          NextWeekIntent: HotkeyAction<NextWeekIntent>(blocked: blocked, () {
            if (WeekStrip.nextWeek(selected, today) case final day?) {
              onSelect(day);
            }
          }),
          PreviousWeekIntent: HotkeyAction<PreviousWeekIntent>(
            blocked: blocked,
            () {
              if (WeekStrip.previousWeek(selected, today) case final day?) {
                onSelect(day);
              }
            },
          ),
        },
        child: child,
      ),
    );
  }
}
