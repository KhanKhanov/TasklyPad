import 'package:oplog_sync/oplog_sync.dart';
import 'package:test/test.dart';

void main() {
  late MemorySyncFs fs;

  setUp(() => fs = MemorySyncFs());

  test('writeString создаёт родительские папки, readString читает', () async {
    await fs.writeString('nodes/a/000001.ndjson', '{"x":1}\n');
    expect(await fs.exists('nodes'), isTrue);
    expect(await fs.exists('nodes/a'), isTrue);
    expect(await fs.readString('nodes/a/000001.ndjson'), '{"x":1}\n');
  });

  test('appendString дописывает в конец', () async {
    await fs.appendString('log.ndjson', 'a\n');
    await fs.appendString('log.ndjson', 'b\n');
    expect(await fs.readString('log.ndjson'), 'a\nb\n');
  });

  test('list — только прямые дети, отсортированы', () async {
    await fs.writeString('nodes/b/1.ndjson', '');
    await fs.writeString('nodes/a/1.ndjson', '');
    await fs.writeString('nodes/a/2.ndjson', '');
    await fs.writeString('format.json', '{}');
    expect(await fs.list(''), ['format.json', 'nodes']);
    expect(await fs.list('nodes'), ['a', 'b']);
    expect(await fs.list('nodes/a'), ['1.ndjson', '2.ndjson']);
  });

  test('readString несуществующего файла — StateError', () {
    expect(() => fs.readString('nope'), throwsStateError);
  });
}
