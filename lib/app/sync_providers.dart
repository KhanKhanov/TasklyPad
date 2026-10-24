import 'package:oplog_sync/oplog_sync.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/app_database.dart';
import '../sync/mutator.dart';
import '../sync/sync_services.dart';

part 'sync_providers.g.dart';

/// Ядро данных этого запуска. Создаётся асинхронно в `main` (`bootstrap`) до
/// первого кадра и подставляется через `ProviderScope(overrides: …)`, поэтому
/// остальные провайдеры получают готовую базу без состояния «загрузка».
@Riverpod(keepAlive: true)
SyncServices syncServices(Ref ref) => throw UnimplementedError(
  'syncServicesProvider задаётся в main через ProviderScope.overrides',
);

/// База приложения: только для чтения (запросы и `watch`) в репозиториях.
/// Запись — через [mutatorProvider].
@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) => ref.watch(syncServicesProvider).db;

/// Движок слияния — один на базу.
@Riverpod(keepAlive: true)
MergeEngine mergeEngine(Ref ref) => ref.watch(syncServicesProvider).engine;

/// Единственная точка записи данных пользователя.
@Riverpod(keepAlive: true)
Mutator mutator(Ref ref) => ref.watch(syncServicesProvider).mutator;
