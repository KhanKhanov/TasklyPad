// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'nav_history.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// История переходов приложения: следит за адресом роутера.

@ProviderFor(navHistory)
final navHistoryProvider = NavHistoryProvider._();

/// История переходов приложения: следит за адресом роутера.

final class NavHistoryProvider
    extends $FunctionalProvider<NavHistory, NavHistory, NavHistory>
    with $Provider<NavHistory> {
  /// История переходов приложения: следит за адресом роутера.
  NavHistoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'navHistoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$navHistoryHash();

  @$internal
  @override
  $ProviderElement<NavHistory> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  NavHistory create(Ref ref) {
    return navHistory(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NavHistory value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NavHistory>(value),
    );
  }
}

String _$navHistoryHash() => r'59428a63992c20317a444c4ff7e22beffe15050a';
