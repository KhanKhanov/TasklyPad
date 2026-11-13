import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/core/fractional_index.dart';
import 'package:planner/data/projection/entity_fields.dart';

import '../../sync/support/devices.dart';
import '../support/app_commands.dart';

// Замер массовых «Выполнить», «Вернуть», «Дублировать» (М4.13, находка ревью):
// 300 выделенных задач при 3000 выполненных в базе, drift в памяти. Время
// выводится в лог; проверяется результат, а не время — оно зависит от машины.
void main() {
  late TestDevice device;
  late AppCommands app;
  late List<String> selected;

  setUp(() async {
    device = await TestDevice.start();
    app = AppCommands(device);
    final mutator = device.services.mutator;
    // Три проекта по 100 выделенных: дубликат не упрётся в лимит 300.
    final projects = [
      for (var p = 0; p < 3; p++) await app.projects.add(name: 'Проект $p'),
    ];
    final keys = sequence(1100);
    selected = await mutator.batch(() async {
      final ids = <String>[];
      for (final (p, project) in projects.indexed) {
        for (var i = 0; i < 1100; i++) {
          final done = i >= 100;
          final id = await mutator.create(EntityTypes.task, {
            TaskFields.content: 'Задача $p-$i',
            TaskFields.projectId: project,
            TaskFields.orderKey: keys[i],
            TaskFields.priority: 4,
            if (done) TaskFields.isCompleted: true,
            if (done) TaskFields.completedAt: testStart.toIso8601String(),
          });
          if (!done) ids.add(id);
        }
      }
      return ids;
    });
  });

  Future<Duration> timed(Future<void> Function() action) async {
    final watch = Stopwatch()..start();
    await action();
    return watch.elapsed;
  }

  test('замер: 300 выделенных при 3000 выполненных — «Выполнить», «Вернуть», '
      '«Дублировать»', () async {
    expect(selected, hasLength(300));
    final read = await timed(app.read);

    final complete = await timed(() async {
      await app.bulk.complete(selected);
    });
    var ws = await app.read();
    expect(selected.every((id) => ws.task(id)!.isCompleted), isTrue);

    final uncomplete = await timed(() async {
      await app.bulk.uncomplete(selected);
    });
    ws = await app.read();
    expect(selected.every((id) => !ws.task(id)!.isCompleted), isTrue);

    final duplicate = await timed(() => app.bulk.duplicate(selected));
    ws = await app.read();
    for (final p in ws.childProjects(null)) {
      if (p.isInbox) continue;
      expect(ws.activeTaskCount(p.id), 200);
    }

    debugPrint(
      'Замер M4.13: снимок ${read.inMilliseconds} мс; «Выполнить» '
      '${complete.inMilliseconds} мс; «Вернуть» '
      '${uncomplete.inMilliseconds} мс; «Дублировать» '
      '${duplicate.inMilliseconds} мс',
    );
  }, timeout: const Timeout(Duration(minutes: 5)));
}
