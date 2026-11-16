import 'package:flutter/material.dart';

import '../../../app/theme/app_palette.dart';
import '../../../domain/markdown_text.dart';
import '../../../domain/models.dart';
import '../../../domain/recently_viewed.dart';
import '../../../domain/search.dart';
import '../../../domain/workspace.dart';
import '../../../l10n/app_localizations.dart';
import '../../common/ui/ui_kit.dart';
import '../../filters/ui/filter_tile.dart';
import '../../shell/logic/shell_commands.dart';
import '../../shell/ui/shell_command_texts.dart';
import '../logic/search_items.dart';

/// Строка окна «Поиск»: значок, текст, подпись, справа — подсказка клавиши
/// или кнопка. [selected] — строка под ↑/↓.
class SearchTile extends StatelessWidget {
  const SearchTile({
    super.key,
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
    this.iconColor,
    this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Material(
      color: selected ? palette.selected : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        canRequestFocus: false,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              Icon(icon, size: 18, color: iconColor ?? palette.textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: palette.textPrimary),
                    ),
                    if (subtitle case final s? when s.isNotEmpty)
                      Text(
                        s,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: palette.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

/// Заголовок группы строк; справа — [action] («Удалить» у недавних).
class SearchHeader extends StatelessWidget {
  const SearchHeader(this.text, {super.key, this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(10, 12, 4, 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppPalette.of(context).textSecondary,
            ),
          ),
        ),
        ?action,
      ],
    ),
  );
}

/// Значок, текст и подпись строки [item] по снимку [ws]. Подсказки клавиш
/// команд — при [showKeys] (на телефоне клавиатуры нет — допущение О-69).
({IconData icon, Color? color, String title, String? subtitle, String? keys})
searchItemLook(
  AppLocalizations l10n,
  Workspace ws,
  SearchItem item, {
  required bool showKeys,
}) => switch (item) {
  RecentSearchRow(:final text) => (
    icon: Icons.history,
    color: null,
    title: text,
    subtitle: null,
    keys: null,
  ),
  ViewedRow(:final item) => _viewedLook(l10n, ws, item),
  CommandRow(:final id) => (
    icon: shellCommandIcon(id),
    color: null,
    title: shellCommandLabel(l10n, id),
    subtitle: null,
    keys: showKeys ? _keys(l10n, id) : null,
  ),
  HitRow(:final hit) => _hitLook(l10n, ws, hit),
  CompletedRow(:final task) => (
    icon: Icons.check_circle_outline,
    color: null,
    title: plainText(task.content),
    subtitle: _place(l10n, ws, task),
    keys: null,
  ),
  SearchCompletedRow() => (
    icon: Icons.task_alt,
    color: null,
    title: l10n.searchCompleted,
    subtitle: null,
    keys: null,
  ),
  SaveAsFilterRow() => (
    icon: filterIcon,
    color: null,
    title: l10n.saveAsFilter,
    subtitle: null,
    keys: null,
  ),
};

String? _keys(AppLocalizations l10n, ShellCommandId id) {
  final chords = shellCommand(id).chords;
  return chords.isEmpty ? null : chordLabel(l10n, chords.first);
}

({IconData icon, Color? color, String title, String? subtitle, String? keys})
_hitLook(AppLocalizations l10n, Workspace ws, SearchHit hit) => switch (hit) {
  TaskHit(:final task) => (
    icon: Icons.radio_button_unchecked,
    color: null,
    title: plainText(task.content),
    subtitle: _place(l10n, ws, task),
    keys: null,
  ),
  ProjectHit(:final project) => _projectLook(l10n, project),
  SectionHit(:final section, :final project) => (
    icon: Icons.view_agenda_outlined,
    color: null,
    title: section.name,
    subtitle: projectTitle(l10n, project),
    keys: null,
  ),
  LabelHit(:final label) => (
    icon: Icons.sell_outlined,
    color: projectColor(label.color),
    title: label.name,
    subtitle: null,
    keys: null,
  ),
  FilterHit(:final filter) => (
    icon: filterIcon,
    color: projectColor(filter.color),
    title: filter.name,
    subtitle: null,
    keys: null,
  ),
};

({IconData icon, Color? color, String title, String? subtitle, String? keys})
_projectLook(AppLocalizations l10n, Project project) => (
  icon: project.isInbox ? Icons.inbox_outlined : Icons.tag,
  color: project.isInbox ? null : projectColor(project.color),
  title: projectTitle(l10n, project),
  subtitle: null,
  keys: null,
);

({IconData icon, Color? color, String title, String? subtitle, String? keys})
_viewedLook(AppLocalizations l10n, Workspace ws, ViewedItem item) {
  ({IconData icon, Color? color, String title, String? subtitle, String? keys})
  command(ShellCommandId id) => (
    icon: shellCommandIcon(id),
    color: null,
    title: shellCommandLabel(l10n, id),
    subtitle: null,
    keys: null,
  );
  return switch (item.kind) {
    ViewedKind.inbox => command(ShellCommandId.inbox),
    ViewedKind.today => command(ShellCommandId.today),
    ViewedKind.upcoming => command(ShellCommandId.upcoming),
    ViewedKind.task => switch (ws.task(item.id!)!) {
      // Выполненная — значком выполненной, как в «Выполненных задачах».
      final task when task.isCompleted => searchItemLook(
        l10n,
        ws,
        CompletedRow(task),
        showKeys: false,
      ),
      final task => _hitLook(l10n, ws, TaskHit(task)),
    },
    ViewedKind.project => _projectLook(l10n, ws.project(item.id!)!),
    ViewedKind.label => _hitLook(l10n, ws, LabelHit(ws.label(item.id!)!)),
    ViewedKind.filter => _hitLook(l10n, ws, FilterHit(ws.filter(item.id!)!)),
  };
}

/// Просмотренное ещё есть в снимке: удалённое и архивное не показывается.
bool viewedAlive(Workspace ws, ViewedItem item) => switch (item.kind) {
  ViewedKind.task => ws.task(item.id!) != null,
  ViewedKind.project =>
    ws.project(item.id!) != null && !ws.isProjectArchived(item.id!),
  ViewedKind.label => ws.label(item.id!) != null,
  ViewedKind.filter => ws.filter(item.id!) != null,
  _ => true,
};

/// «Проект / Раздел» задачи — где она видна.
String _place(AppLocalizations l10n, Workspace ws, Task task) {
  final project = ws.project(ws.rootProjectOf(task.id));
  final section = ws.rootSectionOf(task.id);
  return [
    if (project != null) projectTitle(l10n, project),
    ?section?.name,
  ].join(' / ');
}
