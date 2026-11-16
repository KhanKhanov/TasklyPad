import 'package:flutter/widgets.dart';

import '../logic/shell_commands.dart';

/// Запуск команды оболочки для всего, что внутри неё: клавиш, пункта «Поиск»
/// сайдбара, окна «Поиск». Команду выполняет оболочка — ей известны экран,
/// ширина окна и выдвижная панель.
class ShellCommandScope extends InheritedWidget {
  const ShellCommandScope({super.key, required this.run, required super.child});

  /// Выполнить команду.
  final ValueChanged<ShellCommandId> run;

  /// Запуск команд ближайшей оболочки.
  static ValueChanged<ShellCommandId> of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<ShellCommandScope>();
    assert(scope != null, 'ShellCommandScope вне оболочки');
    return scope!.run;
  }

  @override
  bool updateShouldNotify(ShellCommandScope oldWidget) => run != oldWidget.run;
}
