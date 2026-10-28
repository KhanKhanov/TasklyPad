// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Когда синхронизироваться (docs/plans/m2-core-app.md, решение 10): при
/// запуске, раз в [period], через [debounce] после своей правки, при
/// возврате окна на передний план и кнопкой «Синхронизировать».

@ProviderFor(SyncController)
final syncControllerProvider = SyncControllerProvider._();

/// Когда синхронизироваться (docs/plans/m2-core-app.md, решение 10): при
/// запуске, раз в [period], через [debounce] после своей правки, при
/// возврате окна на передний план и кнопкой «Синхронизировать».
final class SyncControllerProvider
    extends $NotifierProvider<SyncController, SyncStatus> {
  /// Когда синхронизироваться (docs/plans/m2-core-app.md, решение 10): при
  /// запуске, раз в [period], через [debounce] после своей правки, при
  /// возврате окна на передний план и кнопкой «Синхронизировать».
  SyncControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncControllerHash();

  @$internal
  @override
  SyncController create() => SyncController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyncStatus value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SyncStatus>(value),
    );
  }
}

String _$syncControllerHash() => r'99373a90917cd4d5050659dd5e24a25c33061b1a';

/// Когда синхронизироваться (docs/plans/m2-core-app.md, решение 10): при
/// запуске, раз в [period], через [debounce] после своей правки, при
/// возврате окна на передний план и кнопкой «Синхронизировать».

abstract class _$SyncController extends $Notifier<SyncStatus> {
  SyncStatus build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<SyncStatus, SyncStatus>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SyncStatus, SyncStatus>,
              SyncStatus,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Устройства в папке синхронизации; перечитываются после каждого удачного
/// прохода и после каждой ошибки — неудачный проход не меняет время
/// синхронизации, а папки уже может не быть.

@ProviderFor(syncDevices)
final syncDevicesProvider = SyncDevicesProvider._();

/// Устройства в папке синхронизации; перечитываются после каждого удачного
/// прохода и после каждой ошибки — неудачный проход не меняет время
/// синхронизации, а папки уже может не быть.

final class SyncDevicesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<SyncDevice>>,
          List<SyncDevice>,
          FutureOr<List<SyncDevice>>
        >
    with $FutureModifier<List<SyncDevice>>, $FutureProvider<List<SyncDevice>> {
  /// Устройства в папке синхронизации; перечитываются после каждого удачного
  /// прохода и после каждой ошибки — неудачный проход не меняет время
  /// синхронизации, а папки уже может не быть.
  SyncDevicesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncDevicesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncDevicesHash();

  @$internal
  @override
  $FutureProviderElement<List<SyncDevice>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<SyncDevice>> create(Ref ref) {
    return syncDevices(ref);
  }
}

String _$syncDevicesHash() => r'df0da91dcb6060c56353a164a8634907755c58cc';
