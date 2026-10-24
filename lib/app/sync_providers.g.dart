// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Ядро данных этого запуска. Создаётся асинхронно в `main` (`bootstrap`) до
/// первого кадра и подставляется через `ProviderScope(overrides: …)`, поэтому
/// остальные провайдеры получают готовую базу без состояния «загрузка».

@ProviderFor(syncServices)
final syncServicesProvider = SyncServicesProvider._();

/// Ядро данных этого запуска. Создаётся асинхронно в `main` (`bootstrap`) до
/// первого кадра и подставляется через `ProviderScope(overrides: …)`, поэтому
/// остальные провайдеры получают готовую базу без состояния «загрузка».

final class SyncServicesProvider
    extends $FunctionalProvider<SyncServices, SyncServices, SyncServices>
    with $Provider<SyncServices> {
  /// Ядро данных этого запуска. Создаётся асинхронно в `main` (`bootstrap`) до
  /// первого кадра и подставляется через `ProviderScope(overrides: …)`, поэтому
  /// остальные провайдеры получают готовую базу без состояния «загрузка».
  SyncServicesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncServicesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncServicesHash();

  @$internal
  @override
  $ProviderElement<SyncServices> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SyncServices create(Ref ref) {
    return syncServices(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyncServices value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SyncServices>(value),
    );
  }
}

String _$syncServicesHash() => r'ea2718e961e592f873c230d54e35a6e566343a54';

/// База приложения: только для чтения (запросы и `watch`) в репозиториях.
/// Запись — через [mutatorProvider].

@ProviderFor(appDatabase)
final appDatabaseProvider = AppDatabaseProvider._();

/// База приложения: только для чтения (запросы и `watch`) в репозиториях.
/// Запись — через [mutatorProvider].

final class AppDatabaseProvider
    extends $FunctionalProvider<AppDatabase, AppDatabase, AppDatabase>
    with $Provider<AppDatabase> {
  /// База приложения: только для чтения (запросы и `watch`) в репозиториях.
  /// Запись — через [mutatorProvider].
  AppDatabaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appDatabaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appDatabaseHash();

  @$internal
  @override
  $ProviderElement<AppDatabase> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppDatabase create(Ref ref) {
    return appDatabase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppDatabase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppDatabase>(value),
    );
  }
}

String _$appDatabaseHash() => r'02a3d550dc8d9786b80523c318c6bec88e98ca0e';

/// Движок слияния — один на базу.

@ProviderFor(mergeEngine)
final mergeEngineProvider = MergeEngineProvider._();

/// Движок слияния — один на базу.

final class MergeEngineProvider
    extends $FunctionalProvider<MergeEngine, MergeEngine, MergeEngine>
    with $Provider<MergeEngine> {
  /// Движок слияния — один на базу.
  MergeEngineProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mergeEngineProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mergeEngineHash();

  @$internal
  @override
  $ProviderElement<MergeEngine> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  MergeEngine create(Ref ref) {
    return mergeEngine(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MergeEngine value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MergeEngine>(value),
    );
  }
}

String _$mergeEngineHash() => r'2abcb402cf83ff93df8528d4e86616a76095ab1a';

/// Единственная точка записи данных пользователя.

@ProviderFor(mutator)
final mutatorProvider = MutatorProvider._();

/// Единственная точка записи данных пользователя.

final class MutatorProvider
    extends $FunctionalProvider<Mutator, Mutator, Mutator>
    with $Provider<Mutator> {
  /// Единственная точка записи данных пользователя.
  MutatorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mutatorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mutatorHash();

  @$internal
  @override
  $ProviderElement<Mutator> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Mutator create(Ref ref) {
    return mutator(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Mutator value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Mutator>(value),
    );
  }
}

String _$mutatorHash() => r'3fa06b631a804d86d5be607675f1677d2a24e009';
