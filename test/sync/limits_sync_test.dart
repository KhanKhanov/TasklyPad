import 'package:flutter_test/flutter_test.dart';
import 'package:planner/domain/rules.dart';
import 'package:planner/sync/io_sync_fs.dart';

import '../data/support/drift_probe.dart';
import '../features/support/app_commands.dart';
import 'support/devices.dart';

// Лимиты на двух устройствах (решение 14А plans/m4): каждое проверяет только
// свои записи, а пришедшее с другого устройства сверх лимита показывается как
// есть, без конфликтов; новая запись сверх лимита отклоняется на обоих — и
// после пересборки из журнала.
Matcher _rejected(RejectReason reason) =>
    throwsA(isA<CommandRejected>().having((e) => e.reason, 'reason', reason));

void main() {
  late TestDevice pc;
  late TestDevice phone;
  late AppCommands onPc;
  late AppCommands onPhone;
  late String folder;

  setUp(() async {
    folder = tempDir('limits_sync_').path;
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

  /// Повторная доставка и пересборка из журнала ничего не меняют, базы
  /// устройств совпадают.
  Future<void> rebuildBoth() async {
    final states = <Map<String, Object?>>[];
    for (final dev in [pc, phone]) {
      final before = await dumpSyncedState(dev.db);
      await dev.folder(IoSyncFs(folder)).syncOnce();
      await dev.services.engine.rebuild();
      expect(await dumpSyncedState(dev.db), before, reason: dev.nodeId);
      states.add(before);
    }
    expect(states[1]['field_versions'], states[0]['field_versions']);
    expect(states[1]['sections'], states[0]['sections']);
    expect(states[1]['task_labels'], states[0]['task_labels']);
  }

  /// [action] отклонено с [reason], и ни одной новой op на [dev].
  Future<void> rejectsWithoutOps(
    TestDevice dev,
    Future<Object?> Function() action,
    RejectReason reason,
  ) async {
    final before = (await dev.ownOps()).length;
    await expectLater(action(), _rejected(reason));
    expect((await dev.ownOps()).length, before);
  }

  test('по 11 разделов офлайн на двух устройствах — видны все 22, конфликтов '
      'нет; 23-й отклонён на обоих, и после пересборки', () async {
    final project = await onPc.projects.add(name: 'Работа');
    await syncBoth();

    for (var i = 0; i < 11; i++) {
      await onPc.sections.add(project, name: 'ПК $i');
      await onPhone.sections.add(project, name: 'Телефон $i');
    }
    await syncBoth();

    Future<void> check() async {
      for (final (dev, app) in [(pc, onPc), (phone, onPhone)]) {
        expect((await app.read()).sectionsOf(project), hasLength(22));
        expect(await dev.conflicts(), isEmpty);
        await rejectsWithoutOps(
          dev,
          () => app.sections.add(project, name: 'Ещё'),
          RejectReason.tooManySections,
        );
      }
    }

    await check();
    await rebuildBoth();
    await check();
  });

  test('по 60 меток на одну задачу офлайн — видны все 120, конфликтов нет; '
      'ещё одна отклонена на обоих, снять можно, и после пересборки', () async {
    final task = await onPc.tasks.add(content: 'Задача');
    await syncBoth();

    for (final (prefix, app) in [('пк', onPc), ('тел', onPhone)]) {
      final ids = <String>{};
      for (var i = 0; i < 60; i++) {
        ids.add(await app.labels.add(name: '$prefix$i'));
      }
      await app.tasks.setLabels(task, ids);
    }
    await syncBoth();

    Future<void> check() async {
      for (final (dev, app) in [(pc, onPc), (phone, onPhone)]) {
        final ws = await app.read();
        final labels = ws.task(task)!.labelIds.toSet();
        expect(labels, hasLength(120));
        expect(await dev.conflicts(), isEmpty);
        final extra = ws.labels.firstWhere((l) => !labels.contains(l.id));
        await rejectsWithoutOps(
          dev,
          () => app.tasks.setLabels(task, {...labels, extra.id}),
          RejectReason.tooManyLabels,
        );
        await rejectsWithoutOps(
          dev,
          () => app.bulk.addLabels([task], {extra.id}),
          RejectReason.tooManyLabels,
        );
      }
    }

    // Метка, которой нет на задаче, — её и пытаются добавить.
    await onPc.labels.add(name: 'лишняя');
    await syncBoth();
    await check();
    await rebuildBoth();
    await check();

    // Снимать метки с задачи сверх лимита можно: 120 → 119.
    final ws = await onPhone.read();
    final labels = ws.task(task)!.labelIds;
    await onPhone.tasks.setLabels(task, labels.skip(1).toSet());
    await syncBoth();
    expect((await onPc.read()).task(task)!.labelIds, hasLength(119));
    await rebuildBoth();
  });
}
