import 'package:flutter/material.dart';

import '../../../app/theme/app_palette.dart';
import '../../../domain/workspace.dart';
import '../../../l10n/app_localizations.dart';
import '../logic/search_items.dart';
import 'search_tiles.dart';

/// Строки окна «Поиск» с заголовками групп: «Недавние поисковые запросы» (с
/// «Удалить»), «Недавно просмотренные», «Команды», «Выполненные задачи».
/// [selected] — строка под ↑/↓, список прокручивается к ней;
/// [onRemoveRecent] — крестик у запроса. Строки строятся по мере прокрутки:
/// короткое слово находит сотни задач.
class SearchList extends StatefulWidget {
  const SearchList({
    super.key,
    required this.ws,
    required this.items,
    required this.selected,
    required this.showKeys,
    required this.onTap,
    required this.onRemoveRecent,
    required this.onClearRecent,
  });

  final Workspace ws;
  final List<SearchItem> items;
  final int selected;
  final bool showKeys;
  final ValueChanged<SearchItem> onTap;
  final ValueChanged<String> onRemoveRecent;
  final VoidCallback onClearRecent;

  @override
  State<SearchList> createState() => _SearchListState();
}

class _SearchListState extends State<SearchList> {
  /// Ключ выбранной строки — чтобы прокрутить к ней.
  final GlobalKey _selectedKey = GlobalKey();

  @override
  void didUpdateWidget(SearchList old) {
    super.didUpdateWidget(old);
    if (widget.selected == old.selected || widget.selected < 0) return;
    // ↑/↓ двигают выбор на одну строку, соседняя уже построена (запас
    // прокрутки списка), поэтому её контекст есть после кадра.
    final down = widget.selected > old.selected;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final row = _selectedKey.currentContext;
      if (row == null || !row.mounted) return;
      Scrollable.ensureVisible(
        row,
        alignmentPolicy: down
            ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
            : ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = widget.items;
    // Строки списка: заголовок группы перед строкой (true) и сама строка.
    final rows = <(int, bool)>[
      for (var i = 0; i < items.length; i++) ...[
        if (_startsGroup(items[i], i == 0 ? null : items[i - 1])) (i, true),
        (i, false),
      ],
    ];
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      itemCount: rows.length,
      itemBuilder: (context, row) => switch (rows[row]) {
        (final i, true) => _header(l10n, items[i])!,
        (final i, false) => _tile(context, l10n, items[i], i),
      },
    );
  }

  /// С [item] начинается группа с заголовком (найденное — без заголовка:
  /// его называет вкладка).
  static bool _startsGroup(SearchItem item, SearchItem? before) =>
      before?.runtimeType != item.runtimeType &&
      switch (item) {
        RecentSearchRow() ||
        ViewedRow() ||
        CommandRow() ||
        CompletedRow() => true,
        _ => false,
      };

  /// Заголовок группы, которую начинает [item].
  Widget? _header(AppLocalizations l10n, SearchItem item) {
    return switch (item) {
      RecentSearchRow() => SearchHeader(
        l10n.recentSearches,
        action: TextButton(
          onPressed: widget.onClearRecent,
          child: Text(l10n.recentSearchesClear),
        ),
      ),
      ViewedRow() => SearchHeader(l10n.recentlyViewed),
      CommandRow() => SearchHeader(l10n.searchCommands),
      CompletedRow() => SearchHeader(l10n.completedTasks),
      _ => null,
    };
  }

  Widget _tile(
    BuildContext context,
    AppLocalizations l10n,
    SearchItem item,
    int index,
  ) {
    final look = searchItemLook(
      l10n,
      widget.ws,
      item,
      showKeys: widget.showKeys,
    );
    final palette = AppPalette.of(context);
    final trailing = switch (item) {
      RecentSearchRow(:final text) => IconButton(
        tooltip: l10n.recentSearchRemove,
        visualDensity: VisualDensity.compact,
        icon: const Icon(Icons.close, size: 16),
        color: palette.textSecondary,
        onPressed: () => widget.onRemoveRecent(text),
      ),
      _ when look.keys != null => Text(
        look.keys!,
        style: TextStyle(fontSize: 12, color: palette.textSecondary),
      ),
      _ => null,
    };
    final selected = index == widget.selected;
    return SearchTile(
      key: selected ? _selectedKey : null,
      icon: look.icon,
      iconColor: look.color,
      title: look.title,
      subtitle: look.subtitle,
      trailing: trailing,
      selected: selected,
      onTap: () => widget.onTap(item),
    );
  }
}
