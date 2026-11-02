// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'today.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Сегодняшняя дата устройства (полночь) для подписей срока — по стенным
/// часам (`AppClock.nowWall`), как разбор дат и расчёт повторений: иначе
/// «Сегодня» в строке и «today» в разборе могли бы разойтись. Сама
/// обновляется в полночь и при возвращении приложения на экран: приложение
/// на Windows живёт в трее сутками, а таймер на телефоне в глубоком сне
/// стоит — без этого вчерашние задачи оставались бы «Сегодня».

@ProviderFor(today)
final todayProvider = TodayProvider._();

/// Сегодняшняя дата устройства (полночь) для подписей срока — по стенным
/// часам (`AppClock.nowWall`), как разбор дат и расчёт повторений: иначе
/// «Сегодня» в строке и «today» в разборе могли бы разойтись. Сама
/// обновляется в полночь и при возвращении приложения на экран: приложение
/// на Windows живёт в трее сутками, а таймер на телефоне в глубоком сне
/// стоит — без этого вчерашние задачи оставались бы «Сегодня».

final class TodayProvider
    extends $FunctionalProvider<DateTime, DateTime, DateTime>
    with $Provider<DateTime> {
  /// Сегодняшняя дата устройства (полночь) для подписей срока — по стенным
  /// часам (`AppClock.nowWall`), как разбор дат и расчёт повторений: иначе
  /// «Сегодня» в строке и «today» в разборе могли бы разойтись. Сама
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

String _$todayHash() => r'5134c0354686277399af983d8160b952e2caaf29';

/// Время срока сегодня [date] [time] (`HH:MM`) прошло — срок красный, как
/// просроченный (help «Introduction to dates and time»: зелёный — «haven't
/// gone past the due time»). Пересчитывается в момент срока: таймер стоит
/// только у сроков на сегодня со временем впереди.

@ProviderFor(dueTimePassed)
final dueTimePassedProvider = DueTimePassedFamily._();

/// Время срока сегодня [date] [time] (`HH:MM`) прошло — срок красный, как
/// просроченный (help «Introduction to dates and time»: зелёный — «haven't
/// gone past the due time»). Пересчитывается в момент срока: таймер стоит
/// только у сроков на сегодня со временем впереди.

final class DueTimePassedProvider extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Время срока сегодня [date] [time] (`HH:MM`) прошло — срок красный, как
  /// просроченный (help «Introduction to dates and time»: зелёный — «haven't
  /// gone past the due time»). Пересчитывается в момент срока: таймер стоит
  /// только у сроков на сегодня со временем впереди.
  DueTimePassedProvider._({
    required DueTimePassedFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: null,
         name: r'dueTimePassedProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$dueTimePassedHash();

  @override
  String toString() {
    return r'dueTimePassedProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    final argument = this.argument as (String, String);
    return dueTimePassed(ref, argument.$1, argument.$2);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is DueTimePassedProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$dueTimePassedHash() => r'c9a0f757f2534e9ac451a05fe0d3a6c628dd9e04';

/// Время срока сегодня [date] [time] (`HH:MM`) прошло — срок красный, как
/// просроченный (help «Introduction to dates and time»: зелёный — «haven't
/// gone past the due time»). Пересчитывается в момент срока: таймер стоит
/// только у сроков на сегодня со временем впереди.

final class DueTimePassedFamily extends $Family
    with $FunctionalFamilyOverride<bool, (String, String)> {
  DueTimePassedFamily._()
    : super(
        retry: null,
        name: r'dueTimePassedProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Время срока сегодня [date] [time] (`HH:MM`) прошло — срок красный, как
  /// просроченный (help «Introduction to dates and time»: зелёный — «haven't
  /// gone past the due time»). Пересчитывается в момент срока: таймер стоит
  /// только у сроков на сегодня со временем впереди.

  DueTimePassedProvider call(String date, String time) =>
      DueTimePassedProvider._(argument: (date, time), from: this);

  @override
  String toString() => r'dueTimePassedProvider';
}
