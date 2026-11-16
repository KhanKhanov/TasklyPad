import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:planner/data/local_meta_dao.dart';
import 'package:planner/data/repositories/recently_viewed_repository.dart';
import 'package:planner/domain/recently_viewed.dart';
import 'package:planner/sync/io_sync_fs.dart';

import '../features/support/app_commands.dart';
import 'support/devices.dart';

// «Недавно просмотренное» — память устройства, не данные (решение 1А plans/m5
// «Решения M5.4», SYNC_DESIGN «Специальные случаи»): на другое устройство не
// попадает, в файлах папки его нет, пересборка базы из журнала операций его не
// трогает. Сценарии «Инвариантов реализации» про слияние полей неприменимы:
// список не пишется в op-log.
void main() {
  test('список A не попадает ни на B, ни в папку; пересборка его не '
      'трогает', () async {
    final folder = tempDir('recently_viewed_').path;
    final a = await TestDevice.start(seed: 1);
    final b = await TestDevice.start(seed: 2);
    final onA = AppCommands(a);
    final repoA = RecentlyViewedRepository(a.db);
    final list = const RecentlyViewed().visit(
      const ViewedItem(ViewedKind.project, 'секретный-проект'),
    );
    await repoA.save(list);
    // Обычная правка, чтобы синхронизации было что везти.
    await onA.tasks.add(content: 'Milk');

    for (var round = 0; round < 2; round++) {
      for (final dev in [a, b]) {
        final report = await dev.folder(IoSyncFs(folder)).syncOnce();
        expect(report?.issues, isEmpty);
      }
    }

    expect((await b.aliveTasks()).values, contains('Milk'));
    expect((await RecentlyViewedRepository(b.db).load()).items, isEmpty);
    final texts = [
      for (final file in Directory(folder).listSync(recursive: true))
        if (file is File)
          utf8.decode(file.readAsBytesSync(), allowMalformed: true),
    ];
    // Контроль: файлы папки читаются как текст — задача в них видна.
    expect(texts.any((t) => t.contains('Milk')), isTrue);
    expect(texts.where((t) => t.contains('секретный')), isEmpty);

    await a.services.engine.rebuild();
    expect((await repoA.load()).items, list.items);
  });

  for (final (name, value) in const [
    ('не JSON', '{oops'),
    ('другая версия', '{"v":2,"items":[]}'),
    ('задача без id', '{"v":1,"items":[{"k":"task"}]}'),
  ]) {
    test('битое значение ($name) — пустой список без ошибки', () async {
      final dev = await TestDevice.start();
      await LocalMetaDao(dev.db).write(LocalMetaDao.recentlyViewedKey, value);
      expect((await RecentlyViewedRepository(dev.db).load()).items, isEmpty);
    });
  }
}
