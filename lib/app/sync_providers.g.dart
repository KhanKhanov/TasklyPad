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

/// Профиль данных этого запуска (`--profile`, lib/app/profile.dart);
/// `null` — основной. Задаётся в `main` через `ProviderScope.overrides`.

@ProviderFor(appProfile)
final appProfileProvider = AppProfileProvider._();

/// Профиль данных этого запуска (`--profile`, lib/app/profile.dart);
/// `null` — основной. Задаётся в `main` через `ProviderScope.overrides`.

final class AppProfileProvider
    extends $FunctionalProvider<String?, String?, String?>
    with $Provider<String?> {
  /// Профиль данных этого запуска (`--profile`, lib/app/profile.dart);
  /// `null` — основной. Задаётся в `main` через `ProviderScope.overrides`.
  AppProfileProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appProfileProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appProfileHash();

  @$internal
  @override
  $ProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String? create(Ref ref) {
    return appProfile(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$appProfileHash() => r'd1ba7d9ae80b44fbf3d9c9270d86e072f6309c47';

/// Синхронизация с общей папкой. В `info.json` уходят имя компьютера,
/// платформа и профиль — чтобы в списке устройств различать два профиля
/// одного ПК. Это остаётся в папке синхронизации пользователя.

@ProviderFor(syncRunner)
final syncRunnerProvider = SyncRunnerProvider._();

/// Синхронизация с общей папкой. В `info.json` уходят имя компьютера,
/// платформа и профиль — чтобы в списке устройств различать два профиля
/// одного ПК. Это остаётся в папке синхронизации пользователя.

final class SyncRunnerProvider
    extends $FunctionalProvider<SyncRunner, SyncRunner, SyncRunner>
    with $Provider<SyncRunner> {
  /// Синхронизация с общей папкой. В `info.json` уходят имя компьютера,
  /// платформа и профиль — чтобы в списке устройств различать два профиля
  /// одного ПК. Это остаётся в папке синхронизации пользователя.
  SyncRunnerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncRunnerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncRunnerHash();

  @$internal
  @override
  $ProviderElement<SyncRunner> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SyncRunner create(Ref ref) {
    return syncRunner(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyncRunner value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SyncRunner>(value),
    );
  }
}

String _$syncRunnerHash() => r'b666830bc5da576b6ede81b0556682a47a5db44d';

/// Системный диалог выбора папки; в тестах — фейк.

@ProviderFor(folderPicker)
final folderPickerProvider = FolderPickerProvider._();

/// Системный диалог выбора папки; в тестах — фейк.

final class FolderPickerProvider
    extends $FunctionalProvider<FolderPicker, FolderPicker, FolderPicker>
    with $Provider<FolderPicker> {
  /// Системный диалог выбора папки; в тестах — фейк.
  FolderPickerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'folderPickerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$folderPickerHash();

  @$internal
  @override
  $ProviderElement<FolderPicker> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  FolderPicker create(Ref ref) {
    return folderPicker(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FolderPicker value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FolderPicker>(value),
    );
  }
}

String _$folderPickerHash() => r'0c2cb16072b633b2cb4a8fe1740b8ead9280eed6';
