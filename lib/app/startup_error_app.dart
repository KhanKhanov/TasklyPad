import 'package:flutter/material.dart';

import '../data/db_backup.dart';
import '../l10n/app_localizations.dart';

/// Приложение вместо основного, если данные не открылись при запуске.
///
/// Ничего не пишет и не пытается «починить» базу: сохранность данных важнее
/// того, чтобы приложение открылось.
class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(colorSchemeSeed: const Color(0xFFDC4C3E)),
      home: Builder(
        builder: (context) {
          final l10n = AppLocalizations.of(context);
          final message = switch (error) {
            SchemaTooNewException(:final found, :final supported) =>
              l10n.startupSchemaTooNew(found, supported),
            _ => l10n.startupErrorDetails('$error'),
          };
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.startupErrorTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    SelectableText(message, textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
