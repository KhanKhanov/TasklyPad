import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import 'router.dart';
import 'theme/app_themes.dart';

/// Корневой виджет приложения: тема, локализация, роутер.
///
/// Тема — Taskly; светлый или тёмный вариант — как в системе. Выбор темы и
/// варианта — M2.3 (docs/plans/m2-core-app.md).
class PlannerApp extends ConsumerWidget {
  const PlannerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildThemeData(tasklyTheme.light, Brightness.light),
      darkTheme: buildThemeData(tasklyTheme.dark, Brightness.dark),
      routerConfig: router,
    );
  }
}
