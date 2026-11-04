// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'upcoming_day.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Выбранный день «Предстоящего» `YYYY-MM-DD` — дата по умолчанию новой
/// задачи (help «Plan your week with the Upcoming view»: «click Add task to
/// create a task for that selected day»). Не синхронизируется: это место
/// просмотра, а не данные. Пока экран открыт — живёт; при уходе с экрана и
/// в полночь — снова сегодня.

@ProviderFor(UpcomingDay)
final upcomingDayProvider = UpcomingDayProvider._();

/// Выбранный день «Предстоящего» `YYYY-MM-DD` — дата по умолчанию новой
/// задачи (help «Plan your week with the Upcoming view»: «click Add task to
/// create a task for that selected day»). Не синхронизируется: это место
/// просмотра, а не данные. Пока экран открыт — живёт; при уходе с экрана и
/// в полночь — снова сегодня.
final class UpcomingDayProvider extends $NotifierProvider<UpcomingDay, String> {
  /// Выбранный день «Предстоящего» `YYYY-MM-DD` — дата по умолчанию новой
  /// задачи (help «Plan your week with the Upcoming view»: «click Add task to
  /// create a task for that selected day»). Не синхронизируется: это место
  /// просмотра, а не данные. Пока экран открыт — живёт; при уходе с экрана и
  /// в полночь — снова сегодня.
  UpcomingDayProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'upcomingDayProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$upcomingDayHash();

  @$internal
  @override
  UpcomingDay create() => UpcomingDay();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$upcomingDayHash() => r'515290efe59539efe2ac98412909e669568944d6';

/// Выбранный день «Предстоящего» `YYYY-MM-DD` — дата по умолчанию новой
/// задачи (help «Plan your week with the Upcoming view»: «click Add task to
/// create a task for that selected day»). Не синхронизируется: это место
/// просмотра, а не данные. Пока экран открыт — живёт; при уходе с экрана и
/// в полночь — снова сегодня.

abstract class _$UpcomingDay extends $Notifier<String> {
  String build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<String, String>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String, String>,
              String,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
