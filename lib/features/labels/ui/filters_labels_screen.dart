import 'package:flutter/material.dart';

import '../../../app/theme/app_palette.dart';
import '../../../domain/workspace.dart';
import '../../../l10n/app_localizations.dart';
import '../../common/ui/ui_kit.dart';
import '../../common/ui/layout.dart';
import '../../filters/ui/filter_dialog.dart';
import '../../filters/ui/filter_drag.dart';
import '../../filters/ui/filter_tile.dart';
import 'label_dialog.dart';
import 'label_drag.dart';
import 'label_tile.dart';

/// Страница «Фильтры и метки», как в Todoist: «Мои фильтры» и «Метки», у
/// каждого раздела «+» и список по порядку (перетаскиванием); у метки — число
/// задач, у обоих — меню «⋯» при наведении (help «Introduction to filters»,
/// «Introduction to labels»).
class FiltersLabelsScreen extends StatelessWidget {
  const FiltersLabelsScreen({super.key});

  @override
  Widget build(BuildContext context) => WorkspaceView(builder: _build);

  Widget _build(BuildContext context, Workspace ws) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final labels = ws.labels;
    final filters = ws.filters;
    Widget empty(String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(text, style: TextStyle(color: palette.textSecondary)),
    );
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: contentMaxWidth),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(32, 8, 32, 48),
          children: [
            Text(
              l10n.filtersAndLabels,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 26,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            _SectionHeader(
              title: l10n.myFilters,
              addTooltip: l10n.addFilter,
              onAdd: () => showFilterDialog(context),
            ),
            if (filters.isEmpty) empty(l10n.noFilters),
            for (final filter in filters)
              FilterDragTile(
                key: ValueKey(filter.id),
                filter: filter,
                filters: filters,
                child: FilterTile(filter: filter),
              ),
            const SizedBox(height: 24),
            _SectionHeader(
              title: l10n.labelsHeader,
              addTooltip: l10n.addLabel,
              onAdd: () => showLabelDialog(context),
            ),
            if (labels.isEmpty) empty(l10n.noLabels),
            for (final label in labels)
              LabelDragTile(
                key: ValueKey(label.id),
                label: label,
                labels: labels,
                child: LabelTile(
                  label: label,
                  count: ws.labelTaskCount(label.id),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Заголовок раздела страницы с «+» справа, над чертой.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.addTooltip,
    required this.onAdd,
  });

  final String title;
  final String addTooltip;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: palette.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            tooltip: addTooltip,
            icon: const Icon(Icons.add, size: 20),
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}
