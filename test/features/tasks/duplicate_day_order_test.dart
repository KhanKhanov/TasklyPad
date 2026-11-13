import 'package:flutter_test/flutter_test.dart';
import 'package:planner/data/projection/entity_fields.dart';
import 'package:planner/domain/models.dart';
import 'package:planner/domain/view_options.dart';
import 'package:planner/domain/view_order.dart';

import '../../sync/support/devices.dart';
import '../support/app_commands.dart';

// Дубликат в «Сегодня» и «Предстоящем» встаёт сразу под оригиналом: копия
// получает ключ порядка дня между ключом оригинала и следующим (находка
// ревью M4.13).
void main() {
  late TestDevice device;
  late AppCommands app;
  const day = '2026-10-23';

  setUp(() async {
    device = await TestDevice.start();
    app = AppCommands(device);
  });

  /// Задачи дня в порядке «Вручную» вида «Сегодня».
  Future<List<String>> dayOrder() async {
    final ws = await app.read();
    return [
      for (final t in ws.todayTasks(
        day,
        order: ws.taskOrder(DefaultOrder.smart, sorting: Sorting.manual),
      ))
        t.content,
    ];
  }

  /// Три задачи дня с ручным порядком дня А, Б, В.
  Future<List<String>> threeInDay() async {
    final ids = [
      for (final name in ['А', 'Б', 'В'])
        await app.tasks.add(
          content: name,
          due: const Due(date: day),
        ),
    ];
    // Ключи дня — как после перетаскивания (reorderInDay).
    for (final (id, key) in [(ids[0], 'F'), (ids[1], 'M'), (ids[2], 'T')]) {
      await device.services.mutator.update(EntityTypes.task, id, {
        TaskFields.dayOrderKey: key,
      });
    }
    expect(await dayOrder(), ['А', 'Б', 'В']);
    return ids;
  }

  test('дубликат задачи с ключом дня — сразу под оригиналом в дне', () async {
    final ids = await threeInDay();
    final copy = await app.tasks.duplicate(ids[0]);
    expect(await dayOrder(), ['А', 'А', 'Б', 'В']);
    final ws = await app.read();
    expect(
      ws.task(copy)!.dayOrderKey.compareTo(ws.task(ids[0])!.dayOrderKey),
      greaterThan(0),
    );
    expect(
      ws.task(copy)!.dayOrderKey.compareTo(ws.task(ids[1])!.dayOrderKey),
      lessThan(0),
    );
  });

  test('массовый дубликат — каждая копия под своим оригиналом', () async {
    final ids = await threeInDay();
    await app.bulk.duplicate([ids[0], ids[2]]);
    expect(await dayOrder(), ['А', 'А', 'Б', 'В', 'В']);
    await app.bulk.duplicate([ids[0], ids[1]]);
    expect(await dayOrder(), ['А', 'А', 'А', 'Б', 'Б', 'В', 'В']);
  });

  test('оригинал без ключа дня — копия без ключа', () async {
    final id = await app.tasks.add(
      content: 'А',
      due: const Due(date: day),
    );
    final copy = await app.tasks.duplicate(id);
    expect(
      (await device.entity(EntityTypes.task, copy))!,
      isNot(contains(TaskFields.dayOrderKey)),
    );
  });
}
