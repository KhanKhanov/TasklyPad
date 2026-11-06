// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'drag_session.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Сессия перетаскивания (состояние интерфейса этого устройства, не
/// синхронизируется): `null` — ничего не тащат. Строки читают её через
/// `select`, поэтому каждая перестраивается, только когда её это касается.

@ProviderFor(DragSession)
final dragSessionProvider = DragSessionProvider._();

/// Сессия перетаскивания (состояние интерфейса этого устройства, не
/// синхронизируется): `null` — ничего не тащат. Строки читают её через
/// `select`, поэтому каждая перестраивается, только когда её это касается.
final class DragSessionProvider
    extends $NotifierProvider<DragSession, DragSessionState?> {
  /// Сессия перетаскивания (состояние интерфейса этого устройства, не
  /// синхронизируется): `null` — ничего не тащат. Строки читают её через
  /// `select`, поэтому каждая перестраивается, только когда её это касается.
  DragSessionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dragSessionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dragSessionHash();

  @$internal
  @override
  DragSession create() => DragSession();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DragSessionState? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DragSessionState?>(value),
    );
  }
}

String _$dragSessionHash() => r'e016600d2011945ee3beebba438fb48f015ca0c3';

/// Сессия перетаскивания (состояние интерфейса этого устройства, не
/// синхронизируется): `null` — ничего не тащат. Строки читают её через
/// `select`, поэтому каждая перестраивается, только когда её это касается.

abstract class _$DragSession extends $Notifier<DragSessionState?> {
  DragSessionState? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<DragSessionState?, DragSessionState?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<DragSessionState?, DragSessionState?>,
              DragSessionState?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
