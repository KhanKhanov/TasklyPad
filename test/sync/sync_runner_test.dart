import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:oplog_sync/oplog_sync.dart';
import 'package:path/path.dart' as p;
import 'package:planner/sync/io_sync_fs.dart';
import 'package:planner/sync/sync_runner.dart';
import 'package:planner/sync/sync_services.dart';

import '../features/support/app_commands.dart';
import 'support/devices.dart';

SyncRunner _runner(TestDevice device, String name) => SyncRunner(
  services: device.services,
  openFs: IoSyncFs.new,
  deviceInfo: {'device': name, 'platform': 'windows'},
);

Future<List<String>> _titles(TestDevice device) async {
  final ws = await AppCommands(device).read();
  return [for (final t in ws.children(null)) t.content]..sort();
}

/// Файлы папки синхронизации с содержимым — чтобы проверить, что прежнюю
/// папку не трогали.
Map<String, String> _files(String root) => {
  for (final f in Directory(root).listSync(recursive: true))
    if (f is File) p.relative(f.path, from: root): f.readAsStringSync(),
};

/// Последний чанк узла в папке — его «недокачивает» облако.
File _lastChunk(String root, String nodeId) {
  final chunks = [
    for (final f in Directory(
      p.join(root, syncFolderName, 'nodes', nodeId),
    ).listSync())
      if (f is File && f.path.endsWith('.ndjson')) f,
  ]..sort((x, y) => x.path.compareTo(y.path));
  return chunks.last;
}

void main() {
  test('без папки синхронизация не идёт, устройств нет', () async {
    final a = await TestDevice.start(seed: 1);
    final runner = _runner(a, 'A');
    expect(await runner.syncNow(), isNull);
    expect(await runner.devices(), isEmpty);
    expect(await runner.lastSync(), isNull);
  });

  test('два устройства выбирают одну папку — правки сходятся; время '
      'синхронизации и список устройств с этим устройством', () async {
    final folder = tempDir('planner_runner_').path;
    final a = await TestDevice.start(seed: 1);
    final b = await TestDevice.start(seed: 2);
    final ra = _runner(a, 'A');
    final rb = _runner(b, 'B');

    await AppCommands(a).tasks.add(content: 'from A');
    await ra.setFolder(folder);
    await AppCommands(b).tasks.add(content: 'from B');
    await rb.setFolder(folder);
    await ra.syncNow();

    expect(await _titles(a), ['from A', 'from B']);
    expect(await _titles(b), ['from A', 'from B']);
    expect(await ra.lastSync(), isNotNull);

    final devices = await ra.devices();
    expect(
      {for (final d in devices) d.name: d.isThisDevice},
      {'A': true, 'B': false},
    );
    expect(devices.every((d) => d.platform == 'windows'), isTrue);
    expect(devices.every((d) => d.updated != null), isTrue);
  });

  test('смена папки: правки отмеченного «больше не используется» устройства '
      'переиздаются и доходят до нового устройства; прежняя папка не '
      'меняется', () async {
    final oldFolder = tempDir('planner_old_').path;
    final newFolder = tempDir('planner_new_').path;
    final a = await TestDevice.start(seed: 1);
    final b = await TestDevice.start(seed: 2);
    final ra = _runner(a, 'A');
    final rb = _runner(b, 'B');

    await AppCommands(b).tasks.add(content: 'from B');
    await rb.setFolder(oldFolder);
    await AppCommands(a).tasks.add(content: 'from A');
    await ra.setFolder(oldFolder);
    expect(await _titles(a), ['from A', 'from B']);
    final oldFiles = _files(oldFolder);

    expect((await ra.setFolder(newFolder, retired: {b.nodeId})).adopted, {
      b.nodeId,
    });
    expect(_files(oldFolder), oldFiles);

    final c = await TestDevice.start(seed: 3);
    final rc = _runner(c, 'C');
    await rc.setFolder(newFolder);
    expect(await _titles(c), ['from A', 'from B']);

    // Узел B всё же пришёл в новую папку сам, без новых правок: его ops
    // совпадают с копиями по значению — данные те же, конфликтов нет.
    await rb.setFolder(newFolder);
    await rc.syncNow();
    expect(await _titles(c), ['from A', 'from B']);
    expect(await c.services.store.conflicts(), isEmpty);
    expect(await b.services.store.conflicts(), isEmpty);
  });

  test('смена папки без отметок: живое устройство правит в прежней папке и '
      'переезжает само — правки доходят, конфликтов нет ни у кого', () async {
    final oldFolder = tempDir('planner_old_').path;
    final newFolder = tempDir('planner_new_').path;
    final a = await TestDevice.start(seed: 1);
    final b = await TestDevice.start(seed: 2);
    final ra = _runner(a, 'A');
    final rb = _runner(b, 'B');

    final id = await AppCommands(b).tasks.add(content: 'v1');
    await rb.setFolder(oldFolder);
    await ra.setFolder(oldFolder);

    await ra.setFolder(newFolder);
    a.clock.advance(const Duration(minutes: 1));
    b.clock.advance(const Duration(minutes: 1));
    await AppCommands(b).tasks.rename(id, 'v2');
    await rb.syncNow();
    await rb.setFolder(newFolder);
    await ra.syncNow();

    final c = await TestDevice.start(seed: 3);
    await _runner(c, 'C').setFolder(newFolder);
    for (final device in [a, b, c]) {
      expect(await _titles(device), ['v2']);
      expect(await device.services.store.conflicts(), isEmpty);
    }
  });

  test('смена папки: у отмеченного устройства в новой папке устаревшая '
      'папка — его поздние правки всё равно доходят', () async {
    final oldFolder = tempDir('planner_old_').path;
    final newFolder = tempDir('planner_new_').path;
    final a = await TestDevice.start(seed: 1);
    final b = await TestDevice.start(seed: 2);
    final ra = _runner(a, 'A');
    final rb = _runner(b, 'B');

    // B когда-то писал в «новую» папку, потом ушёл в прежнюю.
    await AppCommands(b).tasks.add(content: 'early B');
    await rb.setFolder(newFolder);
    await rb.setFolder(oldFolder);
    await AppCommands(b).tasks.add(content: 'late B');
    await rb.syncNow();
    await ra.setFolder(oldFolder);
    expect(await _titles(a), ['early B', 'late B']);

    await ra.setFolder(newFolder, retired: {b.nodeId});
    final c = await TestDevice.start(seed: 3);
    await _runner(c, 'C').setFolder(newFolder);
    expect(await _titles(c), ['early B', 'late B']);
    expect(await c.services.store.conflicts(), isEmpty);
  });

  test('смена папки: правки, которые отмеченное устройство выгрузило после '
      'нашего прошлого прохода, тоже доходят (последний проход с прежней '
      'папкой)', () async {
    final oldFolder = tempDir('planner_old_').path;
    final newFolder = tempDir('planner_new_').path;
    final a = await TestDevice.start(seed: 1);
    final b = await TestDevice.start(seed: 2);
    final ra = _runner(a, 'A');
    final rb = _runner(b, 'B');

    await AppCommands(b).tasks.add(content: 'from B');
    await rb.setFolder(oldFolder);
    await ra.setFolder(oldFolder);
    await AppCommands(b).tasks.add(content: 'last from B');
    await rb.syncNow();

    expect((await ra.setFolder(newFolder, retired: {b.nodeId})).adopted, {
      b.nodeId,
    });
    final c = await TestDevice.start(seed: 3);
    await _runner(c, 'C').setFolder(newFolder);
    expect(await _titles(c), ['from B', 'last from B']);
  });

  // Каждый вид непрочитанного чанка отмеченного узла (ChunkIssueKind):
  // по виду не понять, пройдёт ли он сам, поэтому смена не начинается, пока
  // пользователь не сменит «всё равно» (решение 12).
  final damages =
      <String, Future<void> Function(String, TestDevice, SyncRunner)>{
        'incomplete — файл обрезан': (folder, b, rb) async {
          await AppCommands(b).tasks.add(content: 'last from B');
          await rb.syncNow();
          _lastChunk(folder, b.nodeId).writeAsStringSync('{"partial');
        },
        'malformed — op не разбирается, хотя файл целый':
            (folder, b, rb) async {
              await AppCommands(b).tasks.add(content: 'last from B');
              await rb.syncNow();
              _lastChunk(
                folder,
                b.nodeId,
              ).writeAsStringSync('не op\n{"end":1}\n');
            },
        'io — файл не читается как текст': (folder, b, rb) async {
          await AppCommands(b).tasks.add(content: 'last from B');
          await rb.syncNow();
          _lastChunk(folder, b.nodeId).writeAsBytesSync([0xC3, 0x28, 0x0A]);
        },
        'missing — чанка в середине нет': (folder, b, rb) async {
          await AppCommands(b).tasks.add(content: 'mid B');
          await rb.syncNow();
          final middle = _lastChunk(folder, b.nodeId);
          await AppCommands(b).tasks.add(content: 'last from B');
          await rb.syncNow();
          middle.deleteSync();
        },
        'rejected — часы устройства спешат больше чем на час':
            (folder, b, rb) async {
              b.advance(const Duration(hours: 2));
              await AppCommands(b).tasks.add(content: 'last from B');
              await rb.syncNow();
            },
      };
  for (final MapEntry(key: name, value: damage) in damages.entries) {
    test('смена папки: чанк отмеченного устройства не прочитан ($name) — смена '
        'не начата; «всё равно» — прочитанное переиздаётся, устройство '
        'названо в итоге', () async {
      final oldFolder = tempDir('planner_old_').path;
      final newFolder = tempDir('planner_new_').path;
      final a = await TestDevice.start(seed: 1);
      final b = await TestDevice.start(seed: 2);
      final ra = _runner(a, 'A');
      final rb = _runner(b, 'B');

      await AppCommands(b).tasks.add(content: 'from B');
      await rb.setFolder(oldFolder);
      await ra.setFolder(oldFolder);
      await damage(oldFolder, b, rb);

      await expectLater(
        ra.setFolder(newFolder, retired: {b.nodeId}),
        throwsA(
          isA<RetiredUnreadException>().having((e) => e.nodes, 'nodes', {
            b.nodeId,
          }),
        ),
      );
      expect(await ra.folderPath(), oldFolder);
      expect(Directory(newFolder).listSync(), isEmpty);

      final change = await ra.setFolder(
        newFolder,
        retired: {b.nodeId},
        force: true,
      );
      expect(change.adopted, {b.nodeId});
      expect(change.unreadable, {b.nodeId});
      expect(await ra.folderPath(), newFolder);

      final c = await TestDevice.start(seed: 3);
      await _runner(c, 'C').setFolder(newFolder);
      expect(await _titles(c), ['from B']);
    });
  }

  // Прежняя папка недоступна целиком: не прочитан никто из отмеченных.
  final unavailable = <String, void Function(String)>{
    'записана более новой версией': (folder) =>
        File(p.join(folder, syncFolderName, 'format.json'))
            .writeAsStringSync('{"v":999,"folder_id":"x"}\n'),
    'удалена': (folder) => Directory(folder).deleteSync(recursive: true),
  };
  for (final MapEntry(key: name, value: breakFolder) in unavailable.entries) {
    test('смена папки: прежняя папка $name — смена не начата, прежняя папка '
        'не создаётся заново; «всё равно» — переиздаётся журнал', () async {
      final oldFolder = tempDir('planner_old_').path;
      final newFolder = tempDir('planner_new_').path;
      final a = await TestDevice.start(seed: 1);
      final b = await TestDevice.start(seed: 2);
      final ra = _runner(a, 'A');

      await AppCommands(b).tasks.add(content: 'from B');
      await _runner(b, 'B').setFolder(oldFolder);
      await ra.setFolder(oldFolder);
      breakFolder(oldFolder);
      final before = Directory(oldFolder).existsSync()
          ? _files(oldFolder)
          : null;

      await expectLater(
        ra.setFolder(newFolder, retired: {b.nodeId}),
        throwsA(
          isA<RetiredUnreadException>().having((e) => e.nodes, 'nodes', {
            b.nodeId,
          }),
        ),
      );
      expect(await ra.folderPath(), oldFolder);

      final change = await ra.setFolder(
        newFolder,
        retired: {b.nodeId},
        force: true,
      );
      expect(change.adopted, {b.nodeId});
      expect(change.unreadable, {b.nodeId});
      expect(
        Directory(oldFolder).existsSync() ? _files(oldFolder) : null,
        before,
      );

      final c = await TestDevice.start(seed: 3);
      await _runner(c, 'C').setFolder(newFolder);
      expect(await _titles(c), ['from B']);
    });
  }

  test('смена папки: чанк живого неотмеченного устройства не прочитан — '
      'смена не останавливается', () async {
    final oldFolder = tempDir('planner_old_').path;
    final a = await TestDevice.start(seed: 1);
    final b = await TestDevice.start(seed: 2);
    final d = await TestDevice.start(seed: 4);
    final ra = _runner(a, 'A');
    final rd = _runner(d, 'D');

    await AppCommands(b).tasks.add(content: 'from B');
    await _runner(b, 'B').setFolder(oldFolder);
    await rd.setFolder(oldFolder);
    await ra.setFolder(oldFolder);
    await AppCommands(d).tasks.add(content: 'from D');
    await rd.syncNow();
    _lastChunk(oldFolder, d.nodeId).writeAsStringSync('{"partial');

    final change = await ra.setFolder(
      tempDir('planner_new_').path,
      retired: {b.nodeId},
    );
    expect(change.adopted, {b.nodeId});
    expect(change.unreadable, isEmpty);
  });

  test('смена папки: первый проход с новой папкой не удался — папка уже '
      'сменена, итог переиздания и ошибка возвращаются', () async {
    final oldFolder = tempDir('planner_old_').path;
    final newFolder = tempDir('planner_new_').path;
    final a = await TestDevice.start(seed: 1);
    final b = await TestDevice.start(seed: 2);
    final ra = _runner(a, 'A');

    await AppCommands(b).tasks.add(content: 'from B');
    await _runner(b, 'B').setFolder(oldFolder);
    await ra.setFolder(oldFolder);
    Directory(p.join(newFolder, syncFolderName)).createSync();
    File(p.join(newFolder, syncFolderName, 'format.json'))
        .writeAsStringSync('{"v":999,"folder_id":"x"}\n');

    final change = await ra.setFolder(newFolder, retired: {b.nodeId});
    expect(change.error, isA<SyncFormatException>());
    expect(change.adopted, {b.nodeId});
    expect(await ra.folderPath(), newFolder);
  });

  test('папку синхронизации удалили — список устройств не «пуст», а не '
      'прочитан', () async {
    final folder = tempDir('planner_runner_').path;
    final a = await TestDevice.start(seed: 1);
    final ra = _runner(a, 'A');
    await ra.setFolder(folder);
    expect(await ra.devices(), hasLength(1));
    Directory(folder).deleteSync(recursive: true);
    await expectLater(ra.devices(), throwsA(isA<SyncFolderMissingException>()));
  });

  test('смена папки атомарна: сбой посреди переиздания — ни копий, ни новой '
      'папки', () async {
    final oldFolder = tempDir('planner_old_').path;
    final newFolder = tempDir('planner_new_').path;
    final a = await TestDevice.start(seed: 1);
    final b = await TestDevice.start(seed: 2);
    final ra = _runner(a, 'A');

    await AppCommands(b).tasks.add(content: 'from B');
    await _runner(b, 'B').setFolder(oldFolder);
    await ra.setFolder(oldFolder);
    final own = (await a.services.store.opsOfNodeAfter(a.nodeId, null)).length;

    // Свой узел переиздать нельзя — сбой после того, как копии B уже записаны.
    await expectLater(
      ra.setFolder(newFolder, retired: {b.nodeId, a.nodeId}),
      throwsArgumentError,
    );
    expect(await ra.folderPath(), oldFolder);
    expect((await a.services.store.opsOfNodeAfter(a.nodeId, null)).length, own);
  });

  test('переиздание при смене папки — не своя правка: сигнала для '
      'отложенной синхронизации нет', () async {
    final oldFolder = tempDir('planner_old_').path;
    final a = await TestDevice.start(seed: 1);
    final b = await TestDevice.start(seed: 2);
    final ra = _runner(a, 'A');
    await AppCommands(b).tasks.add(content: 'from B');
    await _runner(b, 'B').setFolder(oldFolder);
    await ra.setFolder(oldFolder);

    var signals = 0;
    final sub = a.services.mutator.localChanges.listen((_) => signals++);
    final change = await ra.setFolder(
      tempDir('planner_new_').path,
      retired: {b.nodeId},
    );
    expect(change.adopted, {b.nodeId});
    expect(change.unreadable, isEmpty);
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    expect(signals, 0);
  });

  test('пересборка базы из журнала даёт те же данные', () async {
    final a = await TestDevice.start(seed: 1);
    final app = AppCommands(a);
    final id = await app.tasks.add(content: 'one');
    await app.tasks.add(content: 'two');
    await app.tasks.complete(id);
    final before = await app.read();

    await _runner(a, 'A').rebuild();
    final after = await app.read();
    expect(
      [for (final t in after.children(null)) (t.content, t.isCompleted)],
      [for (final t in before.children(null)) (t.content, t.isCompleted)],
    );
  });

  test('папка синхронизации внутри выбранной — planner-sync', () async {
    final folder = tempDir('planner_root_').path;
    final a = await TestDevice.start(seed: 1);
    await _runner(a, 'A').setFolder(folder);
    expect(
      Directory(p.join(folder, syncFolderName, 'nodes', a.nodeId)).existsSync(),
      isTrue,
    );
    expect(await a.services.meta.folderPath(), folder);
  });
}
