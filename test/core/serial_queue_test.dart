import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:planner/core/serial_queue.dart';

void main() {
  test('шаги — по одному, в порядке вызова: следующий не начинается, пока '
      'идёт предыдущий', () async {
    final queue = SerialQueue();
    final log = <String>[];
    final first = Completer<void>();
    final a = queue.run(() async {
      log.add('a начат');
      await first.future;
      log.add('a закончен');
    });
    final b = queue.run(() async => log.add('b'));
    await pumpEventQueue();
    expect(log, ['a начат']);
    first.complete();
    await Future.wait([a, b]);
    expect(log, ['a начат', 'a закончен', 'b']);
  });

  test(
    'сбой шага — ошибка у вызвавшего, следующие шаги идут по порядку',
    () async {
      final queue = SerialQueue();
      final log = <int>[];
      final failed = queue.run<void>(() async => throw StateError('сбой'));
      final second = queue.run(() async {
        log.add(2);
        return 2;
      });
      final third = queue.run(() async {
        log.add(3);
        return 3;
      });
      await expectLater(failed, throwsStateError);
      expect(await second, 2);
      expect(await third, 3);
      expect(log, [2, 3]);
    },
  );

  test('синхронная ошибка шага тоже не останавливает очередь', () async {
    final queue = SerialQueue();
    final failed = queue.run<int>(() => throw ArgumentError('сразу'));
    final next = queue.run(() async => 'дальше');
    await expectLater(failed, throwsArgumentError);
    expect(await next, 'дальше');
  });

  test(
    'ошибка шага, которую никто не ждёт, не всплывает необработанной',
    () async {
      final queue = SerialQueue();
      unawaited(queue.run<void>(() async => throw StateError('никто не ждёт')));
      expect(await queue.run(() async => 1), 1);
    },
  );
}
