/// Системное уведомление о конфликте синхронизации (docs/plans/m2-core-app.md,
/// решение 15). Интерфейс — чтобы оболочка проверялась тестом без настоящих
/// уведомлений ОС.
abstract interface class ConflictNotifier {
  /// Подготовить при запуске: клик по уведомлению, оставшемуся в центре
  /// уведомлений с прошлого запуска, тоже откроет «Конфликты».
  Future<void> start();

  /// Окно приложения на переднем плане: хватит тоста внутри окна.
  Future<bool> isAppActive();

  /// Показать уведомление ОС. Клик по нему показывает окно и даёт событие
  /// [opened].
  Future<void> show({required String title, required String body});

  /// Пользователь открыл уведомление — перейти к «Конфликтам».
  Stream<void> get opened;
}

/// Уведомлений ОС на этой платформе пока нет (Android — О-35): о конфликте
/// говорят тост в окне и пункт сайдбара.
final class InAppConflictNotifier implements ConflictNotifier {
  const InAppConflictNotifier();

  @override
  Future<void> start() async {}

  @override
  Future<bool> isAppActive() async => true;

  @override
  Future<void> show({required String title, required String body}) async {}

  @override
  Stream<void> get opened => const Stream.empty();
}
