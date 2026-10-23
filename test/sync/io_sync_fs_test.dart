import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:oplog_sync/testing.dart';
import 'package:path/path.dart' as p;
import 'package:planner/sync/io_sync_fs.dart';

import 'support/devices.dart';

void main() {
  // Тот же контракт, что пакет проверяет на MemorySyncFs, — на настоящем диске.
  group('SyncFs на IoSyncFs', () {
    for (final scenario in syncFsScenarios) {
      test(
        scenario.name,
        () => scenario.run(() async => IoSyncFs(tempDir('io_fs_').path)),
      );
    }
  });

  test('Windows: целевой файл ненадолго занят (облачный клиент) — rename '
      'повторяется и проходит', () async {
    final root = tempDir('io_fs_');
    final fs = IoSyncFs(root.path);
    await fs.writeString('info.json', 'старое');
    final held = await File(p.join(root.path, 'info.json')).open();
    final released = Future<void>.delayed(
      const Duration(milliseconds: 150),
      held.close,
    );

    await fs.writeString('info.json', 'новое');
    await released;

    expect(await fs.readString('info.json'), 'новое');
  }, skip: !Platform.isWindows);

  test('путь с «..» — ошибка, а не выход за корень папки', () async {
    final fs = IoSyncFs(tempDir('io_fs_').path);
    expect(() => fs.writeString('../снаружи.txt', 'x'), throwsArgumentError);
    expect(() => fs.list('nodes/../..'), throwsArgumentError);
  });

  test('writeString — временный файл не похож на чанк и не остаётся', () async {
    final root = tempDir('io_fs_');
    final fs = IoSyncFs(root.path);
    await fs.writeString('nodes/a/000001.ndjson', 'x\n');
    final names = Directory(p.join(root.path, 'nodes', 'a'))
        .listSync()
        .map((e) => p.basename(e.path));
    expect(names, ['000001.ndjson']);
  });

  test('writeStringIfAbsent — из 20 одновременных записей одного файла '
      'проходит одна, содержимое целиком от неё', () async {
    final fs = IoSyncFs(tempDir('io_fs_').path);
    final results = await Future.wait([
      for (var i = 0; i < 20; i++)
        fs.writeStringIfAbsent('nodes/a/000001.ndjson', 'запись $i\n' * 50),
    ]);
    final text = await fs.readString('nodes/a/000001.ndjson');
    final winner = results.indexOf(true);
    expect(results.where((r) => r), hasLength(1));
    expect(text, 'запись $winner\n' * 50);
  });
}
