// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Planner';

  @override
  String get inbox => 'Inbox';

  @override
  String get inboxEmpty => 'No tasks yet';

  @override
  String get startupErrorTitle => 'Couldn\'t open your data';

  @override
  String startupSchemaTooNew(int found, int supported) {
    return 'Your data was saved by a newer version of the app (schema $found, this version supports up to $supported). Update the app — your data is untouched.';
  }

  @override
  String startupErrorDetails(String error) {
    return 'Your data was not changed. Details: $error';
  }
}
