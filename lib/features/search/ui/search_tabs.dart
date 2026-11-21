import 'package:material_ui/material_ui.dart';

import '../../../domain/search.dart';
import '../../../l10n/app_localizations.dart';

/// Вкладки результатов поиска словами — только непустые (help «Introduction
/// to search»: «Top» и соседние разделы сужают результаты).
class SearchTabs extends StatelessWidget {
  const SearchTabs({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onSelected,
  });

  final List<SearchTab> tabs;
  final SearchTab selected;
  final ValueChanged<SearchTab> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          for (final tab in tabs)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(searchTabLabel(l10n, tab)),
                selected: tab == selected,
                onSelected: (_) => onSelected(tab),
              ),
            ),
        ],
      ),
    );
  }
}

/// Подпись вкладки.
String searchTabLabel(AppLocalizations l10n, SearchTab tab) => switch (tab) {
  SearchTab.top => l10n.searchTop,
  SearchTab.tasks => l10n.searchTabTasks,
  SearchTab.descriptions => l10n.searchTabDescriptions,
  SearchTab.projects => l10n.searchTabProjects,
  SearchTab.sections => l10n.searchTabSections,
  SearchTab.labels => l10n.searchTabLabels,
  SearchTab.filters => l10n.searchTabFilters,
};
