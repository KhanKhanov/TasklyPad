import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import '../logic/shell_commands.dart';

/// Подпись команды — как пункт сайдбара или кнопка, что делают то же.
String shellCommandLabel(AppLocalizations l10n, ShellCommandId id) =>
    switch (id) {
      ShellCommandId.inbox => l10n.inbox,
      ShellCommandId.today => l10n.todayView,
      ShellCommandId.upcoming => l10n.upcomingView,
      ShellCommandId.projects => l10n.myProjects,
      ShellCommandId.filtersLabels => l10n.filtersAndLabels,
      ShellCommandId.settings => l10n.settings,
      ShellCommandId.theme => l10n.themeSection,
      ShellCommandId.addTask => l10n.addTask,
      ShellCommandId.addProject => l10n.addProject,
      ShellCommandId.addLabel => l10n.addLabel,
      ShellCommandId.addFilter => l10n.addFilter,
      ShellCommandId.sync => l10n.syncNow,
      ShellCommandId.toggleSidebar => l10n.toggleSidebar,
      ShellCommandId.search => l10n.search,
    };

/// Значок команды — тот же, что у пункта сайдбара.
IconData shellCommandIcon(ShellCommandId id) => switch (id) {
  ShellCommandId.inbox => Icons.inbox_outlined,
  ShellCommandId.today => Icons.calendar_today_outlined,
  ShellCommandId.upcoming => Icons.calendar_month_outlined,
  ShellCommandId.projects => Icons.folder_outlined,
  ShellCommandId.filtersLabels => Icons.grid_view_outlined,
  ShellCommandId.settings => Icons.settings_outlined,
  ShellCommandId.theme => Icons.palette_outlined,
  ShellCommandId.addTask => Icons.add_circle_outline,
  ShellCommandId.addProject => Icons.create_new_folder_outlined,
  ShellCommandId.addLabel => Icons.label_outline,
  ShellCommandId.addFilter => Icons.filter_alt_outlined,
  ShellCommandId.sync => Icons.sync,
  ShellCommandId.toggleSidebar => Icons.view_sidebar_outlined,
  ShellCommandId.search => Icons.search,
};

/// Подсказка клавиши: «G, затем I», «Ctrl+1», «Ctrl+Shift+F», «/».
String chordLabel(AppLocalizations l10n, ShellChord chord) {
  if (chord.character case final c?) return c;
  final key = _keyName(chord.key!);
  if (chord.prefix case final p?) return l10n.keyThen(_keyName(p), key);
  return [
    if (chord.ctrl) 'Ctrl',
    if (chord.alt) 'Alt',
    if (chord.shift) 'Shift',
    key,
  ].join('+');
}

String _keyName(LogicalKeyboardKey key) => key.keyLabel.toUpperCase();
