import 'package:flutter_test/flutter_test.dart';
import 'package:oplog_sync/oplog_sync.dart';
import 'package:planner/data/local_meta_dao.dart';
import 'package:planner/data/projection/entity_fields.dart';
import 'package:planner/domain/conflicts.dart';
import 'package:planner/domain/theme_settings.dart';
import 'package:planner/features/conflicts/logic/conflict_commands.dart';
import 'package:planner/sync/conflict_repository.dart';
import 'package:planner/sync/io_sync_fs.dart';

import '../features/support/app_commands.dart';
import 'support/devices.dart';

// Тема оформления на двух устройствах (SYNC_DESIGN «Специальные случаи»):
// сущность `settings` без таблицы, тема устройства — в `local_meta`, пока
// «Синхронизировать тему» выключена. Сценарии — по «Инвариантам реализации»;
// неприменимы: правка против удаления (у настроек нет удаления),
// повторяющаяся задача и переупорядочивание (нет таких полей).
void main() {
  late TestDevice pc;
  late TestDevice phone;
  late AppCommands onPc;
  late AppCommands onPhone;
  late String folder;

  const dark = ThemeChoice(themeId: 'taskly', appearance: ThemeAppearance.dark);
  const light = ThemeChoice(
    themeId: 'taskly',
    appearance: ThemeAppearance.light,
  );

  setUp(() async {
    folder = tempDir('settings_sync_').path;
    pc = await TestDevice.start(seed: 1);
    phone = await TestDevice.start(seed: 2);
    onPc = AppCommands(pc);
    onPhone = AppCommands(phone);
  });

  Future<void> syncBoth() async {
    for (var round = 0; round < 2; round++) {
      for (final dev in [pc, phone]) {
        final report = await dev.folder(IoSyncFs(folder)).syncOnce();
        expect(report?.issues, isEmpty);
      }
    }
    pc.advance(const Duration(seconds: 1));
    phone.advance(const Duration(seconds: 2));
  }

  Future<ThemeChoice> effective(AppCommands dev) async =>
      (await dev.themeRepo.load()).effective;

  /// Ops настроек этого устройства (при запуске оно пишет ещё «Входящие»).
  Future<List<Op>> settingsOps(TestDevice dev) async => [
    for (final op in await dev.ownOps())
      if (op.entityType == EntityTypes.settings) op,
  ];

  Future<int> opsCount(TestDevice dev) async => (await settingsOps(dev)).length;

  group('сохранение на одном устройстве', () {
    test('синхронизация включена — пишутся только изменённые поля settings, '
        'повторное сохранение ops не даёт', () async {
      // Тема по умолчанию — Taskly: меняется только внешний вид.
      await onPc.theme.save(dark, syncTheme: true);
      final first = await settingsOps(pc);
      expect(
        {for (final op in first) (op.entityType, op.entityId, op.field)},
        {
          (
            EntityTypes.settings,
            settingsEntityId,
            SettingsFields.themeAppearance,
          ),
        },
      );
      expect(await pc.entity(EntityTypes.settings, settingsEntityId), {
        SettingsFields.themeAppearance: 'dark',
      });

      await onPc.theme.save(light, syncTheme: true);
      final second = (await settingsOps(pc)).skip(first.length).toList();
      expect(
        [for (final op in second) op.field],
        [SettingsFields.themeAppearance],
      );

      await onPc.theme.save(light, syncTheme: true);
      expect(await opsCount(pc), first.length + 1);
      expect(await effective(onPc), light);
    });

    test('синхронизация выключена — ops нет, тема на устройстве', () async {
      await onPc.theme.save(dark, syncTheme: false);
      expect(await settingsOps(pc), isEmpty);
      expect(await effective(onPc), dark);
      final meta = LocalMetaDao(pc.db);
      expect(await meta.read(LocalMetaDao.themeIdKey), 'taskly');
      expect(await meta.read(LocalMetaDao.themeAppearanceKey), 'dark');
      expect(await meta.themeSync(), isFalse);
    });

    test('выключение копирует общую тему на устройство — вид не меняется, '
        'ops нет', () async {
      await onPc.theme.save(dark, syncTheme: true);
      final before = await opsCount(pc);
      final shown = await effective(onPc);
      await onPc.theme.save(shown, syncTheme: false);
      expect(await effective(onPc), dark);
      expect(await opsCount(pc), before);
    });

    test(
      'испорченные значения в журнале и local_meta — как будто их нет',
      () async {
        await pc.services.mutator.update(
          EntityTypes.settings,
          settingsEntityId,
          {SettingsFields.themeId: 42, SettingsFields.themeAppearance: 'sepia'},
        );
        await LocalMetaDao(pc.db).write(LocalMetaDao.themeAppearanceKey, '');
        expect(
          await effective(onPc),
          const ThemeChoice(
            themeId: 'taskly',
            appearance: ThemeAppearance.system,
          ),
        );
      },
    );
  });

  group('два устройства', () {
    test('последовательная правка — тема сошлась, конфликтов нет', () async {
      await onPc.theme.save(dark, syncTheme: true);
      await syncBoth();
      expect(await effective(onPhone), dark);

      await onPhone.theme.save(light, syncTheme: true);
      await syncBoth();
      expect(await effective(onPc), light);
      expect(await pc.conflicts(), isEmpty);
      expect(await phone.conflicts(), isEmpty);
    });

    test('новое устройство (синхронизация по умолчанию включена) показывает '
        'общую тему и ничего не пишет', () async {
      await onPc.theme.save(dark, syncTheme: true);
      await syncBoth();
      expect(await effective(onPhone), dark);
      expect(await settingsOps(phone), isEmpty);
    });

    test('параллельная правка разных полей — сохраняются обе', () async {
      await onPc.theme.save(light, syncTheme: true);
      await syncBoth();

      await onPc.theme.save(dark, syncTheme: true);
      await onPhone.theme.save(
        const ThemeChoice(themeId: 'kale', appearance: ThemeAppearance.light),
        syncTheme: true,
      );
      await syncBoth();

      const both = ThemeChoice(
        themeId: 'kale',
        appearance: ThemeAppearance.dark,
      );
      expect(await effective(onPc), both);
      expect(await effective(onPhone), both);
      expect(await pc.conflicts(), isEmpty);
    });

    test('параллельная правка одного поля — один конфликт на обоих, карточка '
        '«Настройки»; выбор на телефоне закрывает его на ПК', () async {
      await onPc.theme.save(light, syncTheme: true);
      await syncBoth();

      await onPc.theme.save(dark, syncTheme: true);
      await onPhone.theme.save(
        const ThemeChoice(
          themeId: 'taskly',
          appearance: ThemeAppearance.system,
        ),
        syncTheme: true,
      );
      await syncBoth();

      final (a, b) = (await pc.conflicts(), await phone.conflicts());
      expect(a, hasLength(1));
      expect([for (final c in b) c.id], [a.single.id]);
      expect(await effective(onPc), await effective(onPhone));

      ConflictRepository repo(TestDevice dev) => ConflictRepository(
        db: dev.db,
        store: dev.services.store,
        meta: dev.services.meta,
      );
      final card = (await repo(phone).load()).single;
      expect(card.entity, ConflictEntity.settings);
      expect(card.title, isNull);
      expect(
        [for (final v in card.older.values) v.field],
        [ConflictField.appearance],
      );

      final older = card.older;
      await ConflictCommands(
        mutator: phone.services.mutator,
        read: onPhone.read,
      ).keep(card, older);
      await syncBoth();

      final chosen = ThemeAppearance.parse(older.fields.values.single);
      for (final dev in [onPc, onPhone]) {
        expect((await effective(dev)).appearance, chosen);
      }
      expect(await repo(pc).load(), isEmpty);
    });

    test('у телефона синхронизация выключена: правки ПК его не меняют, его '
        'правки не уходят; включение делает его тему общей', () async {
      await onPc.theme.save(light, syncTheme: true);
      await syncBoth();
      await onPhone.theme.save(dark, syncTheme: false);
      final phoneOps = await opsCount(phone);

      await onPc.theme.save(
        const ThemeChoice(
          themeId: 'taskly',
          appearance: ThemeAppearance.system,
        ),
        syncTheme: true,
      );
      await syncBoth();
      expect(await effective(onPhone), dark);
      expect(await opsCount(phone), phoneOps);

      await onPhone.theme.save(await effective(onPhone), syncTheme: true);
      await syncBoth();
      expect(await effective(onPc), dark);
      expect(await effective(onPhone), dark);
      expect(await pc.conflicts(), isEmpty);
    });

    test('долгий офлайн и повторная доставка — сходится, без дублей', () async {
      for (var i = 0; i < 3; i++) {
        await onPc.theme.save(i.isEven ? dark : light, syncTheme: true);
        pc.advance(const Duration(minutes: 5));
      }
      await onPhone.theme.save(
        const ThemeChoice(themeId: 'kale', appearance: ThemeAppearance.dark),
        syncTheme: true,
      );
      await syncBoth();
      await syncBoth();

      expect(await effective(onPc), await effective(onPhone));
      final rows = await (pc.db.select(
        pc.db.fieldVersions,
      )..where((t) => t.entityType.equals(EntityTypes.settings))).get();
      expect(rows, hasLength(2));
    });

    test('устройство ещё не получило общую тему и меняет одно поле — другое '
        'не затирает умолчанием, конфликта нет', () async {
      await onPc.theme.save(dark, syncTheme: true);
      await onPhone.theme.save(
        const ThemeChoice(themeId: 'kale', appearance: ThemeAppearance.system),
        syncTheme: true,
      );
      expect(
        [for (final op in await settingsOps(phone)) op.field],
        [SettingsFields.themeId],
      );
      await syncBoth();

      const both = ThemeChoice(
        themeId: 'kale',
        appearance: ThemeAppearance.dark,
      );
      expect(await effective(onPc), both);
      expect(await effective(onPhone), both);
      expect(await pc.conflicts(), isEmpty);
    });

    test('незнакомый внешний вид от более новой версии переживает смену '
        'темы', () async {
      await pc.services.mutator.update(EntityTypes.settings, settingsEntityId, {
        SettingsFields.themeAppearance: 'sepia',
      });
      await onPc.theme.save(
        const ThemeChoice(themeId: 'kale', appearance: ThemeAppearance.system),
        syncTheme: true,
      );
      expect(await pc.entity(EntityTypes.settings, settingsEntityId), {
        SettingsFields.themeAppearance: 'sepia',
        SettingsFields.themeId: 'kale',
      });
    });

    test('пересборка из журнала не меняет тему', () async {
      await onPc.theme.save(dark, syncTheme: true);
      await onPhone.theme.save(
        const ThemeChoice(themeId: 'kale', appearance: ThemeAppearance.light),
        syncTheme: true,
      );
      await syncBoth();
      final before = await onPhone.themeRepo.load();
      await phone.services.engine.rebuild();
      expect(await onPhone.themeRepo.load(), before);
    });
  });
}
