import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import 'router.dart';

/// Корневой виджет приложения: тема, локализация, роутер.
class PlannerApp extends ConsumerWidget {
  const PlannerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(colorSchemeSeed: const Color(0xFFDC4C3E)),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFFDC4C3E),
        brightness: Brightness.dark,
      ),
      routerConfig: router,
    );
  }
}
