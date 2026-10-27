import 'dart:io';

import 'package:oplog_sync/oplog_sync.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/app_database.dart';
import '../platform/folder_picker.dart';
import '../platform/windows/file_selector_folder_picker.dart';
import '../sync/io_sync_fs.dart';
import '../sync/mutator.dart';
import '../sync/sync_runner.dart';
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

/// Профиль данных этого запуска (`--profile`, lib/app/profile.dart);
/// `null` — основной. Задаётся в `main` через `ProviderScope.overrides`.
@Riverpod(keepAlive: true)
String? appProfile(Ref ref) => null;

/// Синхронизация с общей папкой. В `info.json` уходят имя компьютера,
/// платформа и профиль — чтобы в списке устройств различать два профиля
/// одного ПК. Это остаётся в папке синхронизации пользователя.
@Riverpod(keepAlive: true)
SyncRunner syncRunner(Ref ref) => SyncRunner(
  services: ref.watch(syncServicesProvider),
  openFs: IoSyncFs.new,
  deviceInfo: {
    'device': Platform.localHostname,
    'platform': Platform.operatingSystem,
    'profile': ?ref.watch(appProfileProvider),
  },
);

/// Системный диалог выбора папки; в тестах — фейк. Пока только Windows:
/// Android — через SAF (M6, О-30).
@Riverpod(keepAlive: true)
FolderPicker folderPicker(Ref ref) => Platform.isWindows
    ? const FileSelectorFolderPicker()
    : const UnsupportedFolderPicker();
