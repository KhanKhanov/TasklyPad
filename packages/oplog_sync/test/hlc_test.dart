import 'package:oplog_sync/oplog_sync.dart';
import 'package:test/test.dart';

void main() {
  const node = 'node-a';
  const t0 = 1761110400000; // 2025-10-22T05:20:00Z

  group('Hlc — строковая форма', () {
    test('toString → parse — без потерь', () {
      const hlc = Hlc(wallMs: t0, counter: 3, nodeId: node);
      expect(Hlc.parse(hlc.toString()), hlc);
    });

    test('toString — фиксированная ширина и hex-счётчик', () {
      const hlc = Hlc(wallMs: t0, counter: 255, nodeId: node);
      expect(hlc.toString(), '001761110400000:00FF:node-a');
    });

    test('parse — мусор → FormatException', () {
      expect(() => Hlc.parse('abc'), throwsFormatException);
      expect(() => Hlc.parse('1:2:'), throwsFormatException);
      expect(() => Hlc.parse('x:0001:n'), throwsFormatException);
    });

    test('parse — значения вне диапазона → FormatException, а не assert', () {
      expect(() => Hlc.parse('-5:0001:n'), throwsFormatException);
      expect(() => Hlc.parse('1:-1:n'), throwsFormatException);
      expect(() => Hlc.parse('1:10000:n'), throwsFormatException);
    });

    test('сравнение строк совпадает с compareTo', () {
      final samples = [
        const Hlc(wallMs: t0, counter: 0, nodeId: 'b'),
        const Hlc(wallMs: t0, counter: 0, nodeId: 'a'),
        const Hlc(wallMs: t0 + 1, counter: 0, nodeId: 'a'),
        const Hlc(wallMs: t0, counter: 16, nodeId: 'a'),
        const Hlc(wallMs: t0, counter: 9, nodeId: 'z'),
        const Hlc(wallMs: t0 - 1, counter: 65535, nodeId: 'a'),
      ];
      final byCompare = [...samples]..sort();
      final byString = [...samples]
        ..sort((a, b) => a.toString().compareTo(b.toString()));
      expect(byString, byCompare);
    });
  });

  group('Hlc — порядок', () {
    test('wall важнее counter, counter важнее node', () {
      const a = Hlc(wallMs: t0, counter: 5, nodeId: 'z');
      const b = Hlc(wallMs: t0 + 1, counter: 0, nodeId: 'a');
      const c = Hlc(wallMs: t0, counter: 6, nodeId: 'a');
      expect(a < b, isTrue);
      expect(a < c, isTrue);
      expect(c < b, isTrue);
    });

    test('одинаковые wall и counter — побеждает больший node_id', () {
      const a = Hlc(wallMs: t0, counter: 0, nodeId: 'a');
      const b = Hlc(wallMs: t0, counter: 0, nodeId: 'b');
      expect(b > a, isTrue);
      expect(a == b, isFalse);
    });
  });

  group('Hlc.tick', () {
    test('время идёт вперёд → wall = now, counter = 0', () {
      const h = Hlc(wallMs: t0, counter: 7, nodeId: node);
      expect(
        h.tick(t0 + 10),
        const Hlc(wallMs: t0 + 10, counter: 0, nodeId: node),
      );
    });

    test('та же миллисекунда → растёт counter', () {
      const h = Hlc(wallMs: t0, counter: 7, nodeId: node);
      expect(h.tick(t0), const Hlc(wallMs: t0, counter: 8, nodeId: node));
    });

    test('часы прыгнули назад → wall не уменьшается', () {
      const h = Hlc(wallMs: t0, counter: 0, nodeId: node);
      final next = h.tick(t0 - 5000);
      expect(next.wallMs, t0);
      expect(next.counter, 1);
      expect(next > h, isTrue);
    });

    test('переполнение счётчика → StateError', () {
      const h = Hlc(wallMs: t0, counter: Hlc.maxCounter, nodeId: node);
      expect(() => h.tick(t0), throwsStateError);
    });
  });

  group('Hlc.receive', () {
    test('чужая метка в будущем → берём её wall, counter+1', () {
      const local = Hlc(wallMs: t0, counter: 2, nodeId: node);
      const remote = Hlc(wallMs: t0 + 500, counter: 4, nodeId: 'node-b');
      final next = local.receive(remote, t0 + 1);
      expect(next, const Hlc(wallMs: t0 + 500, counter: 5, nodeId: node));
      expect(next > remote, isTrue);
    });

    test('все три времени равны → max(counter)+1', () {
      const local = Hlc(wallMs: t0, counter: 9, nodeId: node);
      const remote = Hlc(wallMs: t0, counter: 3, nodeId: 'node-b');
      expect(local.receive(remote, t0).counter, 10);
    });

    test('локальное время впереди всех → counter = 0', () {
      const local = Hlc(wallMs: t0, counter: 9, nodeId: node);
      const remote = Hlc(wallMs: t0 - 10, counter: 3, nodeId: 'node-b');
      expect(
        local.receive(remote, t0 + 100),
        const Hlc(wallMs: t0 + 100, counter: 0, nodeId: node),
      );
    });

    test('результат всегда больше и локальной, и чужой метки', () {
      const local = Hlc(wallMs: t0, counter: 1, nodeId: node);
      const remote = Hlc(wallMs: t0 - 1, counter: 1, nodeId: 'node-b');
      final next = local.receive(remote, t0 - 100);
      expect(next > local, isTrue);
      expect(next > remote, isTrue);
    });

    test('чужая метка дальше часа в будущем → HlcDriftException', () {
      const local = Hlc(wallMs: t0, counter: 0, nodeId: node);
      final remote = Hlc(
        wallMs: t0 + Hlc.maxDrift.inMilliseconds + 1,
        counter: 0,
        nodeId: 'node-b',
      );
      expect(
        () => local.receive(remote, t0),
        throwsA(isA<HlcDriftException>()),
      );
    });
  });
}
