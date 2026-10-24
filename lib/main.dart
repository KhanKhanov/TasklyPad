import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import 'app/app.dart';
import 'app/bootstrap.dart';
import 'app/startup_error_app.dart';
import 'app/sync_providers.dart';
import 'sync/sync_services.dart';

Future<void> main() async {
  // Плагины (пути, база) доступны только после инициализации движка Flutter.
  WidgetsFlutterBinding.ensureInitialized();
  final SyncServices services;
  try {
    services = await bootstrap();
  } catch (error, stack) {
    Logger().e('База не открылась', error: error, stackTrace: stack);
    runApp(StartupErrorApp(error: error));
    return;
  }
  // ProviderScope — корень Riverpod: хранит состояние всех провайдеров.
  // Готовое ядро данных подставляется сюда, остальные провайдеры — от него.
  runApp(
    ProviderScope(
      overrides: [syncServicesProvider.overrideWithValue(services)],
      child: const PlannerApp(),
    ),
  );
}
