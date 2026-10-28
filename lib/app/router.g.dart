// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'router.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Маршруты приложения. Deep links из уведомлений и виджетов ведут сюда же.
/// Все экраны — внутри [AppShell] (`ShellRoute`): сайдбар не пересоздаётся
/// при переходах.

@ProviderFor(router)
final routerProvider = RouterProvider._();

/// Маршруты приложения. Deep links из уведомлений и виджетов ведут сюда же.
/// Все экраны — внутри [AppShell] (`ShellRoute`): сайдбар не пересоздаётся
/// при переходах.

final class RouterProvider
    extends $FunctionalProvider<GoRouter, GoRouter, GoRouter>
    with $Provider<GoRouter> {
  /// Маршруты приложения. Deep links из уведомлений и виджетов ведут сюда же.
  /// Все экраны — внутри [AppShell] (`ShellRoute`): сайдбар не пересоздаётся
  /// при переходах.
  RouterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'routerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$routerHash();

  @$internal
  @override
  $ProviderElement<GoRouter> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GoRouter create(Ref ref) {
    return router(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GoRouter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GoRouter>(value),
    );
  }
}

String _$routerHash() => r'2e25668490430c90e3573675c8d85ce1d8494aa4';
