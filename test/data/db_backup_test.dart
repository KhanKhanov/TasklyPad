import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:planner/data/db_backup.dart';
import 'package:sqlite3/common.dart';
import 'package:sqlite3/sqlite3.dart';

/// Копии в памяти; можно заставить [writeCopy] упасть.
final class _FakeBackups implements BackupStore {
  _FakeBackups([Iterable<String> existing = const []]) : names = [...existing];

  final List<String> names;
  bool failWrites = false;

  @override
  List<String> list() => [...names];

  @override
  void writeCopy(CommonDatabase db, String name) {
    if (failWrites) throw const FileSystemException('диск полон');
    names.add(name);
  }

  @override
  void delete(String name) => names.remove(name);
}

void main() {
  final now = DateTime.utc(2026, 10, 23, 10, 15, 30);
  late CommonDatabase db;

  setUp(() => db = sqlite3.openInMemory());
  tearDown(() => db.close());

  void open(_FakeBackups backups, {int target = 2}) =>
      prepareForOpen(db, targetVersion: target, backups: backups, nowUtc: now);

  test('prepareForOpen — новая база (версия 0) → без копии', () {
    final backups = _FakeBackups();
    open(backups);
    expect(backups.names, isEmpty);
  });

  test('prepareForOpen — актуальная версия → без копии', () {
    db.userVersion = 2;
    final backups = _FakeBackups();
    open(backups);
    expect(backups.names, isEmpty);
  });

  test('prepareForOpen — старая версия → копия с временем и версией', () {
    db.userVersion = 1;
    final backups = _FakeBackups();
    open(backups);
    expect(backups.names, ['pre-migration-20261023T101530000Z-v1.sqlite']);
  });

  test('prepareForOpen — два открытия в одну секунду → разные имена копий', () {
    db.userVersion = 1;
    final backups = _FakeBackups();
    open(backups);
    prepareForOpen(
      db,
      targetVersion: 2,
      backups: backups,
      nowUtc: now.add(const Duration(milliseconds: 1)),
    );
    expect(backups.names.toSet(), hasLength(2));
  });

  test('prepareForOpen — версия новее приложения → SchemaTooNewException', () {
    db.userVersion = 3;
    final backups = _FakeBackups();
    expect(() => open(backups), throwsA(isA<SchemaTooNewException>()));
    expect(backups.names, isEmpty);
  });

  test('prepareForOpen — сбой копии пробрасывается, база не открывается', () {
    db.userVersion = 1;
    final backups = _FakeBackups()..failWrites = true;
    expect(() => open(backups), throwsA(isA<FileSystemException>()));
  });

  test('prepareForOpen — ротация: остаются 14 новейших', () {
    db.userVersion = 1;
    final old = [
      for (var day = 1; day <= 14; day++)
        'pre-migration-202609${day.toString().padLeft(2, '0')}T000000Z-v1.sqlite',
    ];
    final backups = _FakeBackups(old);
    open(backups);
    expect(backups.names, hasLength(backupsToKeep));
    expect(backups.names, isNot(contains(old.first)));
    expect(
      backups.names,
      contains('pre-migration-20261023T101530000Z-v1.sqlite'),
    );
  });

  test('prepareForOpen — ротация не вытесняет новейшую копию прошлой версии', () {
    db.userVersion = 2;
    const beforeV2 = 'pre-migration-20260801T000000000Z-v1.sqlite';
    // Миграция v2 → v3 падала 14 раз подряд — 14 копий версии 2.
    final failed = [
      for (var day = 1; day <= 14; day++)
        'pre-migration-202609${day.toString().padLeft(2, '0')}T000000000Z-v2.sqlite',
    ];
    final backups = _FakeBackups([beforeV2, ...failed]);
    open(backups, target: 3);
    expect(backups.names, contains(beforeV2));
    expect(backups.names, hasLength(backupsToKeep + 1));
    expect(backups.names, isNot(contains(failed.first)));
  });

  group('IoBackupStore', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('planner-backup-'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('writeCopy — VACUUM INTO даёт полную копию с той же версией', () {
      db
        ..execute('CREATE TABLE t (v TEXT)')
        ..execute("INSERT INTO t VALUES ('данные')")
        ..userVersion = 1;
      final store = IoBackupStore(p.join(dir.path, 'backups'));
      store.writeCopy(db, 'pre-migration-x-v1.sqlite');

      final copy = sqlite3.open(
        p.join(dir.path, 'backups', 'pre-migration-x-v1.sqlite'),
      );
      addTearDown(copy.close);
      expect(copy.userVersion, 1);
      expect(copy.select('SELECT v FROM t').single['v'], 'данные');
    });

    test('list — только файлы копий; delete удаляет', () {
      File(p.join(dir.path, 'pre-migration-a-v1.sqlite')).writeAsStringSync('');
      File(p.join(dir.path, 'чужой.sqlite')).writeAsStringSync('');
      final store = IoBackupStore(dir.path);
      expect(store.list(), ['pre-migration-a-v1.sqlite']);
      store.delete('pre-migration-a-v1.sqlite');
      expect(store.list(), isEmpty);
      expect(File(p.join(dir.path, 'чужой.sqlite')).existsSync(), isTrue);
    });

    test('list — папки ещё нет → пусто', () {
      expect(IoBackupStore(p.join(dir.path, 'нет')).list(), isEmpty);
    });
  });
}
