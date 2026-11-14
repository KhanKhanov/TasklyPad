import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:planner/app/notification_log.dart';
import 'package:planner/domain/notification_log.dart';

/// Журнал «Уведомления» без базы — для виджет-тестов вне приложения: тост
/// пишет в журнал, а ядра данных в таком тесте нет. Запоминает тексты.
class FakeNotificationLog extends NotificationLogController {
  final List<String> texts = [];

  @override
  Future<NotificationLog> build() async => const NotificationLog();

  @override
  Future<void> record(String text) async => texts.add(text);
}

/// Подмена журнала на [log] (по умолчанию — новый [FakeNotificationLog]).
Override fakeNotificationLog([FakeNotificationLog? log]) =>
    notificationLogControllerProvider.overrideWith(
      () => log ?? FakeNotificationLog(),
    );
