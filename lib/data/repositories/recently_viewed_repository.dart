import '../../domain/recently_viewed.dart';
import '../app_database.dart';
import '../local_meta_dao.dart';

/// Хранение «Недавно просмотренного» в `local_meta` одним ключом
/// [LocalMetaDao.recentlyViewedKey] (решение 1А plans/m5 «Решения M5.4»):
/// только на этом устройстве, без синхронизации и без изменения схемы.
base class RecentlyViewedRepository {
  RecentlyViewedRepository(AppDatabase db) : _meta = LocalMetaDao(db);

  final LocalMetaDao _meta;

  /// Список; ключа нет — пустой. Битое значение или другая версия — пустой
  /// список и предупреждение ([LocalMetaDao.readJson]): следующий просмотр
  /// перезапишет ключ.
  Future<RecentlyViewed> load() => _meta.readJson(
    LocalMetaDao.recentlyViewedKey,
    decode: RecentlyViewed.fromJson,
    empty: const RecentlyViewed(),
    failure: 'Недавно просмотренное не разобрано',
  );

  Future<void> save(RecentlyViewed list) =>
      _meta.writeJson(LocalMetaDao.recentlyViewedKey, list.toJson());
}
