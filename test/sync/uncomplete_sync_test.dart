import 'package:flutter_test/flutter_test.dart';
import 'package:planner/data/projection/entity_fields.dart';
import 'package:planner/domain/conflicts.dart';
import 'package:planner/sync/conflict_repository.dart';
import 'package:planner/sync/io_sync_fs.dart';

import '../data/support/drift_probe.dart';
import '../features/support/app_commands.dart';
import 'support/devices.dart';

// Возврат задачи в работу на прежнее место (решение 4А «M4.10a» plans/m4) на
// двух устройствах: ключ порядка не пишется, а совпавший с соседским ключ
// разводится только у возвращённой задачи. Порядок одинаковый, карточек нет,
// пересборка из журнала ничего не меняет.
void main() {
  late TestDevice pc;
  late TestDevice phone;
  late AppCommands onPc;
  late AppCommands onPhone;
  late String folder;

  setUp(() async {
    folder = tempDir('uncomplete_sync_').path;
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

  Future<List<String>> inbox(AppCommands app) async {
    final ws = await app.read();
    return [
      for (final item in ws.projectView(inboxProjectId).unsectioned)
        item.value.content,
    ];
  }

  Future<List<ConflictCard>> cards(TestDevice dev) => ConflictRepository(
    db: dev.db,
    store: dev.services.store,
    meta: dev.services.meta,
  ).load();

  Future<void> expectSameAndStable() async {
    expect(await inbox(onPhone), await inbox(onPc));
    expect(await cards(pc), isEmpty);
    expect(await cards(phone), isEmpty);
    for (final dev in [pc, phone]) {
      final before = await dumpSyncedState(dev.db);
      await dev.services.engine.rebuild();
      expect(await dumpSyncedState(dev.db), before, reason: dev.nodeId);
    }
  }

  test('возврат на ПК и параллельная вставка на то же место на телефоне → '
      'порядок одинаковый, карточки нет', () async {
    final a = await onPc.tasks.add(content: 'a');
    final b = await onPc.tasks.add(content: 'b');
    await onPc.tasks.add(content: 'c');
    await onPc.tasks.complete(b);
    await syncBoth();

    // Телефон вставляет после «a» — туда, где стоит выполненная «b».
    await onPhone.tasks.add(content: 'x', afterId: a);
    await onPc.tasks.uncomplete(b);
    await syncBoth();

    final order = await inbox(onPc);
    expect(order.first, 'a');
    expect(order.last, 'c');
    expect(order.sublist(1, 3).toSet(), {'b', 'x'});
    await expectSameAndStable();
  });

  test('ключ «b» занят вставкой с телефона → у «b» новый ключ, у соседей '
      'ключи прежние', () async {
    final a = await onPc.tasks.add(content: 'a');
    final b = await onPc.tasks.add(content: 'b');
    await onPc.tasks.add(content: 'c');
    await onPc.tasks.complete(b);
    await syncBoth();
    final x = await onPhone.tasks.add(content: 'x', afterId: a);
    final key = (await onPhone.read()).task(b)!.orderKey;
    // Тот же ключ — как если бы два устройства выбрали одно место офлайн.
    await phone.services.mutator.update(EntityTypes.task, x, {
      TaskFields.orderKey: key,
    });
    await syncBoth();

    await onPc.tasks.uncomplete(b);
    await syncBoth();
    final ws = await onPc.read();
    expect(ws.task(b)!.orderKey, isNot(key));
    expect(ws.task(x)!.orderKey, key);
    await expectSameAndStable();
  });
}
