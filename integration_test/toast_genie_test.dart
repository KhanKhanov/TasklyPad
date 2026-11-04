import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:planner/app/app.dart';
import 'package:planner/app/bootstrap.dart';
import 'package:planner/app/sync_providers.dart';
import 'package:planner/features/common/ui/app_toast.dart';

// Эффект «джин» нижнего уведомления на настоящей платформе: кадры в
// середине появления и ухода (решение пользователя 1А «Анимация
// уведомлений»). Кадры — в SCREENSHOT_DIR:
//   flutter test integration_test/toast_genie_test.dart -d windows
//     --dart-define=SCREENSHOT_DIR=C:/temp/shots
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const shots = String.fromEnvironment('SCREENSHOT_DIR');

  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('planner_toast_'));

  tearDown(() {
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows может держать файл базы ещё мгновение — временная папка.
    }
  });

  Future<void> shot(WidgetTester tester, String name) async {
    if (shots.isEmpty) return;
    final view = tester.binding.renderViews.first;
    // ignore: invalid_use_of_protected_member — корневой слой окна целиком.
    final layer = view.layer! as OffsetLayer;
    final ratio = view.flutterView.devicePixelRatio;
    final image = await layer.toImage(Offset.zero & (view.size * ratio));
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    Directory(shots).createSync(recursive: true);
    File(p.join(shots, '$name.png'))
        .writeAsBytesSync(bytes!.buffer.asUint8List());
  }

  testWidgets('уведомление появляется и уходит «джином»', (tester) async {
    final services = await bootstrap(
      dataDirectory: p.join(dir.path, 'data'),
      markerDirectory: p.join(dir.path, 'marker'),
      profile: 'a',
    );
    final container = ProviderContainer(
      overrides: [syncServicesProvider.overrideWithValue(services)],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const PlannerApp(),
      ),
    );
    await tester.pumpAndSettle();
    final messenger = ScaffoldMessenger.of(
      tester.element(find.byType(Scaffold).first),
    );

    /// Кадр через [ms] мс настоящего времени: анимация идёт по часам.
    Future<void> frameAfter(int ms, String name) async {
      await tester.runAsync(
        () => Future<void>.delayed(Duration(milliseconds: ms)),
      );
      await tester.pump();
      await shot(tester, name);
    }

    final toast = showAppToast(
      messenger,
      text: 'Срок изменён у задач: 3',
      action: (label: 'Отменить', onPressed: () {}),
      duration: const Duration(seconds: 30),
    );
    await tester.pump();
    await frameAfter(120, 'genie-1-in');
    await frameAfter(130, 'genie-2-in');
    await tester.pumpAndSettle();
    await shot(tester, 'genie-3-shown');
    expect(find.text('Срок изменён у задач: 3'), findsOneWidget);

    toast.dismiss();
    await tester.pump();
    await frameAfter(150, 'genie-4-out');
    await frameAfter(150, 'genie-5-out');
    await tester.pumpAndSettle();
    expect(find.text('Срок изменён у задач: 3'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await services.close();
  });
}
