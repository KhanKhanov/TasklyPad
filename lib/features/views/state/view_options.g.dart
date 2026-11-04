// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'view_options.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// «Отображение» всех видов — своё и пришедшее синхронизацией (О-22): одна
/// подписка на таблицу, живёт всё время работы приложения, поэтому при
/// повторном входе в вид его настройки уже готовы.

@ProviderFor(allViewOptions)
final allViewOptionsProvider = AllViewOptionsProvider._();

/// «Отображение» всех видов — своё и пришедшее синхронизацией (О-22): одна
/// подписка на таблицу, живёт всё время работы приложения, поэтому при
/// повторном входе в вид его настройки уже готовы.

final class AllViewOptionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<(ViewType, String?), ViewOptions>>,
          Map<(ViewType, String?), ViewOptions>,
          Stream<Map<(ViewType, String?), ViewOptions>>
        >
    with
        $FutureModifier<Map<(ViewType, String?), ViewOptions>>,
        $StreamProvider<Map<(ViewType, String?), ViewOptions>> {
  /// «Отображение» всех видов — своё и пришедшее синхронизацией (О-22): одна
  /// подписка на таблицу, живёт всё время работы приложения, поэтому при
  /// повторном входе в вид его настройки уже готовы.
  AllViewOptionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'allViewOptionsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$allViewOptionsHash();

  @$internal
  @override
  $StreamProviderElement<Map<(ViewType, String?), ViewOptions>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<Map<(ViewType, String?), ViewOptions>> create(Ref ref) {
    return allViewOptions(ref);
  }
}

String _$allViewOptionsHash() => r'26c54f6486c4c9c854549ba627bf393d0565062d';

/// «Отображение» вида [viewType] объекта [objectId]; пока база не ответила
/// или вид не меняли — настройки по умолчанию. Ошибка чтения базы
/// пробрасывается: правка от умолчаний вместо настоящих настроек записала
/// бы не то, что видел пользователь.

@ProviderFor(viewOptions)
final viewOptionsProvider = ViewOptionsFamily._();

/// «Отображение» вида [viewType] объекта [objectId]; пока база не ответила
/// или вид не меняли — настройки по умолчанию. Ошибка чтения базы
/// пробрасывается: правка от умолчаний вместо настоящих настроек записала
/// бы не то, что видел пользователь.

final class ViewOptionsProvider
    extends $FunctionalProvider<ViewOptions, ViewOptions, ViewOptions>
    with $Provider<ViewOptions> {
  /// «Отображение» вида [viewType] объекта [objectId]; пока база не ответила
  /// или вид не меняли — настройки по умолчанию. Ошибка чтения базы
  /// пробрасывается: правка от умолчаний вместо настоящих настроек записала
  /// бы не то, что видел пользователь.
  ViewOptionsProvider._({
    required ViewOptionsFamily super.from,
    required (ViewType, String?) super.argument,
  }) : super(
         retry: null,
         name: r'viewOptionsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$viewOptionsHash();

  @override
  String toString() {
    return r'viewOptionsProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $ProviderElement<ViewOptions> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ViewOptions create(Ref ref) {
    final argument = this.argument as (ViewType, String?);
    return viewOptions(ref, argument.$1, argument.$2);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ViewOptions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ViewOptions>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ViewOptionsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$viewOptionsHash() => r'2cf9da5413212b74bc58ecce1847c44a839fdb95';

/// «Отображение» вида [viewType] объекта [objectId]; пока база не ответила
/// или вид не меняли — настройки по умолчанию. Ошибка чтения базы
/// пробрасывается: правка от умолчаний вместо настоящих настроек записала
/// бы не то, что видел пользователь.

final class ViewOptionsFamily extends $Family
    with $FunctionalFamilyOverride<ViewOptions, (ViewType, String?)> {
  ViewOptionsFamily._()
    : super(
        retry: null,
        name: r'viewOptionsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// «Отображение» вида [viewType] объекта [objectId]; пока база не ответила
  /// или вид не меняли — настройки по умолчанию. Ошибка чтения базы
  /// пробрасывается: правка от умолчаний вместо настоящих настроек записала
  /// бы не то, что видел пользователь.

  ViewOptionsProvider call(ViewType viewType, String? objectId) =>
      ViewOptionsProvider._(argument: (viewType, objectId), from: this);

  @override
  String toString() => r'viewOptionsProvider';
}
