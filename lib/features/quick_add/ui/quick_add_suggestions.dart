import 'package:flutter/material.dart';

import '../../../app/theme/app_palette.dart';
import '../../../l10n/app_localizations.dart';
import '../../common/ui/ui_kit.dart';
import '../logic/suggestions.dart';

/// Список автодополнения под полем: имена проектов, разделов или меток и
/// «Создать …» в конце (help «Use Task Quick Add»). [selected] — пункт под
/// стрелками `↑`/`↓`, его берут `Enter` и `Tab`.
class QuickAddSuggestions extends StatelessWidget {
  const QuickAddSuggestions({
    super.key,
    required this.kind,
    required this.items,
    required this.selected,
    required this.onPick,
  });

  final TokenKind kind;
  final List<Suggestion> items;
  final int selected;
  final ValueChanged<Suggestion> onPick;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    // Нажатие на список — внутри поля: на телефоне поле не теряет фокус.
    return TextFieldTapRegion(
      child: Material(
        elevation: 6,
        color: palette.raised,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320, maxHeight: 260),
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 4),
            shrinkWrap: true,
            children: [
              for (final (i, s) in items.indexed)
                _Item(
                  key: ValueKey('suggestion-$i'),
                  icon: _icon(s, palette),
                  text: s.create
                      ? (kind == TokenKind.project
                            ? l10n.createProject(s.name)
                            : l10n.createLabel(s.name))
                      : s.name,
                  selected: i == selected,
                  onTap: () => onPick(s),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _icon(Suggestion s, AppPalette palette) {
    if (s.create) return Icon(Icons.add, size: 18, color: palette.accent);
    return switch (kind) {
      TokenKind.project when s.color == null => Icon(
        Icons.inbox_outlined,
        size: 18,
        color: palette.textSecondary,
      ),
      TokenKind.project => ProjectHash(color: s.color!, size: 16),
      TokenKind.section => Icon(
        Icons.view_agenda_outlined,
        size: 18,
        color: palette.textSecondary,
      ),
      TokenKind.label => Icon(
        Icons.sell_outlined,
        size: 18,
        color: projectColor(s.color ?? 'charcoal'),
      ),
    };
  }
}

class _Item extends StatelessWidget {
  const _Item({
    super.key,
    required this.icon,
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final Widget icon;
  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Material(
      color: selected ? palette.selected : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              SizedBox(width: 24, child: Center(child: icon)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  text,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? palette.onSelected : palette.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
