import 'package:flutter/material.dart';

import '../../shell/ui/app_shell.dart';

/// Раскладка окна задачи. Узкий экран (телефон) — на весь экран, поля под
/// подзадачами; широкий — окно поверх списка с полями справа.
class TaskDialogLayout extends StatelessWidget {
  const TaskDialogLayout({
    super.key,
    required this.top,
    required this.main,
    required this.fields,
  });

  /// Заголовок: путь, стрелки к соседним задачам, меню, закрыть.
  final Widget top;

  /// Левая часть: название, описание, подзадачи.
  final List<Widget> main;

  /// Поля задачи: проект, срок, дедлайн, приоритет, метки.
  final Widget fields;

  // Свой Scaffold: тосты («Отменить», отказы) — внутри окна, а не под его
  // затемнением на экране списка. ScaffoldMessenger у панели (`TaskPanel`).
  Widget _toasts(Widget child) =>
      Scaffold(backgroundColor: Colors.transparent, body: child);

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width < wideLayoutWidth) {
      return Dialog.fullscreen(
        child: _toasts(
          SafeArea(
            child: Column(
              children: [
                top,
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [...main, const Divider(height: 1), fields],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880, maxHeight: 640),
        child: _toasts(
          Column(
            children: [
              top,
              const Divider(height: 1),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.only(bottom: 24),
                        children: main,
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    SizedBox(
                      width: 280,
                      child: SingleChildScrollView(child: fields),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
