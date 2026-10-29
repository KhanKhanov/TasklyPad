import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oplog_sync/oplog_sync.dart';
import 'package:planner/app/sync_providers.dart';
import 'package:planner/domain/sync_status.dart';
import 'package:planner/features/settings/state/sync_controller.dart';
import 'package:planner/features/settings/ui/settings_screen.dart';

import '../../app/support/pump_app.dart';
import '../support/app_commands.dart';
import 'fake_sync.dart';

// Расписание синхронизации и экран «Настройки → Синхронизация». Проходы —
// фейк; настоящие — test/sync/sync_runner_test.dart. Локаль — en.
void main() {
  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings').last);
    await settle(tester);
  }

  testWidgets('расписание: при запуске, через 5 с после своей правки, раз в '
      'минуту', (tester) async {
    final runner = FakeSyncRunner(folder: 'C:/OneDrive');
    await withApp(
      tester,
      overrides: [syncRunnerProvider.overrideWithValue(runner)],
      (device) async {
        expect(runner.syncs, 1, reason: 'при запуске');

        await tester.runAsync(
          () => AppCommands(device).tasks.add(content: 'Buy milk'),
        );
        await tester.pump(const Duration(seconds: 4));
        expect(runner.syncs, 1, reason: 'ещё не прошло 5 с');
        await tester.pump(const Duration(seconds: 2));
        expect(runner.syncs, 2, reason: 'через 5 с после правки');

        await tester.pump(SyncController.period);
        expect(runner.syncs, greaterThanOrEqualTo(3), reason: 'по таймеру');
      },
    );
  });

  testWidgets('без папки синхронизация не запускается ни по таймеру, ни после '
      'правки', (tester) async {
    final runner = FakeSyncRunner();
    await withApp(
      tester,
      overrides: [syncRunnerProvider.overrideWithValue(runner)],
      (device) async {
        await tester.runAsync(
          () => AppCommands(device).tasks.add(content: 'Buy milk'),
        );
        await tester.pump(const Duration(seconds: 70));
        expect(runner.syncs, 0);
      },
    );
  });

  testWidgets('настройки: выбрать папку → синхронизация, тост, устройства; '
      '«Sync now»; ошибка формата папки — понятный текст', (tester) async {
    final runner = FakeSyncRunner()
      ..deviceList = const [
        SyncDevice(nodeId: 'a', name: 'DESKTOP', isThisDevice: true),
        SyncDevice(
          nodeId: 'b',
          name: 'DESKTOP',
          profile: 'b',
          isThisDevice: false,
        ),
      ];
    final picker = FakeFolderPicker('C:/OneDrive');
    await withApp(
      tester,
      overrides: [
        syncRunnerProvider.overrideWithValue(runner),
        folderPickerProvider.overrideWithValue(picker),
      ],
      (_) async {
        await openSettings(tester);
        expect(find.byType(SettingsScreen), findsOneWidget);
        expect(find.textContaining('No folder chosen'), findsOneWidget);
        expect(find.text('Sync now'), findsNothing);

        await tester.tap(find.text('Choose folder…'));
        await settle(tester);
        expect(runner.folders, ['C:/OneDrive']);
        expect(find.text('Folder connected'), findsOneWidget);
        expect(find.text('C:/OneDrive'), findsOneWidget);
        expect(find.textContaining('Last synced'), findsOneWidget);
        expect(find.text('DESKTOP — this device'), findsOneWidget);
        expect(find.text('DESKTOP (b)'), findsOneWidget);

        final before = runner.syncs;
        runner.failNext = const SyncFormatException('v2');
        await tester.tap(find.text('Sync now'));
        await settle(tester);
        expect(runner.syncs, before + 1);
        expect(find.textContaining('newer version of the app'), findsOneWidget);

        await tester.tap(find.text('Sync now'));
        await settle(tester);
        expect(find.textContaining('newer version of the app'), findsNothing);
      },
    );
  });

  testWidgets('смена папки — после подтверждения; переносятся правки только '
      'отмеченных «больше не используется», по умолчанию — ничьи', (
    tester,
  ) async {
    final runner = FakeSyncRunner(folder: 'C:/Old')
      ..deviceList = const [
        SyncDevice(nodeId: 'a', name: 'DESKTOP', isThisDevice: true),
        SyncDevice(nodeId: 'b', name: 'LAPTOP', isThisDevice: false),
        SyncDevice(nodeId: 'c', name: 'OLD-PC', isThisDevice: false),
      ];
    final picker = FakeFolderPicker('D:/New');
    await withApp(
      tester,
      overrides: [
        syncRunnerProvider.overrideWithValue(runner),
        folderPickerProvider.overrideWithValue(picker),
      ],
      (_) async {
        await openSettings(tester);
        await tester.tap(find.text('Change folder…'));
        await tester.pumpAndSettle();
        expect(picker.lastInitial, 'C:/Old');
        expect(find.text('Change sync folder?'), findsOneWidget);
        final dialog = find.byType(AlertDialog);
        expect(
          find.descendant(of: dialog, matching: find.byType(CheckboxListTile)),
          findsNWidgets(2),
          reason: 'своё устройство в списке не предлагается',
        );
        expect(
          tester
              .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
              .every((tile) => tile.value == false),
          isTrue,
          reason: 'по умолчанию никто не отмечен',
        );
        await tester.tap(find.text('Cancel'));
        await settle(tester);
        expect(runner.folders, isEmpty);

        await tester.tap(find.text('Change folder…'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('OLD-PC'),
          ),
        );
        await tester.pump();
        await tester.tap(find.widgetWithText(FilledButton, 'Change'));
        await settle(tester);
        expect(runner.folders, ['D:/New']);
        expect(runner.retiredSets, [
          {'c'},
        ]);
        expect(find.textContaining('written to it: 1'), findsOneWidget);
      },
    );
  });

  testWidgets('смена папки: часть правок отмеченного не прочитана — вопрос '
      '«подождать или сменить всё равно»: отказ — текст и прежняя папка; '
      '«Change anyway» — смена с force; у отмеченного нечего переиздавать — '
      'тост без числа', (tester) async {
    final runner = FakeSyncRunner(folder: 'C:/Old')
      ..deviceList = const [
        SyncDevice(nodeId: 'c', name: 'OLD-PC', isThisDevice: false),
      ]
      ..adoptedResult = const {};
    await withApp(
      tester,
      overrides: [
        syncRunnerProvider.overrideWithValue(runner),
        folderPickerProvider.overrideWithValue(FakeFolderPicker('D:/New')),
      ],
      (_) async {
        Future<void> changeTickingOldPc() async {
          await tester.tap(find.text('Change folder…'));
          await tester.pumpAndSettle();
          await tester.tap(
            find.descendant(
              of: find.byType(AlertDialog),
              matching: find.text('OLD-PC'),
            ),
          );
          await tester.pump();
          await tester.tap(find.widgetWithText(FilledButton, 'Change'));
          await settle(tester);
        }

        await openSettings(tester);
        runner.failSetFolder = const RetiredUnreadException({'c'});
        await changeTickingOldPc();
        expect(find.text('Not all changes were read'), findsOneWidget);
        await tester.tap(find.text('Cancel'));
        await settle(tester);
        expect(runner.forces, [false]);
        expect(find.textContaining('Try again later'), findsOneWidget);
        expect(find.text('C:/Old'), findsOneWidget);

        runner.failSetFolder = const RetiredUnreadException({'c'});
        await changeTickingOldPc();
        await tester.tap(find.widgetWithText(FilledButton, 'Change anyway'));
        await settle(tester);
        expect(runner.forces, [false, false, true]);
        expect(runner.retiredSets, [
          {'c'},
        ]);
        expect(find.text('D:/New'), findsOneWidget);
        expect(find.text('Folder connected'), findsOneWidget);
      },
    );
  });

  testWidgets('смена папки «всё равно»: часть правок отмеченного не '
      'прочитана — папка сменена, тост предупреждает и держится дольше', (
    tester,
  ) async {
    final runner = FakeSyncRunner(folder: 'C:/Old')
      ..deviceList = const [
        SyncDevice(nodeId: 'c', name: 'OLD-PC', isThisDevice: false),
      ]
      ..unreadableResult = const {'c'};
    await withApp(
      tester,
      overrides: [
        syncRunnerProvider.overrideWithValue(runner),
        folderPickerProvider.overrideWithValue(FakeFolderPicker('D:/New')),
      ],
      (_) async {
        await openSettings(tester);
        await tester.tap(find.text('Change folder…'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('OLD-PC'),
          ),
        );
        await tester.pump();
        await tester.tap(find.widgetWithText(FilledButton, 'Change'));
        await settle(tester);
        expect(find.text('D:/New'), findsOneWidget);
        expect(find.textContaining('written to it: 1'), findsOneWidget);
        expect(
          find.textContaining('Not all changes were read from devices: 1'),
          findsOneWidget,
        );
        await tester.pump(const Duration(seconds: 9));
        expect(
          find.textContaining('Not all changes were read'),
          findsOneWidget,
          reason: 'предупреждение держится дольше обычного тоста',
        );
      },
    );
  });

  testWidgets('смена папки: переиздавать нечего, часть правок не прочитана — '
      'тост без «записаны: 0»; непрочитанное первым проходом с новой папкой '
      'видно сразу', (tester) async {
    final runner = FakeSyncRunner(folder: 'C:/Old')
      ..deviceList = const [
        SyncDevice(nodeId: 'c', name: 'OLD-PC', isThisDevice: false),
      ]
      ..adoptedResult = const {}
      ..unreadableResult = const {'c'}
      ..issuesResult = 2;
    await withApp(
      tester,
      overrides: [
        syncRunnerProvider.overrideWithValue(runner),
        folderPickerProvider.overrideWithValue(FakeFolderPicker('D:/New')),
      ],
      (_) async {
        await openSettings(tester);
        await tester.tap(find.text('Change folder…'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('OLD-PC'),
          ),
        );
        await tester.pump();
        await tester.tap(find.widgetWithText(FilledButton, 'Change'));
        await settle(tester);
        expect(
          find.textContaining('devices no longer in use: 1'),
          findsOneWidget,
        );
        expect(find.textContaining('written to it'), findsNothing);
        expect(find.textContaining('not read yet: 2'), findsOneWidget);
      },
    );
  });

  testWidgets('смена папки: первый проход с новой папкой не удался — на '
      'экране новая папка и ошибка, тост с итогом переиздания', (tester) async {
    final runner = FakeSyncRunner(folder: 'C:/Old')
      ..deviceList = const [
        SyncDevice(nodeId: 'c', name: 'OLD-PC', isThisDevice: false),
      ]
      ..passErrorResult = const SyncFormatException('v2');
    await withApp(
      tester,
      overrides: [
        syncRunnerProvider.overrideWithValue(runner),
        folderPickerProvider.overrideWithValue(FakeFolderPicker('D:/New')),
      ],
      (_) async {
        await openSettings(tester);
        await tester.tap(find.text('Change folder…'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('OLD-PC'),
          ),
        );
        await tester.pump();
        await tester.tap(find.widgetWithText(FilledButton, 'Change'));
        await settle(tester);
        expect(find.text('D:/New'), findsOneWidget);
        expect(find.textContaining('newer version of the app'), findsOne);
        expect(find.textContaining('written to it: 1'), findsOneWidget);
      },
    );
  });

  testWidgets('смена папки без отметок — правки устройств не переносятся; '
      'прежняя папка недоступна — об этом сказано', (tester) async {
    final runner = FakeSyncRunner(folder: 'C:/Old')
      ..failDevices = const FileSystemException('нет доступа', 'C:/Old');
    await withApp(
      tester,
      overrides: [
        syncRunnerProvider.overrideWithValue(runner),
        folderPickerProvider.overrideWithValue(FakeFolderPicker('D:/New')),
      ],
      (_) async {
        await openSettings(tester);
        await tester.tap(find.text('Change folder…'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining("Couldn't read the devices"),
          findsOneWidget,
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Change'));
        await settle(tester);
        expect(runner.retiredSets, [<String>{}]);
        expect(find.text('Folder connected'), findsOneWidget);
      },
    );
  });

  testWidgets('«Пересобрать базу из журнала» — после подтверждения', (
    tester,
  ) async {
    final runner = FakeSyncRunner();
    await withApp(
      tester,
      overrides: [syncRunnerProvider.overrideWithValue(runner)],
      (_) async {
        await openSettings(tester);
        await tester.tap(find.text('Rebuild database from the log'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Rebuild'));
        await settle(tester);
        expect(runner.rebuilds, 1);
        expect(find.text('Database rebuilt'), findsOneWidget);
      },
    );
  });

  testWidgets('`o` `s` — «Настройки»', (tester) async {
    await withApp(
      tester,
      overrides: [syncRunnerProvider.overrideWithValue(FakeSyncRunner())],
      (_) async {
        await tester.sendKeyEvent(LogicalKeyboardKey.keyO);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
        await settle(tester);
        expect(find.byType(SettingsScreen), findsOneWidget);
      },
    );
  });

  testWidgets('смена папки не удалась → на экране прежняя сохранённая папка '
      'и текст ошибки, без второго тоста', (tester) async {
    final runner = FakeSyncRunner(folder: 'C:/Old')
      ..failSetFolder = const FileSystemException('нет доступа', 'D:/New');
    final picker = FakeFolderPicker('D:/New');
    await withApp(
      tester,
      overrides: [
        syncRunnerProvider.overrideWithValue(runner),
        folderPickerProvider.overrideWithValue(picker),
      ],
      (_) async {
        await openSettings(tester);
        await tester.tap(find.text('Change folder…'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Change'));
        await settle(tester);
        expect(find.text('C:/Old'), findsOneWidget);
        expect(find.text('D:/New'), findsNothing);
        expect(find.textContaining('нет доступа'), findsOneWidget);
        expect(find.byType(SnackBar), findsNothing);
      },
    );
  });

  testWidgets('папка синхронизации пропала — понятный текст, вместо прежнего '
      'списка устройств «не прочитаны»; «Create folder again» — после '
      'подтверждения та же папка выбирается заново', (tester) async {
    final runner = FakeSyncRunner(folder: 'C:/OneDrive')
      ..deviceList = const [
        SyncDevice(nodeId: 'a', name: 'DESKTOP', isThisDevice: true),
        SyncDevice(nodeId: 'b', name: 'LAPTOP', isThisDevice: false),
      ];
    await withApp(
      tester,
      overrides: [syncRunnerProvider.overrideWithValue(runner)],
      (_) async {
        await openSettings(tester);
        expect(find.text('LAPTOP'), findsOneWidget);

        const missing = SyncFolderMissingException('planner-sync/format.json');
        runner
          ..failNext = missing
          ..failDevices = missing;
        await tester.tap(find.text('Sync now'));
        await settle(tester);
        expect(find.textContaining('Sync folder not found'), findsOneWidget);
        expect(find.text('LAPTOP'), findsNothing);
        expect(find.textContaining("Devices couldn't be read"), findsOne);

        await tester.tap(find.text('Create folder again'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel'));
        await settle(tester);
        expect(runner.folders, isEmpty);

        runner.failDevices = null;
        await tester.tap(find.text('Create folder again'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(FilledButton, 'Create folder again'),
        );
        await settle(tester);
        expect(runner.folders, ['C:/OneDrive']);
        expect(find.text('Sync folder reconnected'), findsOneWidget);
        expect(find.textContaining('Sync folder not found'), findsNothing);
        expect(find.text('LAPTOP'), findsOneWidget);
      },
    );
  });

  testWidgets('«Create folder again»: устройства из журнала без имён, по '
      'умолчанию не отмечены; отмеченное переиздаётся, смена «всё равно»', (
    tester,
  ) async {
    final runner = FakeSyncRunner(folder: 'C:/OneDrive')
      ..journalDeviceList = [
        SyncDevice(
          nodeId: '0190aaaa-bbbb-7ccc-8ddd-eeeeee123456',
          isThisDevice: false,
          lastEdit: DateTime.utc(2026, 3, 1, 9),
        ),
      ];
    await withApp(
      tester,
      overrides: [syncRunnerProvider.overrideWithValue(runner)],
      (_) async {
        await openSettings(tester);
        runner.failNext = const SyncFolderMissingException(
          'planner-sync/format.json',
        );
        await tester.tap(find.text('Sync now'));
        await settle(tester);
        await tester.tap(find.text('Create folder again'));
        await tester.pumpAndSettle();
        final dialog = find.byType(AlertDialog);
        expect(
          find.descendant(of: dialog, matching: find.text('Unnamed device')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: dialog, matching: find.textContaining('…123456')),
          findsOneWidget,
        );
        expect(
          tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
          isFalse,
        );
        await tester.tap(
          find.descendant(of: dialog, matching: find.text('Unnamed device')),
        );
        await tester.pump();
        await tester.tap(
          find.widgetWithText(FilledButton, 'Create folder again'),
        );
        await settle(tester);
        expect(runner.retiredSets, [
          {'0190aaaa-bbbb-7ccc-8ddd-eeeeee123456'},
        ]);
        expect(runner.forces, [true]);
        expect(find.textContaining('written to it: 1'), findsOneWidget);
      },
    );
  });

  testWidgets('нет самой выбранной папки (диск, облако не подключены) — свой '
      'текст и без «Create folder again»', (tester) async {
    final runner = FakeSyncRunner(folder: 'D:/OneDrive');
    await withApp(
      tester,
      overrides: [syncRunnerProvider.overrideWithValue(runner)],
      (_) async {
        await openSettings(tester);
        runner.failNext = const SyncFolderMissingException('');
        await tester.tap(find.text('Sync now'));
        await settle(tester);
        expect(
          find.textContaining("The chosen folder wasn't found"),
          findsOneWidget,
        );
        expect(find.text('Create folder again'), findsNothing);
      },
    );
  });

  testWidgets('первый выбор папки не удался — причина видна и без папки', (
    tester,
  ) async {
    final runner = FakeSyncRunner()
      ..failSetFolder = const FileSystemException('нет доступа', 'D:/New');
    await withApp(
      tester,
      overrides: [
        syncRunnerProvider.overrideWithValue(runner),
        folderPickerProvider.overrideWithValue(FakeFolderPicker('D:/New')),
      ],
      (_) async {
        await openSettings(tester);
        await tester.tap(find.text('Choose folder…'));
        await settle(tester);
        expect(find.textContaining('No folder chosen'), findsOneWidget);
        expect(find.textContaining('нет доступа'), findsOneWidget);
      },
    );
  });

  testWidgets('проход пропущен (синхронизацию уже ведёт другой) — понятный '
      'текст, не «успех»', (tester) async {
    final runner = FakeSyncRunner(folder: 'C:/OneDrive');
    await withApp(
      tester,
      overrides: [syncRunnerProvider.overrideWithValue(runner)],
      (_) async {
        await openSettings(tester);
        runner.busyNext = true;
        await tester.tap(find.text('Sync now'));
        await settle(tester);
        expect(find.textContaining('already syncing'), findsOneWidget);
      },
    );
  });

  testWidgets('платформа без выбора папки — пояснение вместо кнопки', (
    tester,
  ) async {
    await withApp(
      tester,
      overrides: [
        syncRunnerProvider.overrideWithValue(FakeSyncRunner()),
        folderPickerProvider.overrideWithValue(
          FakeFolderPicker(null, isSupported: false),
        ),
      ],
      (_) async {
        await openSettings(tester);
        expect(find.text('Choose folder…'), findsNothing);
        expect(find.textContaining('coming later'), findsOneWidget);
      },
    );
  });
}
