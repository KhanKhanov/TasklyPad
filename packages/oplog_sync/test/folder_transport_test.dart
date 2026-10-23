import 'dart:convert';

import 'package:oplog_sync/oplog_sync.dart';
import 'package:test/test.dart';

import 'support/test_node.dart';

const int startMs = 1761110400000;
const String root = 'planner-sync';

/// Узел с транспортом через папку [fs] (у каждого устройства — свой вид
/// облачной папки; общий [fs] — облако, которое доставляет мгновенно).
final class Peer {
  Peer(
    String id,
    this.fs, {
    int startMs = startMs,
    String? opIdPrefix,
    Set<String>? silentFields,
    this.maxChunkBytes = FolderTransport.defaultMaxChunkBytes,
  }) : node = Node(
         id,
         startMs: startMs,
         opIdPrefix: opIdPrefix,
         silentFields: silentFields,
       ) {
    transport = transportFor(fs);
  }

  final Node node;
  final SyncFs fs;
  final int maxChunkBytes;
  final MemorySyncStateStore state = MemorySyncStateStore();
  late final FolderTransport transport;

  MergeEngine get engine => node.engine;

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

  /// Номер вызова writeString чанка (с 1), который бросит исключение.
  int? failChunkWriteNo;
  int _chunkWrites = 0;

  /// Пути, чтение которых бросает исключение.
  final Set<String> unreadable = {};

  @override
  Future<bool> exists(String path) => inner.exists(path);

  @override
  Future<List<String>> list(String dir) => inner.list(dir);

  @override
  Future<String> readString(String path) {
    if (unreadable.contains(path)) {
      throw Exception('файл заблокирован: $path');
    }
    return inner.readString(path);
  }

  @override
  Future<void> writeString(String path, String content) {
    if (path.endsWith('.ndjson') && ++_chunkWrites == failChunkWriteNo) {
      throw Exception('диск переполнен');
    }
    return inner.writeString(path, content);
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

/// Все узлы пришли к одинаковым задачам и одинаковым конфликтам.
Future<void> expectConverged(List<Peer> peers) async {
  final first = peers.first.node;
  for (final p in peers.skip(1)) {
    expect(p.node.store.alive('task'), first.store.alive('task'));
    expect(
      (await p.node.conflicts()).map((c) => (c.id, c.resolved)),
      (await first.conflicts()).map((c) => (c.id, c.resolved)),
    );
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

  /// Задача t1 есть на обоих узлах; часы сдвинуты так, что следующие правки
  /// «параллельны» и упорядочены: a раньше b.
  Future<void> sharedTask() async {
    await a.engine.mutate('task', 't1', {'title': 'v0', 'priority': 4});
    await syncAll([a, b]);
    a.node.advance(1000);
    b.node.advance(2000);
  }

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
      expect(b.node.store.alive('task'), hasLength(7));
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
      expect(b.node.task('t1'), {'title': 'v1'});
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
      expect(b.node.store.alive('task'), a.node.store.alive('task'));
      expect(b.node.task('t2'), hasLength(3));
    });

    test('лишний файл в nodes/ (desktop.ini) не мешает', () async {
      await a.engine.mutate('task', 't1', {'title': 'v1'});
      await a.sync();
      await fs.writeString('$root/nodes/desktop.ini', '[.ShellClassInfo]');
      final report = await b.sync();
      expect(report.issues, isEmpty);
      expect(b.node.task('t1'), {'title': 'v1'});
    });
  });

  group('сценарии слияния через папку', () {
    test('создание на одном узле доходит до другого', () async {
      await a.engine.mutate('task', 't1', {'title': 'Отчёт', 'priority': 1});
      await a.sync();
      final report = await b.sync();
      expect(report.received.applied, 2);
      expect(b.node.task('t1'), {'title': 'Отчёт', 'priority': 1});
    });

    test(
      'параллельная правка разных полей — сохраняются обе, без конфликта',
      () async {
        await sharedTask();
        await a.engine.mutate('task', 't1', {'title': 'от a'});
        await b.engine.mutate('task', 't1', {'priority': 1});
        await syncAll([a, b]);

        expect(a.node.task('t1'), {'title': 'от a', 'priority': 1});
        expect(await a.node.conflicts(), isEmpty);
        await expectConverged([a, b]);
      },
    );

    test(
      'параллельная правка одного поля — конфликт с одним id на обоих',
      () async {
        await sharedTask();
        await a.engine.mutate('task', 't1', {'title': 'от a'});
        await b.engine.mutate('task', 't1', {'title': 'от b'});
        await a.sync();
        final atB = await b.sync();
        final atA = await a.sync();

        expect(atB.received.conflicts, hasLength(1));
        expect(atA.received.conflicts.map((c) => c.id), [
          atB.received.conflicts.single.id,
        ]);
        expect(a.node.task('t1')!['title'], 'от b');
        await expectConverged([a, b]);
      },
    );

    test('последовательная правка — конфликта нет', () async {
      await sharedTask();
      await a.engine.mutate('task', 't1', {'title': 'от a'});
      await syncAll([a, b]);
      await b.engine.mutate('task', 't1', {'title': 'от b'});
      await syncAll([a, b]);

      expect(a.node.task('t1')!['title'], 'от b');
      expect(await a.node.conflicts(), isEmpty);
      await expectConverged([a, b]);
    });

    test('правка против удаления — конфликт delete на обоих', () async {
      await sharedTask();
      await a.engine.delete('task', 't1');
      await b.engine.mutate('task', 't1', {'title': 'от b'});
      await syncAll([a, b]);

      final conflicts = await a.node.conflicts();
      expect(conflicts.single.kind, ConflictKind.delete);
      expect(a.node.task('t1')![Op.deletedField], isTrue);
      await expectConverged([a, b]);
    });

    test('разрешение на одном узле закрывает конфликт на другом', () async {
      await sharedTask();
      await a.engine.mutate('task', 't1', {'title': 'от a'});
      await b.engine.mutate('task', 't1', {'title': 'от b'});
      await syncAll([a, b]);
      final id = (await a.node.conflicts()).single.id;

      await a.engine.resolveConflict(id, {'title': 'от a'});
      await syncAll([a, b]);

      expect((await b.node.conflicts()).single.resolved, isTrue);
      expect(b.node.task('t1')!['title'], 'от a');
      await expectConverged([a, b]);
    });

    test(
      'конфликт, разрешённый в более позднем чанке, не попадает в отчёт',
      () async {
        await sharedTask();
        await a.engine.mutate('task', 't1', {'title': 'от a'});
        await a.sync();
        await b.engine.mutate('task', 't1', {'title': 'от b'});
        await b.sync();
        final id = (await b.node.conflicts()).single.id;
        await b.engine.resolveConflict(id, const {});
        await b.sync();

        final report = await a.sync();
        expect(report.received.conflicts, isEmpty);
        expect((await a.node.conflicts()).single.resolved, isTrue);
      },
    );

    test('переупорядочивание — порядок сходится, конфликта нет', () async {
      a = Peer('a', fs, silentFields: {'order_key'});
      b = Peer('b', fs, silentFields: {'order_key'});
      await sharedTask();
      await a.engine.mutate('task', 't1', {'order_key': 'a0'});
      await b.engine.mutate('task', 't1', {'order_key': 'Zz'});
      await syncAll([a, b]);

      expect(a.node.task('t1')!['order_key'], 'Zz');
      expect(await a.node.conflicts(), isEmpty);
      await expectConverged([a, b]);
    });

    test('оба завершили повторяющуюся — две completion, один срок', () async {
      await a.engine.mutate('task', 't1', {
        'title': 'Зарядка',
        'due': '2026-10-23',
      });
      await syncAll([a, b]);
      a.node.advance(1000);
      b.node.advance(2000);
      for (final (p, id) in [(a, 'c-a'), (b, 'c-b')]) {
        await p.engine.mutate('completion', id, {
          'task_id': 't1',
          'due_was': '2026-10-23',
        });
        await p.engine.mutate('task', 't1', {'due': '2026-10-24'});
      }
      await syncAll([a, b]);

      expect(
        a.node.store.alive('completion').keys,
        unorderedEquals(['c-a', 'c-b']),
      );
      expect(a.node.task('t1')!['due'], '2026-10-24');
      expect(await a.node.conflicts(), isEmpty, reason: 'значения due равны');
      await expectConverged([a, b]);
    });

    test(
      'долгий офлайн: узел вчитывает все накопленные чанки по порядку',
      () async {
        await sharedTask();
        for (var i = 1; i <= 5; i++) {
          a.node.advance(60000);
          await a.engine.mutate('task', 't1', {'title': 'a$i'});
          await a.engine.mutate('task', 'n$i', {'title': 'новая $i'});
          await a.sync();
        }
        b.node.advance(600000);
        await b.engine.mutate('task', 't1', {'priority': 2});
        final report = await b.sync();

        expect(report.issues, isEmpty);
        expect(await b.state.chunkCursor('a'), 6);
        expect(b.node.task('t1'), {'title': 'a5', 'priority': 2});
        await syncAll([a, b]);
        await expectConverged([a, b]);
      },
    );

    test('повторная доставка (сброс курсора) ничего не меняет', () async {
      await sharedTask();
      await a.engine.mutate('task', 't1', {'title': 'от a'});
      await b.engine.mutate('task', 't1', {'title': 'от b'});
      await syncAll([a, b]);
      final conflicts = await b.node.conflicts();
      final opCount = b.node.store.opCount;

      await b.state.setChunkCursor('a', 0);
      final report = await b.sync();

      expect(report.received.applied, 0);
      expect(report.received.duplicate, greaterThan(0));
      expect(report.received.conflicts, isEmpty);
      expect(b.node.store.opCount, opCount);
      expect(await b.node.conflicts(), conflicts);
      await expectConverged([a, b]);
    });

    test('три узла: конфликт a и b у c тот же, что у них', () async {
      final c = Peer('c', fs);
      await a.engine.mutate('task', 't1', {'title': 'v0'});
      await syncAll([a, b, c]);
      a.node.advance(1000);
      b.node.advance(2000);
      c.node.advance(3000);
      await a.engine.mutate('task', 't1', {'title': 'от a'});
      await b.engine.mutate('task', 't1', {'title': 'от b'});
      await c.engine.mutate('task', 't1', {'priority': 3});
      await syncAll([a, b, c]);

      expect(await c.node.conflicts(), hasLength(1));
      expect(c.node.task('t1'), {'title': 'от b', 'priority': 3});
      await expectConverged([a, b, c]);
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
        expect(b.node.store.alive('task'), isEmpty);

        await deliver(chunkPath('a', 1));
        final second = await b.sync();
        expect(second.issues, isEmpty);
        expect(b.node.store.alive('task').keys, ['t1', 't2']);
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
        expect(b.node.task('t1'), {'title': 'первая'});
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
      expect(b.node.task('t1'), isNull);
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
      expect(b.node.task('t1'), isNull);
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
        expect(b.node.store.alive('task'), isEmpty);

        await deliver(chunkPath('a', 1));
        await b.sync();
        expect(b.node.task('t1'), {'title': 'первая'});
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
      final c = Peer('c', fs, startMs: startMs + 2 * 3600 * 1000);
      await c.engine.mutate('task', 'tc', {'title': 'из будущего'});
      await c.sync();
      final atA = await a.sync();

      expect(atA.issues.single.kind, ChunkIssueKind.rejected);
      expect(await a.state.chunkCursor('c'), 0);
      expect(a.node.task('tc'), isNull);

      a.node.advance(2 * 3600 * 1000);
      final later = await a.sync();
      expect(later.issues, isEmpty);
      expect(a.node.task('tc'), {'title': 'из будущего'});
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
        startMs: startMs + 60000,
        opIdPrefix: 'a2',
      );
      await restored.engine.mutate('task', 't2', {
        'title': 'после восстановления',
      });
      final report = await restored.sync();

      expect(report.writtenChunks, [2]);
      expect(fs.files[chunkPath('a', 1)], chunk1);
      expect(restored.node.task('t1'), {'title': 'до копии'});
      await b.sync();
      expect(b.node.store.alive('task').keys, unorderedEquals(['t1', 't2']));
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
          startMs: startMs + 60000,
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
          restored.node.store.alive('task').keys,
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
      expect(b.node.task('t2'), {'title': 'вторая'});
      expect(c.node.store.alive('task').keys, unorderedEquals(['t1', 't2']));
    });

    test('часы движка отстают от водяного знака — громкая ошибка', () async {
      await a.state.resetForFolder('x');
      await fs.writeString('$root/format.json', '{"v":1,"folder_id":"x"}\n');
      await a.state.setUploadedUpTo(
        const Hlc(wallMs: startMs + 3600000, counter: 0, nodeId: 'a'),
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
