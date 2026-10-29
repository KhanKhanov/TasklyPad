import 'package:flutter/material.dart';

import '../../../app/theme/app_palette.dart';
import '../../../domain/workspace.dart';
import '../../../l10n/app_localizations.dart';
import '../../common/ui/ui_kit.dart';
import '../../common/ui/layout.dart';
import 'label_dialog.dart';
import 'label_tile.dart';

/// Страница «Фильтры и метки», как в Todoist: раздел «Метки» с «+» и
/// списком меток (значок цвета метки, название, число задач, меню «⋯»).
/// Раздел «Мои фильтры» появится вместе с фильтрами (M5).
class FiltersLabelsScreen extends StatelessWidget {
  const FiltersLabelsScreen({super.key});

  @override
  Widget build(BuildContext context) => WorkspaceView(builder: _build);

  Widget _build(BuildContext context, Workspace ws) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final labels = ws.labels;
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
            Container(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: palette.divider)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.labelsHeader,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.addLabel,
                    icon: const Icon(Icons.add, size: 20),
                    onPressed: () => showLabelDialog(context),
                  ),
                ],
              ),
            ),
            if (labels.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  l10n.noLabels,
                  style: TextStyle(color: palette.textSecondary),
                ),
              ),
            for (final label in labels)
              LabelTile(
                key: ValueKey(label.id),
                label: label,
                count: ws.labelTaskCount(label.id),
              ),
          ],
        ),
      ),
    );
  }
}
