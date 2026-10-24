// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Планер';

  @override
  String get inbox => 'Входящие';

  @override
  String get inboxEmpty => 'Пока нет задач';

  @override
  String get startupErrorTitle => 'Не удалось открыть данные';

  @override
  String startupSchemaTooNew(int found, int supported) {
    return 'Данные сохранены более новой версией приложения (схема $found, эта версия знает до $supported). Обновите приложение — данные не тронуты.';
  }

  @override
  String startupErrorDetails(String error) {
    return 'Данные не изменены. Подробности: $error';
  }
}
