import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/data/projection/entity_fields.dart';
import 'package:planner/domain/rules.dart';

import '../../app/support/pump_app.dart';
import '../../sync/support/devices.dart';
import '../support/app_commands.dart';

// Описание проекта (help «Introduction to projects», решение 2А «Часть M4.11»
// plans/m4). Локаль виджет-тестов — en.
Matcher _rejected(RejectReason reason) =>
    throwsA(isA<CommandRejected>().having((e) => e.reason, 'reason', reason));

void main() {
  group('команды', () {
    late TestDevice device;
    late AppCommands app;

    setUp(() async {
      device = await TestDevice.start();
      app = AppCommands(device);
    });

    test('описание хранится как введено — блок кода отступом цел; только из '
        'пробелов — пустое; стирается пустым', () async {
      final p = await app.projects.add(name: 'Work');
      const code = '    final x = 1;\n    print(x);\n';
      await app.projects.setDescription(p, code);
      expect((await app.read()).project(p)!.description, code);
      await app.projects.setDescription(p, '  \n\t ');
      expect((await app.read()).project(p)!.description, '');
      await app.projects.setDescription(p, 'План');
      await app.projects.setDescription(p, '');
      expect((await app.read()).project(p)!.description, '');
    });

    test('у «Входящих» описания нет — отказ', () async {
      expect(
        app.projects.setDescription(inboxProjectId, 'x'),
        _rejected(RejectReason.inboxProtected),
      );
    });

    test('до 16383 символов, эмодзи — один символ; сверх — отказ без '
        'записи', () async {
      final p = await app.projects.add(name: 'Work');
      final full = '😀' * Limits.description;
      await app.projects.setDescription(p, full);
      expect((await app.read()).project(p)!.description, full);

      final before = (await device.ownOps()).length;
      await expectLater(
        app.projects.setDescription(p, '${full}a'),
        _rejected(RejectReason.tooLong),
      );
      expect((await device.ownOps()).length, before);
    });

    test('дубликат копирует описание', () async {
      final p = await app.projects.add(name: 'Work');
      await app.projects.setDescription(p, 'Контекст');
      final copy = await app.projects.duplicate(p, name: 'Copy of Work');
      expect((await app.read()).project(copy)!.description, 'Контекст');
    });
  });

  group('экран проекта', () {
    Future<String> open(WidgetTester tester, TestDevice device) async {
      final id = (await tester.runAsync(
        () => AppCommands(device).projects.add(name: 'Work'),
      ))!;
      await settle(tester);
      await tester.tap(find.text('Work'));
      await settle(tester);
      return id;
    }

    testWidgets('«Add a description» → редактор на месте → «Save» — строка '
        'под названием', (tester) async {
      await withApp(tester, (device) async {
        final id = await open(tester, device);
        await tester.tap(find.text('Add a description'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Квартальный план');
        await tester.tap(find.widgetWithText(FilledButton, 'Save'));
        await settle(tester);

        expect(find.text('Квартальный план'), findsOneWidget);
        expect(find.text('Add a description'), findsNothing);
        final ws = await tester.runAsync(() => AppCommands(device).read());
        expect(ws!.project(id)!.description, 'Квартальный план');
      });
    });

    testWidgets('переход на другой проект с открытым редактором — редактор '
        'закрыт, черновик никуда не записан', (tester) async {
      await withApp(tester, (device) async {
        final work = await open(tester, device);
        final home = (await tester.runAsync(
          () => AppCommands(device).projects.add(name: 'Home'),
        ))!;
        await settle(tester);
        await tester.tap(find.text('Add a description'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Черновик');
        await tester.tap(find.text('Home'));
        await settle(tester);

        expect(find.widgetWithText(TextField, 'Черновик'), findsNothing);
        expect(find.text('Add a description'), findsOneWidget);
        await tester.tap(find.text('Add a description'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Save'));
        await settle(tester);
        final ws = (await tester.runAsync(() => AppCommands(device).read()))!;
        expect(ws.project(home)!.description, '');
        expect(ws.project(work)!.description, '');
      });
    });

    testWidgets('«Save» без правки, когда описание сменилось на другом '
        'устройстве, — без записи: пришедшее не затирается', (tester) async {
      await withApp(tester, (device) async {
        final id = await open(tester, device);
        final app = AppCommands(device);
        await tester.runAsync(() => app.projects.setDescription(id, 'A'));
        await settle(tester);
        await tester.tap(find.text('A'));
        await tester.pumpAndSettle();
        await tester.runAsync(() => app.projects.setDescription(id, 'B'));
        await settle(tester);
        await tester.tap(find.widgetWithText(FilledButton, 'Save'));
        await settle(tester);
        final ws = await tester.runAsync(app.read);
        expect(ws!.project(id)!.description, 'B');
      });
    });

    testWidgets('«Cancel» и Esc ничего не пишут', (tester) async {
      await withApp(tester, (device) async {
        final id = await open(tester, device);
        await tester.tap(find.text('Add a description'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Черновик');
        await tester.tap(find.text('Cancel'));
        await settle(tester);
        expect(find.text('Add a description'), findsOneWidget);

        await tester.tap(find.text('Add a description'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Черновик');
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await settle(tester);
        expect(find.text('Add a description'), findsOneWidget);
        final ws = await tester.runAsync(() => AppCommands(device).read());
        expect(ws!.project(id)!.description, '');
      });
    });

    testWidgets('закрытие редактора («Save», «Cancel», Esc) не обращается к '
        'освобождённому контроллеру: ошибок кадра нет', (tester) async {
      await withApp(tester, (device) async {
        await open(tester, device);
        for (final close in [
          () => tester.tap(find.widgetWithText(FilledButton, 'Save')),
          () => tester.tap(find.text('Cancel')),
          () => tester.sendKeyEvent(LogicalKeyboardKey.escape),
        ]) {
          await tester.tap(find.text('Add a description'));
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextField), '');
          await tester.pump();
          await close();
          await tester.pump();
          expect(tester.takeException(), isNull);
          await settle(tester);
          expect(find.byType(TextField), findsNothing);
        }
      });
    });

    testWidgets('длинное описание — одна строка, при наведении — целиком', (
      tester,
    ) async {
      await withApp(tester, (device) async {
        final id = await open(tester, device);
        final text = List.filled(60, 'длинное описание').join(' ');
        await tester.runAsync(
          () => AppCommands(device).projects.setDescription(id, text),
        );
        await settle(tester);
        Text shown() => tester.widget<Text>(find.text(text));
        expect(shown().maxLines, 1);

        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        addTearDown(mouse.removePointer);
        await mouse.addPointer(location: Offset.zero);
        await mouse.moveTo(
          tester.getTopLeft(find.text(text)) + const Offset(4, 4),
        );
        await tester.pump();
        expect(shown().maxLines, isNull);
      });
    });

    testWidgets('«Edit» проекта — поле «Description» сохраняет описание', (
      tester,
    ) async {
      await withApp(tester, (device) async {
        final id = await open(tester, device);
        await tester.tap(screenMenu());
        await tester.pumpAndSettle();
        await tester.tap(find.text('Edit').last);
        await settle(tester);
        await tester.enterText(
          find.widgetWithText(TextField, 'Description'),
          'Из окна',
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Save'));
        await settle(tester);
        final ws = await tester.runAsync(() => AppCommands(device).read());
        expect(ws!.project(id)!.description, 'Из окна');
        expect(find.text('Из окна'), findsOneWidget);
      });
    });

    testWidgets('«Входящие» — без строки описания', (tester) async {
      await withApp(tester, (_) async {
        expect(find.text('Add a description'), findsNothing);
      });
    });
  });
}
