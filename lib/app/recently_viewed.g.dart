// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recently_viewed.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// «Недавно просмотренное» окна поиска (решение 1А plans/m5 «Решения M5.4»):
/// экраны — по адресу роутера (один источник для сайдбара, клавиш, поиска и
/// истории), задачи — [recordTask] из окна задачи. Память устройства в
/// `local_meta`; изменения по очереди, ошибка сохранения — в лог (как журнал
/// «Уведомления»), без перемен ничего не пишется.

@ProviderFor(RecentlyViewedController)
final recentlyViewedControllerProvider = RecentlyViewedControllerProvider._();

/// «Недавно просмотренное» окна поиска (решение 1А plans/m5 «Решения M5.4»):
/// экраны — по адресу роутера (один источник для сайдбара, клавиш, поиска и
/// истории), задачи — [recordTask] из окна задачи. Память устройства в
/// `local_meta`; изменения по очереди, ошибка сохранения — в лог (как журнал
/// «Уведомления»), без перемен ничего не пишется.
final class RecentlyViewedControllerProvider
    extends $AsyncNotifierProvider<RecentlyViewedController, RecentlyViewed> {
  /// «Недавно просмотренное» окна поиска (решение 1А plans/m5 «Решения M5.4»):
  /// экраны — по адресу роутера (один источник для сайдбара, клавиш, поиска и
  /// истории), задачи — [recordTask] из окна задачи. Память устройства в
  /// `local_meta`; изменения по очереди, ошибка сохранения — в лог (как журнал
  /// «Уведомления»), без перемен ничего не пишется.
  RecentlyViewedControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'recentlyViewedControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$recentlyViewedControllerHash();

  @$internal
  @override
  RecentlyViewedController create() => RecentlyViewedController();
}

String _$recentlyViewedControllerHash() =>
    r'1dff35344727739eb715f1a488e9f489a9e1fcc3';

/// «Недавно просмотренное» окна поиска (решение 1А plans/m5 «Решения M5.4»):
/// экраны — по адресу роутера (один источник для сайдбара, клавиш, поиска и
/// истории), задачи — [recordTask] из окна задачи. Память устройства в
/// `local_meta`; изменения по очереди, ошибка сохранения — в лог (как журнал
/// «Уведомления»), без перемен ничего не пишется.

abstract class _$RecentlyViewedController
    extends $AsyncNotifier<RecentlyViewed> {
  FutureOr<RecentlyViewed> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<RecentlyViewed>, RecentlyViewed>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<RecentlyViewed>, RecentlyViewed>,
              AsyncValue<RecentlyViewed>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
