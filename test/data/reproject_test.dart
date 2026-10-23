import 'package:flutter_test/flutter_test.dart';
import 'package:oplog_sync/testing.dart';
import 'package:planner/data/projection/default_registry.dart';
import 'package:planner/data/projection/entity_fields.dart';
import 'package:planner/data/projection/projector.dart';

import 'support/drift_probe.dart';

void main() {
  test('needsReproject — новая база да, после reproject нет', () async {
    final probe = DriftProbe(memoryDatabase());
    expect(await probe.store.needsReproject(), isTrue);
    await probe.store.reproject();
    expect(await probe.store.needsReproject(), isFalse);
  });

  test('поле, которого не знала старая версия, после обновления попадает в '
      'колонку; результат равен rebuild', () async {
    final db = memoryDatabase();

    // «Старое приложение»: реестр без описания задачи, версия 0.
    final oldRegistry = ProjectorRegistry(0, [
      taskProjector(db).without({TaskFields.description}),
      projectProjector(db),
    ]);
    final oldProbe = DriftProbe(db, registry: oldRegistry);
    await oldProbe.store.reproject();
    // Правка «с нового устройства»: описание пришло, но колонку не заполнило.
    final remote = ScenarioNode(DriftProbe(memoryDatabase()), 'b');
    await remote.engine.mutate(EntityTypes.task, 't1', {
      TaskFields.content: 'Отчёт',
      TaskFields.description: 'до пятницы',
    });
    final local = ScenarioNode(oldProbe, 'a');
    await remote.pushTo(local);
    var row = await db.select(db.tasks).getSingle();
    expect(row.content, 'Отчёт');
    expect(row.description, '');

    // «Обновлённое приложение» на той же базе.
    final newProbe = DriftProbe(db);
    expect(await newProbe.store.needsReproject(), isTrue);
    await newProbe.store.reproject();
    expect(await newProbe.store.needsReproject(), isFalse);
    row = await db.select(db.tasks).getSingle();
    expect(row.description, 'до пятницы');

    final afterReproject = await dumpSyncedState(db);
    await ScenarioNode(newProbe, 'a').engine.rebuild();
    expect(await dumpSyncedState(db), afterReproject);
  });

  test('reproject не трогает журнал и неизвестные поля', () async {
    final probe = DriftProbe(memoryDatabase());
    final node = ScenarioNode(probe, 'a');
    await node.engine.mutate(EntityTypes.task, 't1', {
      TaskFields.content: 'x',
      'deadline': '2026-11-01',
    });
    await node.engine.mutate('section', 's1', {'name': 'Покупки'});
    final before = await dumpSyncedState(probe.db);
    await probe.store.reproject();
    expect(await dumpSyncedState(probe.db), before);
    expect(await probe.entity('section', 's1'), {'name': 'Покупки'});
    expect(await node.opCount(), 3);
  });
}
