// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'today.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Сегодняшняя локальная дата (полночь) для подписей срока. Сама
/// обновляется в полночь и при возвращении приложения на экран: приложение
/// на Windows живёт в трее сутками, а таймер на телефоне в глубоком сне
/// стоит — без этого вчерашние задачи оставались бы «Сегодня».

@ProviderFor(today)
final todayProvider = TodayProvider._();

/// Сегодняшняя локальная дата (полночь) для подписей срока. Сама
/// обновляется в полночь и при возвращении приложения на экран: приложение
/// на Windows живёт в трее сутками, а таймер на телефоне в глубоком сне
/// стоит — без этого вчерашние задачи оставались бы «Сегодня».

final class TodayProvider
    extends $FunctionalProvider<DateTime, DateTime, DateTime>
    with $Provider<DateTime> {
  /// Сегодняшняя локальная дата (полночь) для подписей срока. Сама
  /// обновляется в полночь и при возвращении приложения на экран: приложение
  /// на Windows живёт в трее сутками, а таймер на телефоне в глубоком сне
  /// стоит — без этого вчерашние задачи оставались бы «Сегодня».
  TodayProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'todayProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$todayHash();

  @$internal
  @override
  $ProviderElement<DateTime> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DateTime create(Ref ref) {
    return today(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DateTime value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DateTime>(value),
    );
  }
}

String _$todayHash() => r'6114e8ca2018ec895487a31c1625eb9c2cb3a331';
