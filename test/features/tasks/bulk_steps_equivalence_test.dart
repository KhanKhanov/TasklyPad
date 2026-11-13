import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/data/projection/entity_fields.dart';
import 'package:planner/domain/models.dart';
import 'package:planner/sync/mutator.dart';

import '../../data/support/drift_probe.dart';
import '../../sync/support/devices.dart';
import '../support/app_commands.dart';

// Массовые «Выполнить», «Вернуть», «Дублировать» читают снимок один раз и
// перечитывают его только при надобности (замер M4.13). Результат и
// «Отменить» — те же, что у одиночных команд подряд со свежим снимком на
// каждом шаге: два устройства с одинаковыми данными, одно — массовым
// действием, другое — по одной.
void main() {
  late TestDevice bulkDevice;
  late TestDevice singleDevice;
  late AppCommands bulk;
  late AppCommands single;

  /// Два устройства с одинаковыми id: те же случайные числа и время id.
  Future<void> startBoth() async {
    bulkDevice = await TestDevice.start(seed: 7);
    singleDevice = await TestDevice.start(seed: 7);
    bulk = AppCommands(bulkDevice);
    single = AppCommands(singleDevice);
  }

  const daily = Due(
    date: '2026-10-23',
    string: 'каждый день',
    lang: 'ru',
    rule: RecurrenceRule(rrule: ['FREQ=DAILY'], fromCompletion: false),
  );
  const today = Due(date: '2026-10-23');

  /// Одинаковые данные — с тем, что шаги массового действия меняют друг для
  /// друга: у сброшенных подзадач двух повторяющихся — две удалённые метки с
  /// одним именем (вторая должна получить метку, созданную первой), родитель
  /// с подзадачей, равные ключи порядка (a, d, g — после параллельных
  /// вставок; h, i) и дня (d, e), архивный раздел с двумя задачами.
  Future<Map<String, String>> seed(TestDevice device, AppCommands app) async {
    final m = device.services.mutator;
    await m.update(EntityTypes.settings, settingsEntityId, {
      SettingsFields.resetRecurringSubtasks: true,
    });
    final p = await app.projects.add(name: 'P');
    final z = await app.sections.add(p, name: 'Z');
    final ids = <String, String>{'p': p, 'z': z};
    for (final (r, name) in [('r1', 'дом'), ('r2', 'Дом')]) {
      final label = await app.labels.add(name: name);
      ids[r] = await app.tasks.add(content: r, projectId: p, due: daily);
      final s = await app.tasks.add(
        content: 's$r',
        parentId: ids[r],
        labelIds: {label},
      );
      await app.tasks.complete(s);
      await app.labels.delete(label);
    }
    for (final name in ['a', 'b']) {
      ids[name] = await app.tasks.add(content: name, projectId: p);
    }
    ids['c'] = await app.tasks.add(content: 'c', parentId: ids['b']);
    for (final name in ['d', 'e', 'f']) {
      ids[name] = await app.tasks.add(content: name, projectId: p, due: today);
    }
    for (final name in ['g', 'h', 'i']) {
      ids[name] = await app.tasks.add(content: name, projectId: p);
    }
    for (final (names, key) in [
      (['a', 'd', 'g'], 'K'),
      (['h', 'i'], 'Q'),
    ]) {
      for (final name in names) {
        await m.update(EntityTypes.task, ids[name]!, {
          TaskFields.orderKey: key,
        });
      }
    }
    for (final (name, key) in [('d', 'F'), ('e', 'F'), ('f', 'M')]) {
      await m.update(EntityTypes.task, ids[name]!, {
        TaskFields.dayOrderKey: key,
      });
    }
    // Две выполненные задачи с удалёнными метками одного имени: «Вернуть»
    // второй должно взять метку, созданную заново для первой.
    for (final (u, name) in [('u1', 'сад'), ('u2', 'Сад')]) {
      final label = await app.labels.add(name: name);
      ids[u] = await app.tasks.add(content: u, projectId: p, labelIds: {label});
      await app.tasks.complete(ids[u]!);
      await app.labels.delete(label);
    }
    for (final name in ['z1', 'z2']) {
      ids[name] = await app.tasks.add(
        content: name,
        projectId: p,
        sectionId: z,
      );
    }
    await app.sections.archive(z);
    // Два архивных раздела с равным ключом порядка (параллельные вставки):
    // «Вернуть» их задач возвращает оба, второй получает новый ключ.
    for (final name in ['y1', 'y2']) {
      final section = await app.sections.add(p, name: 'Раздел $name');
      ids[name] = await app.tasks.add(
        content: name,
        projectId: p,
        sectionId: section,
      );
      await m.update(EntityTypes.section, section, {
        SectionFields.orderKey: 'S',
      });
      await app.sections.archive(section);
    }
    return ids;
  }

  Future<Map<String, Object?>> tables(TestDevice device) async {
    final dump = await dumpSyncedState(device.db);
    return {
      for (final MapEntry(:key, :value) in dump.entries)
        if (!{'ops', 'field_versions', 'conflicts'}.contains(key)) key: value,
    };
  }

  Future<void> expectSame() async {
    expect(await tables(bulkDevice), await tables(singleDevice));
  }

  test(
    '«Выполнить», «Вернуть», «Дублировать» и их «Отменить» — как по '
    'одной',
    () => withClock(Clock.fixed(testStart), () async {
      await startBoth();
      final ids = await seed(bulkDevice, bulk);
      expect(await seed(singleDevice, single), ids);
      await expectSame();

      Future<Undo> singles(
        List<String> order,
        Future<Undo> Function(String id) step,
      ) => singleDevice.services.mutator.batch(
        () async => singleDevice.services.mutator.combine([
          for (final id in order) await step(id),
        ]),
      );

      // «Выполнить»: родители раньше подзадач; подзадача, выполненная с
      // родителем, — пустой шаг (у одиночных — тоже).
      final toComplete = [
        for (final n in ['r1', 'r2', 'a', 'd', 'b', 'c']) ids[n]!,
      ];
      final undoBulkComplete = await bulk.bulk.complete(toComplete);
      final undoSingleComplete = await singles(
        toComplete,
        (id) => single.tasks.complete(id),
      );
      await expectSame();
      await undoBulkComplete();
      await undoSingleComplete();
      await expectSame();
      await bulk.bulk.complete(toComplete);
      await singles(toComplete, (id) => single.tasks.complete(id));
      await expectSame();

      // «Вернуть»: подзадача возвращает родителя, два возврата одного
      // архивного раздела, равные ключи соседей.
      final toReturn = [
        for (final n in [
          'c',
          'b',
          'a',
          'd',
          'z1',
          'z2',
          'u1',
          'u2',
          'y1',
          'y2',
        ])
          ids[n]!,
      ];
      final undoBulkReturn = await bulk.bulk.uncomplete(toReturn);
      final undoSingleReturn = await singles(
        toReturn,
        (id) => single.tasks.uncomplete(id),
      );
      await expectSame();
      await undoBulkReturn();
      await undoSingleReturn();
      await expectSame();
      await bulk.bulk.uncomplete(toReturn);
      await singles(toReturn, (id) => single.tasks.uncomplete(id));
      await expectSame();

      // «Дублировать»: равные ключи дня и порядка, соседи одного места.
      final toCopy = [
        for (final n in ['d', 'e', 'f', 'a', 'g', 'b', 'h', 'i']) ids[n]!,
      ];
      await bulk.bulk.duplicate(toCopy);
      await singleDevice.services.mutator.batch(() async {
        for (final id in toCopy) {
          await single.tasks.duplicate(id);
        }
      });
      await expectSame();
    }),
  );
}
