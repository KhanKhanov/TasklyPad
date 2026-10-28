import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/app/sync_providers.dart';
import 'package:planner/data/projection/entity_fields.dart';
import 'package:planner/domain/theme_settings.dart';
import 'package:planner/features/settings/ui/settings_screen.dart';

import '../../app/support/pump_app.dart';
import '../../sync/support/devices.dart';
import '../support/app_commands.dart';
import 'fake_sync.dart';

// «Настройки → Тема»: на компьютере — «Обновить», на Android — сразу
// (docs/plans/m2-core-app.md, M2.3, коммит 4). Локаль — en, система светлая.
void main() {
  final windows = TargetPlatformVariant.only(TargetPlatform.windows);

  Future<void> run(
    WidgetTester tester,
    Future<void> Function(TestDevice device) body, {
    Future<void> Function(TestDevice device)? before,
    void Function()? firstFrame,
  }) => withApp(
    tester,
    overrides: [syncRunnerProvider.overrideWithValue(FakeSyncRunner())],
    before: before,
    firstFrame: firstFrame,
    (device) async {
      await tester.sendKeyEvent(LogicalKeyboardKey.keyO);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
      await settle(tester);
      await body(device);
    },
  );

  Brightness brightness(WidgetTester tester) =>
      Theme.of(tester.element(find.byType(SettingsScreen))).brightness;

  Future<List<String>> settingsFields(
    WidgetTester tester,
    TestDevice device,
  ) async => [
    for (final op in (await tester.runAsync(device.ownOps))!)
      if (op.entityType == EntityTypes.settings) op.field,
  ];

  ButtonStyleButton update() =>
      find.widgetWithText(FilledButton, 'Update').evaluate().single.widget
          as ButtonStyleButton;

  testWidgets('`o` `t` открывает «Настройки»: «Тема» — над «Синхронизацией», '
      'Taskly, «System», синхронизация темы включена', (tester) async {
    await run(tester, (device) async {
      expect(find.byType(SettingsScreen), findsOneWidget);
      final theme = tester.getTopLeft(find.text('Theme')).dy;
      expect(theme, lessThan(tester.getTopLeft(find.text('Sync')).dy));
      expect(find.text('Taskly'), findsOneWidget);
      final segments = tester.widget<SegmentedButton<ThemeAppearance>>(
        find.byType(SegmentedButton<ThemeAppearance>),
      );
      expect(segments.selected, {ThemeAppearance.system});
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue,
      );
    });
  }, variant: windows);

  testWidgets('компьютер: выбор применяет только «Обновить», после — кнопка '
      'неактивна', (tester) async {
    await run(tester, (device) async {
      expect(update().onPressed, isNull);
      await tester.tap(find.text('Dark'));
      await settle(tester);
      expect(brightness(tester), Brightness.light);
      expect(await settingsFields(tester, device), isEmpty);

      await tester.tap(find.text('Update'));
      await settle(tester);
      expect(brightness(tester), Brightness.dark);
      expect(update().onPressed, isNull);
      // Тему не меняли — в общую сущность уходит только внешний вид.
      expect(await settingsFields(tester, device), [
        SettingsFields.themeAppearance,
      ]);
    });
  }, variant: windows);

  testWidgets('компьютер: синхронизация темы выключена — тема на устройстве, '
      'в журнал ничего', (tester) async {
    await run(tester, (device) async {
      // Два нажатия до перерисовки: второе не теряет первое.
      await tester.tap(find.byType(SwitchListTile));
      await tester.tap(find.text('Dark'));
      await tester.pump();
      await tester.tap(find.text('Update'));
      await settle(tester);
      expect(brightness(tester), Brightness.dark);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse,
      );
      final saved = (await tester.runAsync(
        AppCommands(device).themeRepo.load,
      ))!;
      expect(saved.syncTheme, isFalse);
      expect(saved.localAppearance, ThemeAppearance.dark);
      expect(await settingsFields(tester, device), isEmpty);
    });
  }, variant: windows);

  testWidgets('компьютер: несохранённый выбор совпал с пришедшим — выбора '
      'больше нет, следующая пришедшая тема видна в разделе', (tester) async {
    Future<void> fromElsewhere(TestDevice device, ThemeAppearance a) async {
      await tester.runAsync(
        () => AppCommands(device).theme.save(
          ThemeChoice(themeId: 'taskly', appearance: a),
          syncTheme: true,
        ),
      );
      await settle(tester);
    }

    await run(tester, (device) async {
      await tester.tap(find.text('Dark'));
      await settle(tester);
      await fromElsewhere(device, ThemeAppearance.dark);
      expect(update().onPressed, isNull);

      await fromElsewhere(device, ThemeAppearance.light);
      final segments = tester.widget<SegmentedButton<ThemeAppearance>>(
        find.byType(SegmentedButton<ThemeAppearance>),
      );
      expect(segments.selected, {ThemeAppearance.light});
      expect(update().onPressed, isNull);
    });
  }, variant: windows);

  testWidgets('Android: два нажатия подряд — оба действуют: синхронизация '
      'выключена, тёмная тема на устройстве, в журнал ничего', (tester) async {
    await run(tester, (device) async {
      await tester.tap(find.byType(SwitchListTile));
      await tester.pump();
      await tester.tap(find.text('Dark'));
      await settle(tester);
      expect(brightness(tester), Brightness.dark);
      final saved = (await tester.runAsync(
        AppCommands(device).themeRepo.load,
      ))!;
      expect(saved.syncTheme, isFalse);
      expect(saved.localAppearance, ThemeAppearance.dark);
      expect(await settingsFields(tester, device), isEmpty);
    });
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('Android: выбор применяется сразу, кнопки «Обновить» нет', (
    tester,
  ) async {
    await run(tester, (device) async {
      expect(find.text('Update'), findsNothing);
      await tester.tap(find.text('Dark'));
      await settle(tester);
      expect(brightness(tester), Brightness.dark);
    });
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('тема, сменённая не из раздела (синхронизацией), перекрашивает '
      'приложение и раздел', (tester) async {
    await run(tester, (device) async {
      await tester.runAsync(
        () => AppCommands(device).theme.save(
          const ThemeChoice(
            themeId: 'taskly',
            appearance: ThemeAppearance.dark,
          ),
          syncTheme: true,
        ),
      );
      await settle(tester);
      expect(brightness(tester), Brightness.dark);
      final segments = tester.widget<SegmentedButton<ThemeAppearance>>(
        find.byType(SegmentedButton<ThemeAppearance>),
      );
      expect(segments.selected, {ThemeAppearance.dark});
    });
  }, variant: windows);

  testWidgets('сохранённая тёмная тема действует с первого кадра', (
    tester,
  ) async {
    await run(
      tester,
      before: (device) => AppCommands(device).theme.save(
        const ThemeChoice(themeId: 'taskly', appearance: ThemeAppearance.dark),
        syncTheme: false,
      ),
      firstFrame: () => expect(
        Theme.of(tester.element(find.byType(Navigator).first)).brightness,
        Brightness.dark,
      ),
      (device) async {
        expect(brightness(tester), Brightness.dark);
        expect(update().onPressed, isNull);
      },
    );
  }, variant: windows);
}
