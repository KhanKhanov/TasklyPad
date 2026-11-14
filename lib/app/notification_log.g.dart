// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_log.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Журнал «Уведомления» этого устройства (решения 2А–4А plans/m5 «Решения
/// M5.3a»): загружается при запуске, каждое нижнее уведомление дописывается
/// ([record]). Изменения идут по очереди: две записи подряд не теряют друг
/// друга. Состояние в памяти меняется сразу, сохранение — следом; ошибка
/// сохранения пишется в лог, а не тостом — тост снова попал бы в журнал.
/// Подписки на базу нет: журнал пишет только этот процесс (один экземпляр
/// приложения), а `local_meta` меняется на каждую правку (часы движка).

@ProviderFor(NotificationLogController)
final notificationLogControllerProvider = NotificationLogControllerProvider._();

/// Журнал «Уведомления» этого устройства (решения 2А–4А plans/m5 «Решения
/// M5.3a»): загружается при запуске, каждое нижнее уведомление дописывается
/// ([record]). Изменения идут по очереди: две записи подряд не теряют друг
/// друга. Состояние в памяти меняется сразу, сохранение — следом; ошибка
/// сохранения пишется в лог, а не тостом — тост снова попал бы в журнал.
/// Подписки на базу нет: журнал пишет только этот процесс (один экземпляр
/// приложения), а `local_meta` меняется на каждую правку (часы движка).
final class NotificationLogControllerProvider
    extends $AsyncNotifierProvider<NotificationLogController, NotificationLog> {
  /// Журнал «Уведомления» этого устройства (решения 2А–4А plans/m5 «Решения
  /// M5.3a»): загружается при запуске, каждое нижнее уведомление дописывается
  /// ([record]). Изменения идут по очереди: две записи подряд не теряют друг
  /// друга. Состояние в памяти меняется сразу, сохранение — следом; ошибка
  /// сохранения пишется в лог, а не тостом — тост снова попал бы в журнал.
  /// Подписки на базу нет: журнал пишет только этот процесс (один экземпляр
  /// приложения), а `local_meta` меняется на каждую правку (часы движка).
  NotificationLogControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notificationLogControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notificationLogControllerHash();

  @$internal
  @override
  NotificationLogController create() => NotificationLogController();
}

String _$notificationLogControllerHash() =>
    r'0eebe47add574ae7036b660603c8f80341ee1385';

/// Журнал «Уведомления» этого устройства (решения 2А–4А plans/m5 «Решения
/// M5.3a»): загружается при запуске, каждое нижнее уведомление дописывается
/// ([record]). Изменения идут по очереди: две записи подряд не теряют друг
/// друга. Состояние в памяти меняется сразу, сохранение — следом; ошибка
/// сохранения пишется в лог, а не тостом — тост снова попал бы в журнал.
/// Подписки на базу нет: журнал пишет только этот процесс (один экземпляр
/// приложения), а `local_meta` меняется на каждую правку (часы движка).

abstract class _$NotificationLogController
    extends $AsyncNotifier<NotificationLog> {
  FutureOr<NotificationLog> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<NotificationLog>, NotificationLog>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<NotificationLog>, NotificationLog>,
              AsyncValue<NotificationLog>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
