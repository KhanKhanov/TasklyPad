// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'toast_lamp.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// «Лампа», из которой выходят и в которую втекают нижние уведомления
/// (решения 1А–5А plans/m5 «Решения M5.3a»): на компьютере — вкладка
/// «Уведомления» внизу справа, на телефоне — правый нижний угол окна.
/// Провайдер, а не наследуемый виджет оболочки: тосты окна задачи и карточек
/// конфликтов живут в маршрутах диалогов, вне оболочки. Регистрирует её
/// `ToastLampAnchor`; положение берётся в момент запроса
/// ([toastLampGlobal]) и не устаревает при смене размера окна.

@ProviderFor(ToastLamp)
final toastLampProvider = ToastLampProvider._();

/// «Лампа», из которой выходят и в которую втекают нижние уведомления
/// (решения 1А–5А plans/m5 «Решения M5.3a»): на компьютере — вкладка
/// «Уведомления» внизу справа, на телефоне — правый нижний угол окна.
/// Провайдер, а не наследуемый виджет оболочки: тосты окна задачи и карточек
/// конфликтов живут в маршрутах диалогов, вне оболочки. Регистрирует её
/// `ToastLampAnchor`; положение берётся в момент запроса
/// ([toastLampGlobal]) и не устаревает при смене размера окна.
final class ToastLampProvider
    extends $NotifierProvider<ToastLamp, ToastLampSpot?> {
  /// «Лампа», из которой выходят и в которую втекают нижние уведомления
  /// (решения 1А–5А plans/m5 «Решения M5.3a»): на компьютере — вкладка
  /// «Уведомления» внизу справа, на телефоне — правый нижний угол окна.
  /// Провайдер, а не наследуемый виджет оболочки: тосты окна задачи и карточек
  /// конфликтов живут в маршрутах диалогов, вне оболочки. Регистрирует её
  /// `ToastLampAnchor`; положение берётся в момент запроса
  /// ([toastLampGlobal]) и не устаревает при смене размера окна.
  ToastLampProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'toastLampProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$toastLampHash();

  @$internal
  @override
  ToastLamp create() => ToastLamp();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ToastLampSpot? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ToastLampSpot?>(value),
    );
  }
}

String _$toastLampHash() => r'0241406f496e94c5ee2892a4e9570fe9c460b500';

/// «Лампа», из которой выходят и в которую втекают нижние уведомления
/// (решения 1А–5А plans/m5 «Решения M5.3a»): на компьютере — вкладка
/// «Уведомления» внизу справа, на телефоне — правый нижний угол окна.
/// Провайдер, а не наследуемый виджет оболочки: тосты окна задачи и карточек
/// конфликтов живут в маршрутах диалогов, вне оболочки. Регистрирует её
/// `ToastLampAnchor`; положение берётся в момент запроса
/// ([toastLampGlobal]) и не устаревает при смене размера окна.

abstract class _$ToastLamp extends $Notifier<ToastLampSpot?> {
  ToastLampSpot? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ToastLampSpot?, ToastLampSpot?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ToastLampSpot?, ToastLampSpot?>,
              ToastLampSpot?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
