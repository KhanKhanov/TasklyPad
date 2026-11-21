import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';

/// Локализации приложения: наши строки и строки Material-виджетов
/// (`material_ui`) — «Отмена», «Вставить», подсказки.
///
/// `AppLocalizations.localizationsDelegates` не годится: gen-l10n Flutter 3.50
/// подключает в нём строки устаревшей `package:flutter/material.dart`, а
/// виджеты `material_ui` их не видят и пишут по-английски (О-87).
const List<LocalizationsDelegate<Object?>> appLocalizationsDelegates = [
  AppLocalizations.delegate,
  ...GlobalMaterialLocalizations.delegates,
];
