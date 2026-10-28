import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/theme_settings.dart';
import '../app_database.dart';
import '../local_meta_dao.dart';
import '../projection/entity_fields.dart';

/// Тема оформления: поля сущности `settings` из `field_versions` (таблицы у
/// неё нет — SYNC_DESIGN «Специальные случаи») и тема устройства из
/// `local_meta`.
final class ThemeSettingsRepository {
  ThemeSettingsRepository(this._db) : _meta = LocalMetaDao(_db);

  final AppDatabase _db;
  final LocalMetaDao _meta;

  /// Настройки сейчас и после каждого их изменения — своего и пришедшего
  /// синхронизацией. `local_meta` меняется при каждой правке (часы движка),
  /// поэтому одинаковые снимки отбрасываются.
  Stream<ThemeSettings> watch() => _db
      .customSelect('SELECT 1', readsFrom: {_db.fieldVersions, _db.localMeta})
      .watch()
      .asyncMap((_) => load())
      .distinct();

  Future<ThemeSettings> load() => _db.transaction(() async {
    final rows =
        await (_db.select(_db.fieldVersions)..where(
              (t) =>
                  t.entityType.equals(EntityTypes.settings) &
                  t.entityId.equals(settingsEntityId),
            ))
            .get();
    final shared = {
      for (final row in rows) row.field: jsonDecode(row.valueJson),
    };
    final themeId = shared[SettingsFields.themeId];
    final localThemeId = await _meta.read(LocalMetaDao.themeIdKey);
    return ThemeSettings(
      syncTheme: await _meta.themeSync(),
      sharedThemeId: themeId is String && themeId.isNotEmpty ? themeId : null,
      sharedAppearance: ThemeAppearance.parse(
        shared[SettingsFields.themeAppearance],
      ),
      localThemeId: localThemeId == null || localThemeId.isEmpty
          ? null
          : localThemeId,
      localAppearance: ThemeAppearance.parse(
        await _meta.read(LocalMetaDao.themeAppearanceKey),
      ),
    );
  });
}
