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
// на диске → другая база; правки — командами фильтров и «Отображения».
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

  test('фильтры, созданные на двух устройствах офлайн, — оба остаются, в '
      'одном порядке на обоих, без конфликтов', () async {
    final first = await onPc.filters.add(name: 'Срочное', query: 'p1');
    final second = await onPhone.filters.add(
      name: 'Сегодня и просрочено',
      query: 'today | overdue',
    );
    await syncBoth();

    // Оба встали в конец пустого списка — с одним ключом; при равенстве
    // ключей порядок — по id, одинаково на обоих устройствах.
    final onPcOrder = [for (final f in (await onPc.read()).filters) f.id];
    expect(onPcOrder.toSet(), {first, second});
    for (final dev in [onPc, onPhone]) {
      final ws = await dev.read();
      expect([for (final f in ws.filters) f.id], onPcOrder);
      expect(ws.filter(second)!.query, 'today | overdue');
      expect(ws.filter(first)!.color, 'charcoal');
    }
    expect(await pc.conflicts(), isEmpty);
    expect(await phone.conflicts(), isEmpty);
    await expectStableAndSame();
  });

  test('запрос одного фильтра правят на двух устройствах офлайн — карточка с '
      'полем «Запрос» и пометка фильтра', () async {
    final filter = await onPc.filters.add(name: 'Срочное', query: 'p1');
    await syncBoth();

    await onPc.filters.edit(filter, query: 'p1 & today');
    await onPhone.filters.edit(filter, query: 'p1 | p2');
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
    final filter = await onPc.filters.add(name: 'Срочное', query: 'p1');
    await syncBoth();

    // ПК ставит избранное и снимает: значение то же, что было, но правка
    // записана, и спорит с правкой телефона (Mutator пишет только изменения).
    // Порядок — прямой записью ключа: перестановка в списке из одного фильтра
    // ничего не пишет.
    await onPc.filters.edit(filter, description: 'утром', isFavorite: true);
    await pc.services.mutator.update(EntityTypes.filter, filter, {
      FilterFields.orderKey: 'b0',
    });
    pc.advance(const Duration(milliseconds: 10));
    await onPc.filters.setFavorite(filter, false);
    await onPhone.filters.edit(
      filter,
      description: 'вечером',
      isFavorite: true,
    );
    await phone.services.mutator.update(EntityTypes.filter, filter, {
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
    final filter = await onPc.filters.add(name: 'Срочное', query: 'p1');
    await syncBoth();

    await onPc.filters.delete(filter);
    await onPhone.filters.edit(filter, name: 'Важное');
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
    const today = ViewOptions(viewType: ViewType.today);
    for (final (dev, query) in [(onPc, 'p1'), (onPhone, '#Работа')]) {
      await dev.views.save(today, today.copyWith(filteredBy: query));
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
