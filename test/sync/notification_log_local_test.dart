import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:planner/data/repositories/notification_log_repository.dart';
import 'package:planner/domain/notification_log.dart';
import 'package:planner/sync/io_sync_fs.dart';

import '../features/support/app_commands.dart';
import 'support/devices.dart';

// Журнал «Уведомления» — память устройства, не данные (решение 3А plans/m5
// «Решения M5.3a», SYNC_DESIGN «Специальные случаи»): на другое устройство не
// попадает, в файлах папки его нет, пересборка базы из журнала операций его
// не трогает. Сценарии «Инвариантов реализации» про слияние полей
// неприменимы: журнал не пишется в op-log.
void main() {
  test(
    'журнал A не попадает ни на B, ни в папку; пересборка его не трогает',
    () async {
      final folder = tempDir('notification_log_').path;
      final a = await TestDevice.start(seed: 1);
      final b = await TestDevice.start(seed: 2);
      final onA = AppCommands(a);
      final repoA = NotificationLogRepository(a.db);
      final log = const NotificationLog().add('Секретный тост', 1);
      await repoA.save(log);
      // Обычная правка, чтобы синхронизации было что везти.
      await onA.tasks.add(content: 'Milk');

      for (var round = 0; round < 2; round++) {
        for (final dev in [a, b]) {
          final report = await dev.folder(IoSyncFs(folder)).syncOnce();
          expect(report?.issues, isEmpty);
        }
      }

      expect((await b.aliveTasks()).values, contains('Milk'));
      expect(
        await NotificationLogRepository(b.db).load(),
        const NotificationLog(),
      );
      final texts = [
        for (final file in Directory(folder).listSync(recursive: true))
          if (file is File)
            utf8.decode(file.readAsBytesSync(), allowMalformed: true),
      ];
      // Контроль: файлы папки читаются как текст — задача в них видна.
      expect(texts.any((t) => t.contains('Milk')), isTrue);
      expect(texts.where((t) => t.contains('Секрет')), isEmpty);

      await a.services.engine.rebuild();
      expect(await repoA.load(), log);
    },
  );
}
