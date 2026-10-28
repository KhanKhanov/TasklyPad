import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import 'app/app.dart';
import 'app/bootstrap.dart';
import 'app/data_providers.dart';
import 'app/profile.dart';
import 'app/startup_error_app.dart';
import 'app/sync_providers.dart';
import 'data/repositories/theme_settings_repository.dart';
import 'domain/theme_settings.dart';
import 'sync/sync_services.dart';

Future<void> main(List<String> args) async {
  // Плагины (пути, база) доступны только после инициализации движка Flutter.
  WidgetsFlutterBinding.ensureInitialized();
  final SyncServices services;
  final String? profile;
  try {
    profile = profileFromArgs(args);
    services = await bootstrap(profile: profile);
  } catch (error, stack) {
    Logger().e('База не открылась', error: error, stackTrace: stack);
    // ProviderScope и здесь: экран ошибки провайдеров не читает, но так у
    // каждого runApp один корень, и виджеты с ref не упадут, если появятся.
    runApp(ProviderScope(child: StartupErrorApp(error: error)));
    return;
  }
  // Тема — до первого кадра, иначе тёмная мигнула бы светлой. Не прочиталась —
  // умолчания: оформление не повод показывать экран ошибки.
  var theme = const ThemeSettings();
  try {
    theme = await ThemeSettingsRepository(services.db).load();
  } catch (error, stack) {
    Logger().e('Тема не прочитана', error: error, stackTrace: stack);
  }
  // ProviderScope — корень Riverpod: хранит состояние всех провайдеров.
  // Готовое ядро данных подставляется сюда, остальные провайдеры — от него.
  runApp(
    ProviderScope(
      overrides: [
        syncServicesProvider.overrideWithValue(services),
        appProfileProvider.overrideWithValue(profile),
        initialThemeSettingsProvider.overrideWithValue(theme),
      ],
      child: const PlannerApp(),
    ),
  );
}
