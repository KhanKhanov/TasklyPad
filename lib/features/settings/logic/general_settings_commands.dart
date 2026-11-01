import '../../../data/projection/entity_fields.dart';
import '../../../sync/mutator.dart';

/// Сохранение раздела «Основное»: поля общей сущности `settings`
/// синхронизируются между устройствами (SYNC_DESIGN «Специальные случаи»).
final class GeneralSettingsCommands {
  GeneralSettingsCommands({required this._mutator});

  final Mutator _mutator;

  /// «Умное распознавание дат»: выключено — срок в названии не ищется, его
  /// ставит только планировщик (help «Turn smart date recognition on or
  /// off»).
  Future<void> setSmartDateRecognition(bool enabled) =>
      save(smartDateRecognition: enabled);

  /// «Добавлять подзадачи снова»: выполнение повторяющейся задачи
  /// возвращает её выполненные подзадачи в работу (help «Reset a sub-task»).
  Future<void> setResetRecurringSubtasks(bool enabled) =>
      save(resetRecurringSubtasks: enabled);

  /// Изменённые настройки раздела одной правкой — «Обновить» на компьютере.
  /// Пишутся только переданные поля.
  Future<void> save({
    bool? smartDateRecognition,
    bool? resetRecurringSubtasks,
  }) async {
    final fields = {
      SettingsFields.smartDateRecognition: ?smartDateRecognition,
      SettingsFields.resetRecurringSubtasks: ?resetRecurringSubtasks,
    };
    if (fields.isEmpty) return;
    await _mutator.update(EntityTypes.settings, settingsEntityId, fields);
  }
}
