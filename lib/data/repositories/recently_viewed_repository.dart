import 'dart:convert';

import 'package:logger/logger.dart';

import '../../domain/recently_viewed.dart';
import '../app_database.dart';
import '../local_meta_dao.dart';

/// Хранение «Недавно просмотренного» в `local_meta` одним ключом
/// [LocalMetaDao.recentlyViewedKey] (решение 1А plans/m5 «Решения M5.4»):
/// только на этом устройстве, без синхронизации и без изменения схемы.
base class RecentlyViewedRepository {
  RecentlyViewedRepository(AppDatabase db) : _meta = LocalMetaDao(db);

  final LocalMetaDao _meta;

  static final Logger _log = Logger();

  /// Список; ключа нет — пустой. Битое значение или другая версия — пустой
  /// список и предупреждение: следующий просмотр перезапишет ключ.
  Future<RecentlyViewed> load() async {
    final json = await _meta.read(LocalMetaDao.recentlyViewedKey);
    if (json == null) return const RecentlyViewed();
    try {
      return RecentlyViewed.fromJson(jsonDecode(json));
    } on Object catch (error) {
      _log.w('Недавно просмотренное не разобрано', error: error);
      return const RecentlyViewed();
    }
  }

  Future<void> save(RecentlyViewed list) =>
      _meta.write(LocalMetaDao.recentlyViewedKey, jsonEncode(list.toJson()));
}
