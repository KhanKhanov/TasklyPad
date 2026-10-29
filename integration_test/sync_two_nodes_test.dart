import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:planner/app/bootstrap.dart';
import 'package:planner/data/repositories/workspace_repository.dart';
import 'package:planner/features/labels/logic/label_commands.dart';
import 'package:planner/features/tasks/logic/task_commands.dart';
import 'package:planner/sync/io_sync_fs.dart';
import 'package:planner/sync/sync_runner.dart';
import 'package:planner/sync/sync_services.dart';

/// Устройство-профиль на настоящей платформе: база в файле (фоновый изолят
/// drift_flutter), папка синхронизации на диске через `IoSyncFs`.
final class _Device {
  _Device(this.services, String name)
    : runner = SyncRunner(
        services: services,
        openFs: IoSyncFs.new,
        deviceInfo: {'device': name, 'platform': 'windows'},
      ),
      repo = WorkspaceRepository(services.db) {
    tasks = TaskCommands(
      mutator: services.mutator,
      read: repo.load,
      clock: services.clock,
    );
    labels = LabelCommands(mutator: services.mutator, read: repo.load);
  }

  final SyncServices services;
  final SyncRunner runner;
  final WorkspaceRepository repo;
  late final TaskCommands tasks;
  late final LabelCommands labels;

  Future<List<String>> titles() async =>
      [for (final t in (await repo.load()).children(null)) t.content]..sort();
}

// Два узла через временную папку: то же, что test/sync, но с файлом базы и
// настоящей файловой системой Windows. Запуск — по одному файлу:
//   flutter test integration_test/sync_two_nodes_test.dart -d windows
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Две базы в одном процессе — это два профиля с разными файлами, а не
  // одна база, открытая дважды: предупреждение drift здесь ложное.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('planner_it_sync_'));

  tearDown(() {
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows может держать файл базы ещё мгновение — временная папка.
    }
  });

  testWidgets('два профиля через папку на диске: правки и метки сходятся, '
      'параллельное переименование — один конфликт с одним id на обоих, '
      'временных файлов не остаётся', (tester) async {
    final data = p.join(dir.path, 'data');
    final markers = p.join(dir.path, 'marker');
    final folder = Directory(p.join(dir.path, 'cloud'))..createSync();
    final a = _Device(
      await bootstrap(
        dataDirectory: data,
        markerDirectory: markers,
        profile: 'a',
      ),
      'A',
    );
    addTearDown(a.services.close);
    final b = _Device(
      await bootstrap(
        dataDirectory: data,
        markerDirectory: markers,
        profile: 'b',
      ),
      'B',
    );
    addTearDown(b.services.close);

    final home = await a.labels.add(name: 'дом');
    final shared = await a.tasks.add(content: 'из A', labelIds: {home});
    await a.runner.setFolder(folder.path);
    await b.tasks.add(content: 'из B');
    await b.runner.setFolder(folder.path);
    await a.runner.syncNow();

    expect(await a.titles(), ['из A', 'из B']);
    expect(await b.titles(), ['из A', 'из B']);
    expect((await b.repo.load()).task(shared)!.labelIds, [home]);

    // Оба переименовали одну задачу, не видя правки друг друга.
    await a.tasks.rename(shared, 'вариант A');
    await b.tasks.rename(shared, 'вариант B');
    await a.runner.syncNow();
    await b.runner.syncNow();
    await a.runner.syncNow();

    final onA = await a.services.store.conflicts();
    final onB = await b.services.store.conflicts();
    expect(onA, hasLength(1));
    expect([for (final c in onB) c.id], [for (final c in onA) c.id]);
    expect(
      (await a.repo.load()).task(shared)!.content,
      (await b.repo.load()).task(shared)!.content,
    );

    final leftovers = [
      for (final f in folder.listSync(recursive: true))
        if (f is File && f.path.endsWith('.tmp')) f.path,
    ];
    expect(leftovers, isEmpty);
  });
}
