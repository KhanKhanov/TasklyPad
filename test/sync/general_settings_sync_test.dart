import 'package:flutter_test/flutter_test.dart';
import 'package:planner/data/projection/entity_fields.dart';
import 'package:planner/domain/conflicts.dart';
import 'package:planner/features/conflicts/logic/conflict_commands.dart';
import 'package:planner/sync/conflict_repository.dart';
import 'package:planner/sync/io_sync_fs.dart';

import '../features/support/app_commands.dart';
import 'support/devices.dart';

// «Основное» на двух устройствах: «Умное распознавание даты» и «Добавлять
// подзадачи снова» — флаги общей сущности `settings` (SYNC_DESIGN
// «Специальные случаи»), без переключателя «только на этом устройстве», как
// у темы. Сценарии — по «Инвариантам реализации»; неприменимы: правка против
// удаления (у настроек нет удаления), повторяющаяся задача и
// переупорядочивание (нет таких полей).
void main() {
  late TestDevice pc;
  late TestDevice phone;
  late AppCommands onPc;
  late AppCommands onPhone;
  late String folder;

  setUp(() async {
    folder = tempDir('general_settings_sync_').path;
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

  Future<(bool, bool)> flags(AppCommands dev) async => (
    await dev.settings.smartDateRecognition(),
    await dev.settings.resetRecurringSubtasks(),
  );

  ConflictRepository repo(TestDevice dev) => ConflictRepository(
    db: dev.db,
    store: dev.services.store,
    meta: dev.services.meta,
  );

  /// Конфликты устройства: id, поле, решён ли — то, что должно совпасть на
  /// обоих и пережить пересборку.
  Future<List<(String, String, bool)>> conflictsOf(TestDevice dev) async => [
    for (final c in await dev.conflicts()) (c.id, c.field, c.resolved),
  ];

  /// Оба устройства видят одно и то же, и пересборка из журнала этого не
  /// меняет.
  Future<void> expectConverged() async {
    final values = await flags(onPc);
    final conflicts = await conflictsOf(pc);
    expect(await flags(onPhone), values);
    expect(await conflictsOf(phone), conflicts);
    for (final (dev, app) in [(pc, onPc), (phone, onPhone)]) {
      await dev.services.engine.rebuild();
      expect(await flags(app), values, reason: 'после пересборки');
      expect(await conflictsOf(dev), conflicts, reason: 'после пересборки');
    }
  }

  test('последовательная правка — значения сошлись, конфликтов нет', () async {
    await onPc.general.save(smartDateRecognition: false);
    await syncBoth();
    expect(await flags(onPhone), (false, false));

    await onPhone.general.save(resetRecurringSubtasks: true);
    await syncBoth();
    expect(await flags(onPc), (false, true));
    expect(await pc.conflicts(), isEmpty);
    await expectConverged();
  });

  test('параллельная правка разных полей — сохраняются обе', () async {
    await onPc.general.save(smartDateRecognition: false);
    await onPhone.general.save(resetRecurringSubtasks: true);
    await syncBoth();

    expect(await flags(onPc), (false, true));
    expect(await pc.conflicts(), isEmpty);
    expect(await phone.conflicts(), isEmpty);
    await expectConverged();
  });

  for (final (name, field, conflictField, save) in [
    (
      'умное распознавание даты',
      SettingsFields.smartDateRecognition,
      ConflictField.smartDateRecognition,
      (AppCommands dev, bool v) => dev.general.save(smartDateRecognition: v),
    ),
    (
      'сброс подзадач',
      SettingsFields.resetRecurringSubtasks,
      ConflictField.resetRecurringSubtasks,
      (AppCommands dev, bool v) => dev.general.save(resetRecurringSubtasks: v),
    ),
  ]) {
    test('$name: параллельная правка — один конфликт с одним id, карточка '
        '«Настройки»; выбор на телефоне закрывает его на ПК, то же после '
        'пересборки', () async {
      // У флага два значения, а `Mutator` не пишет то, что уже стоит: спор
      // от общего «выключено» — ПК включил, телефон включил и передумал.
      await save(onPc, false);
      await syncBoth();
      await save(onPc, true);
      await save(onPhone, true);
      await save(onPhone, false);
      await syncBoth();

      final conflicts = await pc.conflicts();
      expect([for (final c in conflicts) c.field], [field]);
      expect(
        [for (final c in await phone.conflicts()) c.id],
        [conflicts.single.id],
      );
      await expectConverged();

      // «Синхронизировать тему» выключена — карточка всё равно видна: прячутся
      // только поля темы.
      await onPhone.theme.save(
        (await onPhone.themeRepo.load()).effective,
        syncTheme: false,
      );
      final card = (await repo(phone).load()).single;
      expect(card.entity, ConflictEntity.settings);
      expect(
        {
          for (final side in [card.older, card.newer])
            for (final v in side.values) (v.field, v.key, v.value),
        },
        {(conflictField, field, true), (conflictField, field, false)},
      );

      // Выбирается проигравшая сторона: выбор действующей ничего не пишет, и
      // проверка значения ниже прошла бы сама собой.
      final older = card.older;
      expect((older.isCurrent, card.newer.isCurrent), (false, true));
      await ConflictCommands(
        mutator: phone.services.mutator,
        read: onPhone.read,
      ).keep(card, older);
      await syncBoth();

      final chosen = older.values.single.value! as bool;
      for (final app in [onPc, onPhone]) {
        final (smart, reset) = await flags(app);
        expect(
          field == SettingsFields.smartDateRecognition ? smart : reset,
          chosen,
        );
      }
      for (final dev in [pc, phone]) {
        expect(await repo(dev).load(), isEmpty);
        expect((await dev.conflicts()).single.resolved, isTrue);
      }
      await expectConverged();
      expect(await repo(pc).load(), isEmpty, reason: 'после пересборки');
    });
  }

  test('оба флага одной правкой на обоих — одна карточка с двумя конфликтами, '
      'выбор закрывает оба на обоих, то же после пересборки', () async {
    // «Обновить» на компьютере пишет оба поля одним действием.
    await onPc.general.save(
      smartDateRecognition: false,
      resetRecurringSubtasks: false,
    );
    await syncBoth();
    await onPc.general.save(
      smartDateRecognition: true,
      resetRecurringSubtasks: true,
    );
    await onPhone.general.save(
      smartDateRecognition: true,
      resetRecurringSubtasks: true,
    );
    await onPhone.general.save(
      smartDateRecognition: false,
      resetRecurringSubtasks: false,
    );
    await syncBoth();

    expect(
      {for (final c in await pc.conflicts()) c.field},
      {
        SettingsFields.smartDateRecognition,
        SettingsFields.resetRecurringSubtasks,
      },
    );
    await expectConverged();
    final card = (await repo(pc).load()).single;
    expect(card.conflictIds, hasLength(2));
    expect(
      [for (final v in card.older.values) v.field],
      [
        ConflictField.smartDateRecognition,
        ConflictField.resetRecurringSubtasks,
      ],
      reason: 'порядок — как в «Основном»',
    );

    expect(card.older.isCurrent, isFalse);
    await ConflictCommands(
      mutator: pc.services.mutator,
      read: onPc.read,
    ).keep(card, card.older);
    await syncBoth();

    for (final (dev, app) in [(pc, onPc), (phone, onPhone)]) {
      expect(await flags(app), (true, true));
      expect(await repo(dev).load(), isEmpty);
    }
    await expectConverged();
  });

  test('долгий офлайн телефона и повторная доставка — один спор, повторное '
      'применение ничего не меняет', () async {
    await syncBoth();
    // Месяц: время идёт на обоих, ПК каждый день переключает распознавание
    // дат (выключено в нечётные дни), сброс подзадач включил в первый день.
    for (var day = 0; day < 30; day++) {
      pc.advance(const Duration(days: 1));
      phone.advance(const Duration(days: 1));
      await onPc.general.save(
        smartDateRecognition: day.isEven,
        resetRecurringSubtasks: day == 0 ? true : null,
      );
    }
    // Телефон всё это время не видел правок ПК и выключил распознавание.
    await onPhone.general.save(smartDateRecognition: false);
    await syncBoth();

    // Конфликт — каждая параллельная пара ops с разными значениями (SYNC_DESIGN
    // «Конфликты»): 15 «включено» ПК (чётные дни) против «выключено»
    // телефона; совпадающие «выключено» не спорят. Карточек столько же — О-66.
    final open = await pc.conflicts();
    expect(open, hasLength(15));
    expect(
      {for (final c in open) (c.field, c.resolved)},
      {(SettingsFields.smartDateRecognition, false)},
    );
    expect((await flags(onPhone)).$2, isTrue);
    await expectConverged();

    // Повторная доставка: каждый узел ещё раз применяет все ops другого.
    final values = await flags(onPc);
    final conflicts = await conflictsOf(pc);
    final pcOps = await pc.ownOps();
    final phoneOps = await phone.ownOps();
    await phone.services.engine.applyAll(pcOps);
    await pc.services.engine.applyAll(phoneOps);
    for (final (dev, app) in [(pc, onPc), (phone, onPhone)]) {
      expect(await flags(app), values);
      expect(await conflictsOf(dev), conflicts);
      expect(
        await dev.services.store.opsOfNodeAfter(pc.nodeId, null),
        hasLength(pcOps.length),
      );
      expect(
        await dev.services.store.opsOfNodeAfter(phone.nodeId, null),
        hasLength(phoneOps.length),
      );
    }
    await expectConverged();

    // Выбор на одной карточке закрывает все конфликты поля на обоих.
    final card = (await repo(phone).load()).first;
    await ConflictCommands(
      mutator: phone.services.mutator,
      read: onPhone.read,
    ).keep(card, card.older);
    await syncBoth();
    for (final dev in [pc, phone]) {
      expect(await repo(dev).load(), isEmpty);
      expect({for (final c in await dev.conflicts()) c.resolved}, {true});
    }
    await expectConverged();
  });
}
