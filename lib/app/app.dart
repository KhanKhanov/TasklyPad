import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../domain/theme_settings.dart';
import '../l10n/app_localizations.dart';
import 'data_providers.dart';
import 'router.dart';
import 'theme/app_themes.dart';

/// Корневой виджет приложения: тема, локализация, роутер.
///
/// Тема и внешний вид — из «Настройки → Тема» (общие или этого устройства,
/// `ThemeSettings.effective`); до первого ответа потока — прочитанные при
/// запуске.
class PlannerApp extends ConsumerWidget {
  const PlannerApp({super.key});

  static final Logger _log = Logger();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    // Ошибка чтения — тема, прочитанная при запуске: оформление не повод
    // показывать экран ошибки.
    ref.listen(themeSettingsProvider, (_, next) {
      if (next case AsyncError(:final error, :final stackTrace)) {
        _log.e('Тема не прочитана', error: error, stackTrace: stackTrace);
      }
    });
    final ThemeSettings settings =
        ref.watch(themeSettingsProvider).value ??
        ref.watch(initialThemeSettingsProvider);
    final choice = settings.effective;
    final theme = appThemeById(choice.themeId);
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildThemeData(theme.light, Brightness.light),
      darkTheme: buildThemeData(theme.dark, Brightness.dark),
      themeMode: switch (choice.appearance) {
        ThemeAppearance.light => ThemeMode.light,
        ThemeAppearance.dark => ThemeMode.dark,
        ThemeAppearance.system => ThemeMode.system,
      },
      routerConfig: router,
    );
  }
}
