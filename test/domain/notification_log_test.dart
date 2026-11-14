import 'package:flutter_test/flutter_test.dart';
import 'package:planner/domain/notification_log.dart';

// Журнал «Уведомления» (решения 2А–4А plans/m5 «Решения M5.3a»): записи,
// лимиты, непрочитанные, удаление и очистка, вид для хранения.
void main() {
  test('записи получают растущие id и время, все непрочитаны', () {
    final log = const NotificationLog().add('A', 10).add('B', 20);
    expect(
      [for (final e in log.items) (e.id, e.atMs, e.text)],
      [(1, 10, 'A'), (2, 20, 'B')],
    );
    expect(log.unread, 2);
  });

  test('201-я запись вытесняет самую старую', () {
    var log = const NotificationLog();
    for (var i = 0; i < notificationLogLimit + 1; i++) {
      log = log.add('n$i', i);
    }
    expect(log.items, hasLength(notificationLogLimit));
    expect(log.items.first.text, 'n1');
    expect(log.items.last.text, 'n$notificationLogLimit');
  });

  test('текст длиннее 500 символов обрезается по кодовым точкам — эмодзи '
      'не рвётся', () {
    final log = const NotificationLog().add('😀' * 600, 0);
    expect(log.items.single.text.runes, hasLength(notificationTextLimit));
    expect(log.items.single.text, '😀' * notificationTextLimit);
  });

  test('прочитано — счётчик 0; новая запись — снова 1', () {
    final read = const NotificationLog().add('A', 0).add('B', 0).markRead();
    expect(read.unread, 0);
    expect(read.add('C', 0).unread, 1);
  });

  test('удаление непрочитанной уменьшает счётчик; очистка — пусто, нумерация '
      'продолжается', () {
    final log = const NotificationLog().add('A', 0).add('B', 0);
    final removed = log.remove(1);
    expect([for (final e in removed.items) e.text], ['B']);
    expect(removed.unread, 1);
    final cleared = removed.clear();
    expect(cleared.items, isEmpty);
    expect(cleared.unread, 0);
    expect(cleared.add('C', 0).items.single.id, 3);
  });

  test('вид для хранения читается обратно тем же журналом', () {
    final log = const NotificationLog().add('A', 5).add('Б', 6).markRead();
    expect(NotificationLog.fromJson(log.toJson()), log);
  });

  test('другая версия формата — ошибка разбора', () {
    expect(
      () =>
          NotificationLog.fromJson({'v': 2, 'next': 1, 'seen': 0, 'items': []}),
      throwsFormatException,
    );
  });
}
