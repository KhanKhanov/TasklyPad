import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/data_providers.dart';
import '../../../domain/recently_viewed.dart';
import '../../../domain/search.dart';
import '../../../l10n/app_localizations.dart';
import '../../common/ui/ui_kit.dart';
import '../../filters/ui/filter_dialog.dart';
import '../../shell/logic/shell_commands.dart';
import '../../tasks/ui/task_panel.dart';
import '../logic/search_input.dart';
import '../logic/search_items.dart';

/// Что делает выбранная строка окна «Поиск»: окно закрывается, а экран или
/// окно открывается в [shell] — контексте оболочки, который живёт после
/// закрытия поиска. Найденное, выполненная задача и «Сохранить как фильтр»
/// записывают запрос в недавние (help: «saves up to five keywords»; когда —
/// в help не описано, допущение О-69).
final class SearchActions {
  const SearchActions({required this.shell, required this.run});

  final BuildContext shell;
  final ValueChanged<ShellCommandId> run;

  /// Выполнить строку [item] окна [dialog]; [text] — строка поиска.
  void activate(
    BuildContext dialog,
    WidgetRef ref,
    SearchItem item,
    String text,
  ) {
    // Окно закроется раньше, чем кончится запись: сбой показывает тост
    // оболочки, ошибку программы видят журнал и тесты.
    final messenger = ScaffoldMessenger.of(shell);
    final l10n = AppLocalizations.of(shell);
    final commands = ref.read(recentSearchCommandsProvider);
    void remember() =>
        unawaited(runGuarded(messenger, l10n, () => commands.add(text)));
    final String query = switch (item) {
      SaveAsFilterRow() => filterQueryToSave(
        classifySearch(text, now: ref.read(clockProvider).nowWall()),
      ),
      _ => '',
    };
    switch (item) {
      case HitRow() || CompletedRow() || SaveAsFilterRow():
        remember();
      default:
    }
    Navigator.pop(dialog);
    if (!shell.mounted) return;
    switch (item) {
      case CommandRow(:final id):
        run(id);
      case ViewedRow(:final item):
        _openViewed(item);
      case HitRow(:final hit):
        _openHit(hit);
      case CompletedRow(:final task):
        showTaskDialog(shell, task.id).ignore();
      case SaveAsFilterRow():
        showFilterDialog(shell, query: query).ignore();
      case RecentSearchRow() || SearchCompletedRow():
        // Обрабатывает само окно, не закрываясь.
        break;
    }
  }

  void _openHit(SearchHit hit) => switch (hit) {
    TaskHit(:final task) => showTaskDialog(shell, task.id).ignore(),
    ProjectHit(:final project) => navigate(
      shell,
      project.isInbox ? '/' : '/project/${project.id}',
    ),
    // Раздел — экран его проекта, без прокрутки к разделу (допущение О-69).
    SectionHit(:final project) => navigate(
      shell,
      project.isInbox ? '/' : '/project/${project.id}',
    ),
    LabelHit(:final label) => navigate(shell, '/label/${label.id}'),
    FilterHit(:final filter) => navigate(shell, '/filter/${filter.id}'),
  };

  void _openViewed(ViewedItem item) => switch (item.kind) {
    ViewedKind.inbox => run(ShellCommandId.inbox),
    ViewedKind.today => run(ShellCommandId.today),
    ViewedKind.upcoming => run(ShellCommandId.upcoming),
    ViewedKind.task => showTaskDialog(shell, item.id!).ignore(),
    ViewedKind.project => navigate(shell, '/project/${item.id}'),
    ViewedKind.label => navigate(shell, '/label/${item.id}'),
    ViewedKind.filter => navigate(shell, '/filter/${item.id}'),
  };
}
