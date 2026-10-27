import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:planner/app/app.dart';
import 'package:planner/app/bootstrap.dart';
import 'package:planner/app/sync_providers.dart';
import 'package:planner/data/db_backup.dart';
import 'package:planner/data/projection/entity_fields.dart';
import 'package:planner/features/projects/ui/project_screen.dart';
import 'package:sqlite3/sqlite3.dart';

// Запуск на настоящей платформе: drift_flutter открывает файл в фоновом
// изоляте, там же `setup` проверяет версию схемы. Обычные тесты работают с
// базой в памяти и этот путь не проходят.
//   flutter test integration_test -d windows
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late String markers;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('planner_it_');
    markers = p.join(dir.path, 'marker');
  });

  tearDown(() {
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows может держать файл базы ещё мгновение — временная папка.
    }
  });

  testWidgets('первый запуск — файл базы, узел и «Входящие»; второй — тот же '
      'узел, приложение показывает «Входящие»', (tester) async {
    final first = await bootstrap(
      dataDirectory: dir.path,
      markerDirectory: markers,
    );
    expect(File(p.join(dir.path, 'planner.sqlite')).existsSync(), isTrue);
    expect(
      File(p.join(markers, 'node_id.txt')).readAsStringSync().trim(),
      (first.nodeId),
    );
    expect(
      await first.store.fieldValue(
        EntityTypes.project,
        inboxProjectId,
        ProjectFields.isInbox,
      ),
      isTrue,
    );
    final nodeId = first.nodeId;
    await first.close();

    final second = await bootstrap(
      dataDirectory: dir.path,
      markerDirectory: markers,
    );
    expect(second.nodeId, nodeId);
    expect(second.identity.isNew, isFalse);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [syncServicesProvider.overrideWithValue(second)],
        child: const PlannerApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ProjectScreen), findsOneWidget);
    // Снять дерево до закрытия базы: снимок читает её потоком.
    await tester.pumpWidget(const SizedBox.shrink());
    await second.close();
  });

  testWidgets('база новее приложения — SchemaTooNewException из фонового '
      'изолята, данные не тронуты', (tester) async {
    final file = p.join(dir.path, 'planner.sqlite');
    sqlite3.open(file)
      ..execute('CREATE TABLE future_data (x TEXT)')
      ..execute("INSERT INTO future_data VALUES ('из будущего')")
      ..userVersion = 99
      ..close();

    await expectLater(
      bootstrap(dataDirectory: dir.path, markerDirectory: markers),
      throwsA(isA<SchemaTooNewException>().having((e) => e.found, 'found', 99)),
    );

    final raw = sqlite3.open(file);
    addTearDown(raw.close);
    expect(raw.userVersion, 99);
    expect(raw.select('SELECT x FROM future_data').single['x'], 'из будущего');
    expect(Directory(p.join(dir.path, 'backups')).existsSync(), isFalse);
    expect(File(p.join(markers, 'node_id.txt')).existsSync(), isFalse);
  });

  testWidgets('профили: у каждого своя база и свой узел в подпапках, '
      'основной профиль не тронут', (tester) async {
    final a = await bootstrap(
      dataDirectory: dir.path,
      markerDirectory: markers,
      profile: 'a',
    );
    final aNode = a.nodeId;
    await a.close();
    final b = await bootstrap(
      dataDirectory: dir.path,
      markerDirectory: markers,
      profile: 'b',
    );
    final bNode = b.nodeId;
    await b.close();

    expect(aNode, isNot(bNode));
    for (final (name, node) in [('a', aNode), ('b', bNode)]) {
      expect(
        File(p.join(dir.path, 'profiles', name, 'planner.sqlite')).existsSync(),
        isTrue,
      );
      expect(
        File(p.join(markers, 'profiles', name, 'node_id.txt'))
            .readAsStringSync()
            .trim(),
        node,
      );
    }
    expect(File(p.join(dir.path, 'planner.sqlite')).existsSync(), isFalse);
    expect(File(p.join(markers, 'node_id.txt')).existsSync(), isFalse);
  });
}
