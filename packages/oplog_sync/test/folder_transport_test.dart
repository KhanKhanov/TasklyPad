import 'dart:convert';

import 'package:oplog_sync/oplog_sync.dart';
import 'package:oplog_sync/testing.dart';
import 'package:test/test.dart';

const String root = scenarioRoot;

/// Узел с транспортом через папку [fs] (у каждого устройства — свой вид
/// облачной папки; общий [fs] — облако, которое доставляет мгновенно).
final class Peer {
  Peer(
    String id,
    this.fs, {
    int startMs = scenarioStartMs,
    String? opIdPrefix,
    Set<String> silentFields = const {},
    this.maxChunkBytes = FolderTransport.defaultMaxChunkBytes,
  }) {
    node = ScenarioNode(
      probe,
      id,
      startMs: startMs,
      opIdPrefix: opIdPrefix,
      silentFields: silentFields,
    );
    transport = transportFor(fs);
  }

  final MemoryProbe probe = MemoryProbe();
  late final ScenarioNode node;
  final SyncFs fs;
  final int maxChunkBytes;
  final MemorySyncStateStore state = MemorySyncStateStore();
  late final FolderTransport transport;

  MergeEngine get engine => node.engine;

  Map<String, Object?>? task(String id) => probe.store.entity('task', id);

  Map<String, Map<String, Object?>> alive(String type) =>
      probe.store.alive(type);

  Future<FolderSyncReport> sync() => transport.sync();

  /// Транспорт того же узла (та же база и состояние) в другую папку.
  FolderTransport transportFor(SyncFs other) => FolderTransport(
    fs: other,
    engine: node.engine,
    state: state,
    root: root,
    deviceInfo: {'name': 'Устройство ${engine.nodeId}'},
    maxChunkBytes: maxChunkBytes,
  );
}

/// Папка, в которой отдельные файлы не читаются или не пишутся.
final class FaultyFs implements SyncFs {
  FaultyFs(this.inner);

  final MemorySyncFs inner;

  /// Номер записи чанка (с 1), которая бросит исключение.
  int? failChunkWriteNo;
  int _chunkWrites = 0;

  /// Пути, чтение которых бросает исключение.
  final Set<String> unreadable = {};

  /// Пути, которых нет в списке файлов, хотя на диске они есть (облачный
  /// клиент докачал файл после чтения списка).
  final Set<String> unlisted = {};

  /// Вызывается перед первой проверкой существования пути — так другое
  /// устройство «успевает» создать файл между проверкой и записью.
  Future<void> Function(String path)? beforeFirstExists;

  @override
  Future<bool> exists(String path) async {
    final hook = beforeFirstExists;
    if (hook != null) {
      beforeFirstExists = null;
      await hook(path);
      return false;
    }
    return inner.exists(path);
  }

  @override
  Future<List<String>> list(String dir) async => [
    for (final name in await inner.list(dir))
      if (!unlisted.contains('$dir/$name')) name,
  ];

  @override
  Future<String> readString(String path) {
    if (unreadable.contains(path)) {
      throw Exception('файл заблокирован: $path');
    }
    return inner.readString(path);
  }

  /// `info.json` не записывается (облачный клиент держит файл).
  bool failInfoWrite = false;

  @override
  Future<void> writeString(String path, String content) {
    if (failInfoWrite && path.endsWith('info.json')) {
      throw Exception('файл занят другим процессом');
    }
    return inner.writeString(path, content);
  }

  @override
  Future<bool> writeStringIfAbsent(String path, String content) {
    if (path.endsWith('.ndjson') && ++_chunkWrites == failChunkWriteNo) {
      throw Exception('диск переполнен');
    }
    return inner.writeStringIfAbsent(path, content);
  }

  @override
  Future<void> appendString(String path, String content) =>
      inner.appendString(path, content);

  @override
  Future<void> createDir(String path) => inner.createDir(path);
}

/// Ops в чанке (без завершающей строки).
List<Op> chunkOps(MemorySyncFs fs, String nodeId, int seq) {
  final lines = const LineSplitter().convert(fs.files[chunkPath(nodeId, seq)]!);
  expect(jsonDecode(lines.last), {'end': lines.length - 1});
  return [
    for (final line in lines.take(lines.length - 1))
      Op.fromJson(jsonDecode(line) as Map<String, Object?>),
  ];
}

String chunkPath(String nodeId, int seq) =>
    '$root/nodes/$nodeId/${seq.toString().padLeft(6, '0')}.ndjson';

/// Два круга синхронизации: после них каждый узел видел ops всех остальных.
Future<void> syncAll(List<Peer> peers) async {
  for (var round = 0; round < 2; round++) {
    for (final p in peers) {
      await p.sync();
    }
  }
}

void main() {
  late MemorySyncFs fs;
  late Peer a;
  late Peer b;

  setUp(() {
    fs = MemorySyncFs();
    a = Peer('a', fs);
    b = Peer('b', fs);
  });

  // Сценарии из «Инвариантов реализации» — общие с приложением (drift + диск).
  group('сценарии слияния через папку', () {
    for (final scenario in folderSyncScenarios) {
      test(scenario.name, () => scenario.run(memoryFolderSyncEnv));
    }
  });

  group('раскладка папки', () {
    test(
      'первая синхронизация — format.json, чанк 000001 и info.json',
      () async {
        await a.engine.mutate('task', 't1', {'title': 'Отчёт'});
        final report = await a.sync();

        expect(report.writtenChunks, [1]);
        expect(report.uploaded, 1);
        final format = jsonDecode(fs.files['$root/format.json']!);
        expect(format, containsPair('v', 1));
        expect(format, containsPair('folder_id', isNotEmpty));
        final info = jsonDecode(fs.files['$root/nodes/a/info.json']!);
        expect(info, containsPair('node_id', 'a'));
        expect(info, containsPair('last_seq', 1));
        expect(info, containsPair('name', 'Устройство a'));
        final op = chunkOps(fs, 'a', 1).single;
        expect((op.entityId, op.field, op.value), ('t1', 'title', 'Отчёт'));
      },
    );

    test('узел без своих ops — info.json есть, чанков нет', () async {
      final report = await a.sync();
      expect(report.writtenChunks, isEmpty);
      expect(fs.files.keys, ['$root/format.json', '$root/nodes/a/info.json']);
    });

    test('каждая выгрузка — новый чанк, прежние не меняются', () async {
      await a.engine.mutate('task', 't1', {'title': 'v1'});
      await a.sync();
      final first = fs.files[chunkPath('a', 1)];
      await a.engine.mutate('task', 't1', {'title': 'v2'});
      final report = await a.sync();

      expect(report.writtenChunks, [2]);
      expect(fs.files[chunkPath('a', 1)], first);
      expect(fs.files[chunkPath('a', 2)], contains('v2'));
    });

    test('синхронизация без новых ops — новых файлов нет', () async {
      await a.engine.mutate('task', 't1', {'title': 'v1'});
      await a.sync();
      final before = Map.of(fs.files)..remove('$root/nodes/a/info.json');
      final report = await a.sync();

      expect(report.writtenChunks, isEmpty);
      expect(Map.of(fs.files)..remove('$root/nodes/a/info.json'), before);
    });

    test('чанк больше порога делится; одна большая op — свой чанк', () async {
      a = Peer('a', fs, maxChunkBytes: 600);
      for (var i = 0; i < 6; i++) {
        await a.engine.mutate('task', 't$i', {'title': 'задача $i'});
      }
      await a.engine.mutate('task', 'big', {'title': 'x' * 2000});
      final report = await a.sync();

      expect(report.writtenChunks.length, greaterThan(2));
      expect(report.uploaded, 7);
      for (final seq in report.writtenChunks) {
        final text = fs.files[chunkPath('a', seq)]!;
        if (text.contains('x' * 2000)) {
          expect(chunkOps(fs, 'a', seq), hasLength(1));
        } else {
          expect(utf8.encode(text).length, lessThanOrEqualTo(600));
        }
      }
      await b.sync();
      expect(b.alive('task'), hasLength(7));
    });

    test('копия облачного клиента «000001 (1).ndjson» не читается', () async {
      await a.engine.mutate('task', 't1', {'title': 'v1'});
      await a.sync();
      await fs.writeString(
        '$root/nodes/a/000001 (1).ndjson',
        'мусор без перевода строки',
      );
      final report = await b.sync();
      expect(report.issues, isEmpty);
      expect(b.task('t1'), {'title': 'v1'});
    });

    test('ops одной правки (общий HLC) не делятся между чанками', () async {
      a = Peer('a', fs, maxChunkBytes: 400);
      await a.engine.mutate('task', 't1', {
        'title': 't' * 200,
        'note': 'n' * 200,
        'description': 'd' * 200,
      });
      await a.engine.mutate('task', 't2', {'title': 'вторая'});
      final report = await a.sync();

      expect(report.writtenChunks, [1, 2]);
      expect(chunkOps(fs, 'a', 1).map((o) => o.entityId), ['t1', 't1', 't1']);
      expect(chunkOps(fs, 'a', 2).single.entityId, 't2');
    });

    test('сбой записи посреди выгрузки — повтор выгружает всё', () async {
      final faulty = FaultyFs(fs)..failChunkWriteNo = 3;
      a = Peer('a', faulty, maxChunkBytes: 300);
      await a.engine.mutate('task', 't1', {'title': 'первая'});
      await a.engine.mutate('task', 't2', {
        'title': 'x' * 200,
        'priority': 1,
        'note': 'y' * 200,
      });
      await a.engine.mutate('task', 't3', {'title': 'третья'});

      await expectLater(a.sync(), throwsException);
      final retry = await a.sync();

      expect(retry.issues, isEmpty);
      await b.sync();
      expect(b.alive('task'), a.alive('task'));
      expect(b.task('t2'), hasLength(3));
    });

    test('info.json не записался (файл занят) — замечание в отчёте, чанки '
        'выгружены, синхронизация не падает', () async {
      final faulty = FaultyFs(fs)..failInfoWrite = true;
      a = Peer('a', faulty);
      await a.engine.mutate('task', 't1', {'title': 'v1'});
      final report = await a.sync();

      expect(report.writtenChunks, [1]);
      expect(report.issues.single.kind, ChunkIssueKind.io);
      expect(report.issues.single.detail, contains('info.json'));
      await b.sync();
      expect(b.task('t1'), {'title': 'v1'});
    });

    test('MemorySyncFs.writeStringIfAbsent — одновременные вызовы: true ровно '
        'у одного', () async {
      final results = await Future.wait([
        for (var i = 0; i < 5; i++) fs.writeStringIfAbsent('x.json', '$i'),
      ]);
      expect(results.where((r) => r), hasLength(1));
      expect(fs.files['x.json'], '${results.indexOf(true)}');
    });

    test('лишний файл в nodes/ (desktop.ini) не мешает', () async {
      await a.engine.mutate('task', 't1', {'title': 'v1'});
      await a.sync();
      await fs.writeString('$root/nodes/desktop.ini', '[.ShellClassInfo]');
      final report = await b.sync();
      expect(report.issues, isEmpty);
      expect(b.task('t1'), {'title': 'v1'});
    });

    test('список файлов отстал от диска — чанк с занятым номером не '
        'перезаписан, взят следующий', () async {
      await a.engine.mutate('task', 't1', {'title': 'до копии'});
      await a.sync();
      final chunk1 = fs.files[chunkPath('a', 1)];

      // Восстановленная копия a не видит в списке уже лежащий чанк 1.
      final lagging = FaultyFs(fs)..unlisted.add('$root/nodes/a/000001.ndjson');
      final restored = Peer(
        'a',
        lagging,
        startMs: scenarioStartMs + 60000,
        opIdPrefix: 'a2',
      );
      await restored.engine.mutate('task', 't2', {'title': 'после'});
      final report = await restored.sync();

      expect(report.writtenChunks, [2]);
      expect(fs.files[chunkPath('a', 1)], chunk1);
      await b.sync();
      expect(b.alive('task').keys, unorderedEquals(['t1', 't2']));
    });

    test('format.json создан другим устройством между проверкой и записью — '
        'берётся его id, файл не затёрт', () async {
      const other = '{"v":1,"folder_id":"чужая"}\n';
      final racing = FaultyFs(fs)
        ..beforeFirstExists = (path) =>
            fs.writeString('$root/format.json', other);
      a = Peer('a', racing);
      await a.engine.mutate('task', 't1', {'title': 'v1'});
      await a.sync();

      expect(fs.files['$root/format.json'], other);
      expect(await a.state.folderId(), 'чужая');
    });
  });

  group('недокачанные и битые файлы', () {
    // У b свой вид облачной папки: файлы a доходят до него с задержкой.
    late MemorySyncFs fsB;

    setUp(() {
      fsB = MemorySyncFs();
      b = Peer('b', fsB);
    });

    Future<void> deliver(String path, {String? content}) =>
        fsB.writeString(path, content ?? fs.files[path]!);

    Future<void> twoChunksFromA() async {
      await a.engine.mutate('task', 't1', {'title': 'первая'});
      await a.sync();
      await a.engine.mutate('task', 't2', {'title': 'вторая'});
      await a.sync();
      await deliver('$root/format.json');
    }

    test(
      'пропущенный номер — ждём недостающий чанк, следующие не читаем',
      () async {
        await twoChunksFromA();
        await deliver(chunkPath('a', 2));

        final first = await b.sync();
        expect(first.issues.single.kind, ChunkIssueKind.missing);
        expect(first.issues.single.seq, 1);
        expect(b.alive('task'), isEmpty);

        await deliver(chunkPath('a', 1));
        final second = await b.sync();
        expect(second.issues, isEmpty);
        expect(b.alive('task').keys, ['t1', 't2']);
        expect(await b.state.chunkCursor('a'), 2);
      },
    );

    test(
      'неполная последняя строка — чанк пропущен, курсор на месте',
      () async {
        await twoChunksFromA();
        final full = fs.files[chunkPath('a', 1)]!;
        await deliver(
          chunkPath('a', 1),
          content: full.substring(0, full.length ~/ 2),
        );

        final first = await b.sync();
        expect(first.issues.single.kind, ChunkIssueKind.incomplete);
        expect(await b.state.chunkCursor('a'), 0);

        await deliver(chunkPath('a', 1));
        await b.sync();
        expect(b.task('t1'), {'title': 'первая'});
        expect(await b.state.chunkCursor('a'), 1);
      },
    );

    test('пустой файл чанка — докачивается, не ошибка формата', () async {
      await twoChunksFromA();
      await deliver(chunkPath('a', 1), content: '');
      final report = await b.sync();
      expect(report.issues.single.kind, ChunkIssueKind.incomplete);
    });

    test('обрыв ровно на границе строк — недокачан (нет строки end)', () async {
      a = Peer('a', fs);
      await a.engine.mutate('task', 't1', {'title': 'первая', 'priority': 1});
      await a.sync();
      await deliver('$root/format.json');
      final full = fs.files[chunkPath('a', 1)]!;
      await deliver(
        chunkPath('a', 1),
        content: full.substring(0, full.indexOf('\n') + 1),
      );

      final report = await b.sync();
      expect(report.issues.single.kind, ChunkIssueKind.incomplete);
      expect(b.task('t1'), isNull);
      expect(await b.state.chunkCursor('a'), 0);
    });

    test('число ops не совпадает со строкой end — битый чанк', () async {
      await twoChunksFromA();
      final full = fs.files[chunkPath('a', 1)]!;
      await deliver(
        chunkPath('a', 1),
        content: full.replaceFirst('{"end":1}', '{"end":2}'),
      );
      final report = await b.sync();
      expect(report.issues.single.kind, ChunkIssueKind.malformed);
      expect(b.task('t1'), isNull);
    });

    test('нечитаемый чужой файл — в отчёте, своя выгрузка идёт', () async {
      await twoChunksFromA();
      await deliver(chunkPath('a', 1));
      final faulty = FaultyFs(fsB)..unreadable.add(chunkPath('a', 1));
      b = Peer('b', faulty);
      await b.engine.mutate('task', 'tb', {'title': 'от b'});

      final report = await b.sync();
      expect(report.issues.single.kind, ChunkIssueKind.io);
      expect(report.writtenChunks, [1]);
      expect(fsB.files.keys, contains(chunkPath('b', 1)));
    });

    test(
      'битая строка — чанк не применяется целиком, после исправления читается',
      () async {
        await twoChunksFromA();
        final good = fs.files[chunkPath('a', 1)]!;
        await deliver(chunkPath('a', 1), content: '{"op_id": обрыв\n$good');

        final first = await b.sync();
        expect(first.issues.single.kind, ChunkIssueKind.malformed);
        expect(first.issues.single.detail, startsWith('строка 1'));
        expect(b.alive('task'), isEmpty);

        await deliver(chunkPath('a', 1));
        await b.sync();
        expect(b.task('t1'), {'title': 'первая'});
      },
    );

    test('op чужого узла в папке узла — битый чанк', () async {
      await twoChunksFromA();
      await deliver(chunkPath('c', 1), content: fs.files[chunkPath('a', 1)]);
      final report = await b.sync();
      expect(report.issues.single.kind, ChunkIssueKind.malformed);
      expect(report.issues.single.nodeId, 'c');
    });

    test('op из будущего — чанк перечитывается, когда часы догонят', () async {
      final c = Peer('c', fs, startMs: scenarioStartMs + 2 * 3600 * 1000);
      await c.engine.mutate('task', 'tc', {'title': 'из будущего'});
      await c.sync();
      final atA = await a.sync();

      expect(atA.issues.single.kind, ChunkIssueKind.rejected);
      expect(await a.state.chunkCursor('c'), 0);
      expect(a.task('tc'), isNull);

      a.node.advance(2 * 3600 * 1000);
      final later = await a.sync();
      expect(later.issues, isEmpty);
      expect(a.task('tc'), {'title': 'из будущего'});
    });
  });

  group('формат и восстановление', () {
    test(
      'format.json новее поддерживаемого — ошибка, ничего не пишем',
      () async {
        await fs.writeString('$root/format.json', '{"v": 2}\n');
        await a.engine.mutate('task', 't1', {'title': 'v1'});

        await expectLater(a.sync(), throwsA(isA<SyncFormatException>()));
        expect(fs.files.keys, ['$root/format.json']);
      },
    );

    test('format.json не разбирается — ошибка', () async {
      await fs.writeString('$root/format.json', 'не json');
      await expectLater(a.sync(), throwsA(isA<SyncFormatException>()));
    });

    test('восстановление базы из копии: чанки не затираются, свои ops возвращаются', () async {
      await a.engine.mutate('task', 't1', {'title': 'до копии'});
      await a.sync();
      final chunk1 = fs.files[chunkPath('a', 1)];

      // База a восстановлена из копии, сделанной до первой синхронизации.
      final restored = Peer(
        'a',
        fs,
        startMs: scenarioStartMs + 60000,
        opIdPrefix: 'a2',
      );
      await restored.engine.mutate('task', 't2', {
        'title': 'после восстановления',
      });
      final report = await restored.sync();

      expect(report.writtenChunks, [2]);
      expect(fs.files[chunkPath('a', 1)], chunk1);
      expect(restored.task('t1'), {'title': 'до копии'});
      await b.sync();
      expect(b.alive('task').keys, unorderedEquals(['t1', 't2']));
    });

    test(
      'восстановление из копии после первой синхронизации — номер следующий',
      () async {
        await a.engine.mutate('task', 't1', {'title': 'в копии'});
        await a.sync();
        a.node.advance(1000);
        await a.engine.mutate('task', 't2', {'title': 'после копии'});
        await a.sync();
        final before = Map.of(fs.files);

        // Копия базы сделана сразу после чанка 1: в ней его ops и курсоры.
        final restored = Peer(
          'a',
          fs,
          startMs: scenarioStartMs + 60000,
          opIdPrefix: 'a2',
        );
        final chunk1 = chunkOps(fs, 'a', 1);
        await restored.engine.applyAll(chunk1);
        await restored.state.resetForFolder(
          (jsonDecode(fs.files['$root/format.json']!) as Map)['folder_id']
              as String,
        );
        await restored.state.setChunkCursor('a', 1);
        await restored.state.setUploadedUpTo(chunk1.last.hlc);
        await restored.engine.mutate('task', 't3', {'title': 'новая'});
        final report = await restored.sync();

        expect(report.writtenChunks, [3]);
        for (final seq in [1, 2]) {
          expect(fs.files[chunkPath('a', seq)], before[chunkPath('a', seq)]);
        }
        expect(
          restored.alive('task').keys,
          unorderedEquals(['t1', 't2', 't3']),
        );
        expect(await restored.state.chunkCursor('a'), 3);
      },
    );

    test('смена папки — курсоры сброшены, новая папка получает всё', () async {
      await a.engine.mutate('task', 't1', {'title': 'первая'});
      await syncAll([a, b]);
      await a.engine.mutate('task', 't2', {'title': 'вторая'});

      final newFs = MemorySyncFs();
      await a.transportFor(newFs).sync();
      await b.transportFor(newFs).sync();
      final c = Peer('c', newFs);
      await c.sync();

      expect(chunkOps(newFs, 'a', 1), hasLength(2));
      expect(b.task('t2'), {'title': 'вторая'});
      expect(c.alive('task').keys, unorderedEquals(['t1', 't2']));
    });

    test('часы движка отстают от водяного знака — громкая ошибка', () async {
      await a.state.resetForFolder('x');
      await fs.writeString('$root/format.json', '{"v":1,"folder_id":"x"}\n');
      await a.state.setUploadedUpTo(
        const Hlc(wallMs: scenarioStartMs + 3600000, counter: 0, nodeId: 'a'),
      );
      await a.engine.mutate('task', 't1', {'title': 'v1'});
      await expectLater(a.sync(), throwsStateError);
    });

    test('параллельный вызов sync — одна синхронизация', () async {
      await a.engine.mutate('task', 't1', {'title': 'v1'});
      final first = a.sync();
      final second = a.sync();
      expect(identical(await first, await second), isTrue);
      expect(fs.files.keys.where((k) => k.endsWith('.ndjson')), hasLength(1));
    });
  });
}
