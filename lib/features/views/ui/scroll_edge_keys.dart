import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../shell/ui/shell_keys.dart';
import '../../tasks/ui/task_actions.dart';

class ScrollToStartIntent extends Intent {
  const ScrollToStartIntent();
}

class ScrollToEndIntent extends Intent {
  const ScrollToEndIntent();
}

/// `Ctrl+Home` и `Ctrl+End` — прокрутка списка задач в самое начало и в самый
/// конец (help «Use keyboard shortcuts», раздел «Project shortcuts», Windows:
/// «Scroll all the way to the top/bottom of your task list»). Прокручивает
/// [controller] — контроллер списка экрана. Не срабатывают при вводе текста и
/// после `g` / `o`.
class ScrollEdgeKeys extends StatelessWidget {
  const ScrollEdgeKeys({
    super.key,
    required this.controller,
    required this.child,
  });

  final ScrollController controller;
  final Widget child;

  /// В конец прокручивается дважды: длина списка, который строится по мере
  /// прокрутки, уточняется после первого прыжка.
  void _scroll({required bool toEnd}) {
    if (!controller.hasClients) return;
    final position = controller.position;
    position.jumpTo(toEnd ? position.maxScrollExtent : 0);
    if (!toEnd) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (controller.hasClients) {
        final p = controller.position;
        if (p.pixels < p.maxScrollExtent) p.jumpTo(p.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    bool blocked() => ShellKeys.sequencePending(context);
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.home, control: true):
            ScrollToStartIntent(),
        SingleActivator(LogicalKeyboardKey.end, control: true):
            ScrollToEndIntent(),
      },
      child: Actions(
        actions: {
          ScrollToStartIntent: HotkeyAction<ScrollToStartIntent>(
            blocked: blocked,
            () => _scroll(toEnd: false),
          ),
          ScrollToEndIntent: HotkeyAction<ScrollToEndIntent>(
            blocked: blocked,
            () => _scroll(toEnd: true),
          ),
        },
        child: child,
      ),
    );
  }
}
