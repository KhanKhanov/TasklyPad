import 'package:flutter_test/flutter_test.dart';
import 'package:planner/domain/theme_settings.dart';
import 'package:planner/sync/io_sync_fs.dart';
import 'package:planner/sync/node_identity.dart';
import 'package:planner/sync/sync_runner.dart';

import '../data/support/drift_probe.dart';
import '../features/support/app_commands.dart';
import 'support/devices.dart';

SyncRunner _runner(TestDevice device, String name) => SyncRunner(
  services: device.services,
  openFs: IoSyncFs.new,
  deviceInfo: {'device': name, 'platform': 'windows'},
);

// Копия базы и смена папки (`adopt`) вместе с сущностями M2: то, что
// переиздаётся от нового узла, должно дать на другом устройстве ту же базу.
void main() {
  test('копия базы и смена папки с сущностями M2 (метки задач, удалённая '
      'метка, общая тема): третье устройство видит то же, конфликтов нет, '
      'после пересборки — то же', () async {
    final oldFolder = tempDir('planner_old_').path;
    final newFolder = tempDir('planner_new_').path;
    const dark = ThemeChoice(
      themeId: 'taskly',
      appearance: ThemeAppearance.dark,
    );
    final original = await TestDevice.start(seed: 1);
    final app = AppCommands(original);
    final project = await app.projects.add(name: 'Ремонт');
    final section = await app.sections.add(project, name: 'Неделя');
    final home = await app.labels.add(name: 'дом');
    final work = await app.labels.add(name: 'работа');
    final paint = await app.tasks.add(
      content: 'покрасить',
      projectId: project,
      sectionId: section,
      labelIds: {home, work},
    );
    final buy = await app.tasks.add(content: 'купить краску', labelIds: {work});
    await app.tasks.complete(buy);
    await app.theme.save(dark, syncTheme: true);
    await _runner(original, 'A').setFolder(oldFolder);

    // Не выгружено до копирования: копия переиздаёт это от своего узла.
    await app.labels.delete(work);
    await app.tasks.rename(paint, 'покрасить стены');

    final copy = await TestDevice.start(
      db: original.db,
      marker: MemoryNodeMarker('другой-компьютер'),
      seed: 5,
    );

    Future<void> expectSame(TestDevice dev) async {
      final onDev = AppCommands(dev);
      final ws = await onDev.read();
      expect(ws.task(paint)!.content, 'покрасить стены');
      expect(ws.task(paint)!.sectionId, section);
      expect(ws.task(paint)!.labelIds, [home]);
      expect(ws.task(buy)!.labelIds, [work], reason: 'выполнена до удаления');
      expect(ws.label(work), isNull);
      expect((await onDev.themeRepo.load()).effective, dark);
      expect(await dumpEntityTables(dev.db), await dumpEntityTables(copy.db));
      expect(await dev.services.store.conflicts(), isEmpty);
    }

    // Та же папка: невыгруженное доходит, потому что копия переиздала его.
    final copyRunner = _runner(copy, 'A2');
    await copyRunner.syncNow();
    final b = await TestDevice.start(seed: 2);
    await _runner(b, 'B').setFolder(oldFolder);
    await expectSame(b);

    // Новая папка: выгруженное прежним id переиздаётся, если его отметить.
    final change = await copyRunner.setFolder(
      newFolder,
      retired: {original.nodeId},
    );
    expect(change.adopted, {original.nodeId});
    final c = await TestDevice.start(seed: 3);
    await _runner(c, 'C').setFolder(newFolder);
    await expectSame(c);
    expect(await copy.services.store.conflicts(), isEmpty);

    final before = await dumpSyncedState(c.db);
    await _runner(c, 'C').rebuild();
    expect(await dumpSyncedState(c.db), before);
    await expectSame(c);
  });
}
