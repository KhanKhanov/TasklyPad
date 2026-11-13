import 'package:flutter_test/flutter_test.dart';
import 'package:planner/data/projection/entity_fields.dart';
import 'package:planner/data/repositories/view_options_repository.dart';
import 'package:planner/domain/conflicts.dart';
import 'package:planner/domain/view_options.dart';
import 'package:planner/features/conflicts/state/conflict_marks.dart';
import 'package:planner/sync/conflict_repository.dart';
import 'package:planner/sync/io_sync_fs.dart';

import '../data/support/drift_probe.dart';
import '../features/support/app_commands.dart';
import 'support/devices.dart';

// Фильтры схемы v6 (решения 2А–4А docs/plans/m5-filters-search.md) на двух
// устройствах тем же путём, что в приложении: Mutator → журнал drift → папка
// на диске → другая база. Команд фильтров ещё нет (коммит 2 M5.2) — правки
// пишутся через Mutator, как их будут писать команды.
void main() {
  late TestDevice pc;
  late TestDevice phone;
  late AppCommands onPc;
  late AppCommands onPhone;
  late String folder;

  setUp(() async {
    folder = tempDir('m5_filters_').path;
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

  /// Пересборка из журнала не меняет базу ни на одном устройстве, и базы
  /// устройств совпадают.
  Future<void> expectStableAndSame() async {
    final states = <Map<String, Object?>>[];
    for (final dev in [pc, phone]) {
      final before = await dumpSyncedState(dev.db);
      await dev.services.engine.rebuild();
      expect(await dumpSyncedState(dev.db), before, reason: dev.nodeId);
      states.add(before);
    }
    expect(states[1], states[0]);
  }

  Future<List<ConflictCard>> cards(TestDevice dev) => ConflictRepository(
    db: dev.db,
    store: dev.services.store,
    meta: dev.services.meta,
  ).load();

  /// Новый фильтр на [dev] — все поля одной правкой, как создание метки.
  Future<String> addFilter(
    TestDevice dev, {
    required String name,
    required String query,
    String orderKey = 'a0',
  }) => dev.services.mutator.create(EntityTypes.filter, {
    FilterFields.name: name,
    FilterFields.query: query,
    FilterFields.orderKey: orderKey,
  });

  Future<void> edit(TestDevice dev, String id, Map<String, Object?> fields) =>
      dev.services.mutator.update(EntityTypes.filter, id, fields);

  test('фильтры, созданные на двух устройствах офлайн, — оба остаются, по '
      'порядку, без конфликтов', () async {
    final first = await addFilter(pc, name: 'Срочное', query: 'p1');
    final second = await addFilter(
      phone,
      name: 'Сегодня и просрочено',
      query: 'today | overdue',
      orderKey: 'a1',
    );
    await syncBoth();

    for (final dev in [onPc, onPhone]) {
      final ws = await dev.read();
      expect(ws.filters.map((f) => f.id), [first, second]);
      expect(ws.filter(second)!.query, 'today | overdue');
      expect(ws.filter(first)!.color, 'charcoal');
    }
    expect(await pc.conflicts(), isEmpty);
    expect(await phone.conflicts(), isEmpty);
    await expectStableAndSame();
  });

  test('запрос одного фильтра правят на двух устройствах офлайн — карточка с '
      'полем «Запрос» и пометка фильтра', () async {
    final filter = await addFilter(pc, name: 'Срочное', query: 'p1');
    await syncBoth();

    await edit(pc, filter, {FilterFields.query: 'p1 & today'});
    await edit(phone, filter, {FilterFields.query: 'p1 | p2'});
    await syncBoth();

    final onPcConflicts = await pc.conflicts();
    expect(onPcConflicts.single.field, FilterFields.query);
    expect((await phone.conflicts()).map((c) => c.id), [
      onPcConflicts.single.id,
    ]);
    final card = (await cards(phone)).single;
    expect((card.entity, card.title), (ConflictEntity.filter, 'Срочное'));
    expect(card.newer.values.single.field, ConflictField.query);
    expect(ConflictMarks.of([card]).has(ConflictEntity.filter, filter), isTrue);

    await phone.services.mutator.resolveConflict(onPcConflicts.single.id, {
      FilterFields.query: 'p1 & today',
    });
    await syncBoth();
    for (final dev in [onPc, onPhone]) {
      expect((await dev.read()).filter(filter)!.query, 'p1 & today');
    }
    expect(await cards(pc), isEmpty);
    await expectStableAndSame();
  });

  test('описание и избранное фильтра правят на двух устройствах офлайн — '
      'карточка без пометки; порядок — молча', () async {
    final filter = await addFilter(pc, name: 'Срочное', query: 'p1');
    await syncBoth();

    // ПК ставит избранное и снимает: значение то же, что было, но правка
    // записана, и спорит с правкой телефона (Mutator пишет только изменения).
    await edit(pc, filter, {
      FilterFields.description: 'утром',
      FilterFields.isFavorite: true,
      FilterFields.orderKey: 'b0',
    });
    pc.advance(const Duration(milliseconds: 10));
    await edit(pc, filter, {FilterFields.isFavorite: false});
    await edit(phone, filter, {
      FilterFields.description: 'вечером',
      FilterFields.isFavorite: true,
      FilterFields.orderKey: 'c0',
    });
    await syncBoth();

    final card = (await cards(pc)).single;
    expect(card.entity, ConflictEntity.filter);
    expect(
      {for (final v in card.newer.values) v.field},
      {ConflictField.description, ConflictField.favorite},
    );
    expect(
      ConflictMarks.of([card]).has(ConflictEntity.filter, filter),
      isFalse,
    );
    // Поздняя правка — телефона: LWW держит её значения до выбора.
    for (final dev in [onPc, onPhone]) {
      final saved = (await dev.read()).filter(filter)!;
      expect(
        (saved.description, saved.isFavorite, saved.orderKey),
        ('вечером', true, 'c0'),
      );
    }
    await expectStableAndSame();
  });

  test('фильтр удалён на ПК, его имя изменено на телефоне — карточка '
      '«удалено / изменено» без пометки', () async {
    final filter = await addFilter(pc, name: 'Срочное', query: 'p1');
    await syncBoth();

    await pc.services.mutator.delete(EntityTypes.filter, filter);
    await edit(phone, filter, {FilterFields.name: 'Важное'});
    await syncBoth();

    final card = (await cards(pc)).single;
    expect((card.entity, card.isDelete), (ConflictEntity.filter, true));
    expect(
      ConflictMarks.of([card]).has(ConflictEntity.filter, filter),
      isFalse,
    );
    expect((await phone.conflicts()).map((c) => c.id), [
      (await pc.conflicts()).single.id,
    ]);
    await expectStableAndSame();
  });

  test('фильтр «Отображения» одного вида правят на двух устройствах офлайн — '
      'побеждает поздняя правка, карточки нет', () async {
    final id = viewOptionsId(ViewType.today.apiName, null);
    for (final (dev, query) in [(pc, 'p1'), (phone, '#Работа')]) {
      await dev.services.mutator.update(EntityTypes.viewOptions, id, {
        ViewOptionsFields.viewType: ViewType.today.apiName,
        ViewOptionsFields.filteredBy: query,
      });
    }
    await syncBoth();

    for (final dev in [pc, phone]) {
      final options = await ViewOptionsRepository(dev.db).load(ViewType.today);
      expect(options.filteredBy, '#Работа');
      expect(await dev.conflicts(), isEmpty);
    }
    await expectStableAndSame();
  });
}
