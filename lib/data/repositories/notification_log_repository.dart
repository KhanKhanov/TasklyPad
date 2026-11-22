import '../../domain/notification_log.dart';
import '../app_database.dart';
import '../local_meta_dao.dart';

/// Хранение журнала «Уведомления» в `local_meta` одним ключом
/// [LocalMetaDao.notificationLogKey] (решение 3А plans/m5 «Решения M5.3a»):
/// только на этом устройстве, без синхронизации и без изменения схемы.
base class NotificationLogRepository {
  NotificationLogRepository(AppDatabase db) : _meta = LocalMetaDao(db);

  final LocalMetaDao _meta;

  /// Журнал; ключа нет — пустой. Битое значение или другая версия — пустой
  /// журнал и предупреждение ([LocalMetaDao.readJson]): из-за журнала не
  /// должен падать запуск, а следующая запись перезапишет ключ.
  Future<NotificationLog> load() => _meta.readJson(
    LocalMetaDao.notificationLogKey,
    decode: (json) => NotificationLog.fromJson(json as Map<String, Object?>),
    empty: const NotificationLog(),
    failure: 'Журнал уведомлений не разобран',
  );

  Future<void> save(NotificationLog log) =>
      _meta.writeJson(LocalMetaDao.notificationLogKey, log.toJson());
}
