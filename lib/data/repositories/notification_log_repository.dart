import 'dart:convert';

import 'package:logger/logger.dart';

import '../../domain/notification_log.dart';
import '../app_database.dart';
import '../local_meta_dao.dart';

/// Хранение журнала «Уведомления» в `local_meta` одним ключом
/// [LocalMetaDao.notificationLogKey] (решение 3А plans/m5 «Решения M5.3a»):
/// только на этом устройстве, без синхронизации и без изменения схемы.
base class NotificationLogRepository {
  NotificationLogRepository(AppDatabase db) : _meta = LocalMetaDao(db);

  final LocalMetaDao _meta;

  static final Logger _log = Logger();

  /// Журнал; ключа нет — пустой. Битое значение или другая версия — пустой
  /// журнал и предупреждение: из-за журнала не должен падать запуск, а
  /// следующая запись перезапишет ключ.
  Future<NotificationLog> load() async {
    final json = await _meta.read(LocalMetaDao.notificationLogKey);
    if (json == null) return const NotificationLog();
    try {
      return NotificationLog.fromJson(jsonDecode(json) as Map<String, Object?>);
    } on Object catch (error) {
      _log.w('Журнал уведомлений не разобран', error: error);
      return const NotificationLog();
    }
  }

  Future<void> save(NotificationLog log) =>
      _meta.write(LocalMetaDao.notificationLogKey, jsonEncode(log.toJson()));
}
