import 'package:flutter_test/flutter_test.dart';
import 'package:planner/data/projection/entity_fields.dart';
import 'package:planner/sync/conflict_repository.dart';
import 'package:planner/sync/io_sync_fs.dart';

import '../features/support/app_commands.dart';
import 'support/devices.dart';

// Недавние поисковые запросы на двух устройствах — поле `recent_searches`
// общей сущности `settings` (решения 5А, 4А plans/m5): синхронизируются,
// параллельные добавления сводит LWW без карточки — слово, введённое в то же
// время на другом устройстве, может потеряться. Сценарии — по «Инвариантам
// реализации»; неприменимы: правка против удаления (у настроек нет удаления),
// повторяющаяся задача и порядок (поле — один список, порядок внутри него
// пишет сам список).
void main() {
  late TestDevice pc;
  late TestDevice phone;
  late AppCommands onPc;
  late AppCommands onPhone;
  late String folder;

  setUp(() async {
    folder = tempDir('recent_searches_sync_').path;
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

  Future<List<String>> recent(AppCommands dev) => dev.settings.recentSearches();

  ConflictRepository cards(TestDevice dev) => ConflictRepository(
    db: dev.db,
    store: dev.services.store,
    meta: dev.services.meta,
  );

  /// Оба устройства видят один список, карточек нет; пересборка из журнала
  /// этого не меняет.
  Future<void> expectConverged() async {
    final list = await recent(onPc);
    expect(await recent(onPhone), list);
    for (final (dev, app) in [(pc, onPc), (phone, onPhone)]) {
      expect(await cards(dev).load(), isEmpty);
      await dev.services.engine.rebuild();
      expect(await recent(app), list, reason: 'после пересборки');
      expect(await cards(dev).load(), isEmpty, reason: 'после пересборки');
    }
  }

  test(
    'поиски на ПК, затем на телефоне — общий список, новые первыми',
    () async {
      await onPc.recentSearches.add('отчёт');
      await syncBoth();
      await onPhone.recentSearches.add('молоко');
      await syncBoth();
      expect(await recent(onPc), ['молоко', 'отчёт']);
      await expectConverged();
    },
  );

  test('параллельные поиски — LWW: оба устройства сошлись на одном списке, '
      'конфликта и карточки нет', () async {
    await onPc.recentSearches.add('общее');
    await syncBoth();
    await onPc.recentSearches.add('с ПК');
    await onPhone.recentSearches.add('с телефона');
    await syncBoth();

    final list = await recent(onPc);
    expect(list, hasLength(2));
    expect(list.first, isIn(['с ПК', 'с телефона']));
    expect(list.last, 'общее');
    expect(await pc.conflicts(), isEmpty);
    expect(await phone.conflicts(), isEmpty);
    await expectConverged();
  });

  test('«Удалить» на одном устройстве очищает список на другом; крестик '
      'убирает один запрос', () async {
    for (final w in ['a', 'b', 'c']) {
      await onPc.recentSearches.add(w);
    }
    await syncBoth();
    await onPhone.recentSearches.remove('b');
    await syncBoth();
    expect(await recent(onPc), ['c', 'a']);

    await onPhone.recentSearches.clear();
    await syncBoth();
    expect(await recent(onPc), isEmpty);
    await expectConverged();
  });

  test(
    'повтор верхнего запроса и «Удалить» пустого списка ops не пишут',
    () async {
      await onPc.recentSearches.add('отчёт');
      final before = (await pc.ownOps()).length;
      final phoneBefore = (await phone.ownOps()).length;
      await onPc.recentSearches.add(' отчёт ');
      await onPc.recentSearches.add('ОТЧЁТ');
      await onPhone.recentSearches.clear();
      // Новое написание того же запроса — другое значение, одна op.
      expect((await pc.ownOps()).length, before + 1);
      expect((await phone.ownOps()).length, phoneBefore);
    },
  );

  test('два поиска подряд без ожидания — оба в списке', () async {
    await Future.wait([
      onPc.recentSearches.add('первый'),
      onPc.recentSearches.add('второй'),
    ]);
    expect(await recent(onPc), ['второй', 'первый']);
  });

  test('повторная доставка и долгий офлайн — тот же результат', () async {
    await onPc.recentSearches.add('до');
    await syncBoth();
    // Месяц: время идёт на обоих, ПК ищет каждый день; телефон всё это время
    // не видел правок ПК и ищет своё.
    for (var day = 0; day < 30; day++) {
      pc.advance(const Duration(days: 1));
      phone.advance(const Duration(days: 1));
      await onPc.recentSearches.add('пк$day');
    }
    await onPhone.recentSearches.add('офлайн');
    await syncBoth();
    // LWW целиком: правка телефона позже — его список побеждает, поиски ПК за
    // месяц теряются (цена решения 4А: недавние поиски — не данные).
    expect(await recent(onPc), ['офлайн', 'до']);
    expect(await pc.conflicts(), isEmpty);
    await expectConverged();

    // Повторная доставка: каждый узел ещё раз применяет все ops другого.
    final list = await recent(onPc);
    final pcOps = await pc.ownOps();
    final phoneOps = await phone.ownOps();
    await phone.services.engine.applyAll(pcOps);
    await pc.services.engine.applyAll(phoneOps);
    expect(await recent(onPc), list);
    expect(await recent(onPhone), list);
    await expectConverged();
  });

  test('значение не списком (с другой версии приложения) читается пустым, '
      'следующий поиск его заменяет', () async {
    await pc.services.mutator.update(EntityTypes.settings, settingsEntityId, {
      SettingsFields.recentSearches: 'не список',
    });
    await syncBoth();
    expect(await recent(onPhone), isEmpty);
    await onPhone.recentSearches.add('отчёт');
    await syncBoth();
    expect(await recent(onPc), ['отчёт']);
    await expectConverged();
  });
}
