import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/recent_searches.dart';
import '../app_database.dart';
import '../projection/entity_fields.dart';

/// Синхронизируемые настройки задач и быстрого добавления: поля
/// сущности `settings` из `field_versions` (таблицы у неё нет — SYNC_DESIGN
/// «Специальные случаи»). Тема — ThemeSettingsRepository.
final class SettingsRepository {
  SettingsRepository(this._db);

  final AppDatabase _db;

  /// «Сбрасывать подзадачи» повторяющейся задачи; поля нет или оно не
  /// логическое — выключено: help «можно включить» (решение 1А «Ход M3.4»,
  /// проверка на живом Todoist — О-57).
  Future<bool> resetRecurringSubtasks() async =>
      await _bool(SettingsFields.resetRecurringSubtasks) ?? false;

  /// «Умное распознавание дат» быстрого добавления; поля нет или оно не
  /// логическое — включено, как у нового аккаунта Todoist (help «Turn smart
  /// date recognition on or off»).
  Future<bool> smartDateRecognition() async =>
      await _bool(SettingsFields.smartDateRecognition) ?? true;

  /// [smartDateRecognition] сейчас и после каждой правки — своей и пришедшей
  /// синхронизацией; одинаковые значения отбрасываются.
  Stream<bool> watchSmartDateRecognition() => _watch(smartDateRecognition);

  /// [resetRecurringSubtasks] — так же, как [watchSmartDateRecognition].
  Stream<bool> watchResetRecurringSubtasks() => _watch(resetRecurringSubtasks);

  /// Недавние поисковые запросы, новые первыми; поля нет или оно битое —
  /// пусто ([recentSearchesOf]).
  Future<List<String>> recentSearches() async =>
      recentSearchesOf(await _value(SettingsFields.recentSearches));

  /// [recentSearches] сейчас и после каждой правки; одинаковые списки
  /// отбрасываются.
  Stream<List<String>> watchRecentSearches() =>
      _watch(recentSearches, equals: sameRecentSearches);

  Stream<T> _watch<T>(
    Future<T> Function() read, {
    bool Function(T, T)? equals,
  }) => _db
      .customSelect('SELECT 1', readsFrom: {_db.fieldVersions})
      .watch()
      .asyncMap((_) => read())
      .distinct(equals);

  Future<bool?> _bool(String field) async {
    final value = await _value(field);
    return value is bool ? value : null;
  }

  Future<Object?> _value(String field) async {
    final row =
        await (_db.select(_db.fieldVersions)..where(
              (t) =>
                  t.entityType.equals(EntityTypes.settings) &
                  t.entityId.equals(settingsEntityId) &
                  t.field.equals(field),
            ))
            .getSingleOrNull();
    return row == null ? null : jsonDecode(row.valueJson);
  }
}
