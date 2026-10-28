import '../../../domain/theme_settings.dart';
import '../../../l10n/app_localizations.dart';

/// Название темы; незнакомая (от более новой версии) — её id.
String themeTitle(AppLocalizations l10n, String themeId) => switch (themeId) {
  'taskly' => l10n.themeTaskly,
  _ => themeId,
};

/// Подпись внешнего вида.
String appearanceTitle(AppLocalizations l10n, ThemeAppearance appearance) =>
    switch (appearance) {
      ThemeAppearance.light => l10n.appearanceLight,
      ThemeAppearance.dark => l10n.appearanceDark,
      ThemeAppearance.system => l10n.appearanceSystem,
    };
