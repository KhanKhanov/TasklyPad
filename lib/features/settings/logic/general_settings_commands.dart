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
  Future<void> setSmartDateRecognition(bool enabled) => _mutator.update(
    EntityTypes.settings,
    settingsEntityId,
    {SettingsFields.smartDateRecognition: enabled},
  );
}
