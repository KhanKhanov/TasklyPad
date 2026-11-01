import 'package:flutter/material.dart';

import '../../../app/theme/app_palette.dart';
import '../../../l10n/app_localizations.dart';
import '../../common/ui/layout.dart';
import 'general_section.dart';
import 'sync_section.dart';
import 'theme_section.dart';

/// Экран «Настройки». Разделы Todoist — в его порядке («Основное», «Тема»),
/// наша «Синхронизация» — после них; окно с разделами слева, как в Todoist, —
/// M10. [section] `theme` — экран открывается на «Теме» (`o t`).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.section});

  final String? section;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final GlobalKey _theme = GlobalKey();

  @override
  void initState() {
    super.initState();
    _scrollToSection();
  }

  /// `o t` на уже открытых «Настройках» — тот же экран с новым разделом.
  @override
  void didUpdateWidget(SettingsScreen old) {
    super.didUpdateWidget(old);
    if (widget.section != old.section) _scrollToSection();
  }

  void _scrollToSection() {
    if (widget.section != 'theme') return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _theme.currentContext;
      if (target != null && target.mounted) Scrollable.ensureVisible(target);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: contentMaxWidth),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(32, 8, 32, 48),
          children: [
            Text(
              l10n.settings,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 26,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 24),
            const GeneralSection(),
            const SizedBox(height: 32),
            ThemeSection(key: _theme),
            const SizedBox(height: 32),
            const SyncSection(),
          ],
        ),
      ),
    );
  }
}

/// Заголовок раздела настроек с линией снизу.
class SettingsHeader extends StatelessWidget {
  const SettingsHeader(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.only(bottom: 8),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.divider)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: palette.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
