// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sidebar_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Боковая панель открыта (на широком окне). Локальное состояние окна, не
/// данные пользователя: в журнал не пишется.

@ProviderFor(SidebarOpen)
final sidebarOpenProvider = SidebarOpenProvider._();

/// Боковая панель открыта (на широком окне). Локальное состояние окна, не
/// данные пользователя: в журнал не пишется.
final class SidebarOpenProvider extends $NotifierProvider<SidebarOpen, bool> {
  /// Боковая панель открыта (на широком окне). Локальное состояние окна, не
  /// данные пользователя: в журнал не пишется.
  SidebarOpenProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sidebarOpenProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sidebarOpenHash();

  @$internal
  @override
  SidebarOpen create() => SidebarOpen();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$sidebarOpenHash() => r'bd8ec9db393c1192110dd23a36303e5d0251be82';

/// Боковая панель открыта (на широком окне). Локальное состояние окна, не
/// данные пользователя: в журнал не пишется.

abstract class _$SidebarOpen extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
