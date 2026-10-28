import '../../../data/local_meta_dao.dart';
import '../../../data/projection/entity_fields.dart';
import '../../../domain/theme_settings.dart';
import '../../../sync/mutator.dart';

/// Тема и переключатель, от которых пользователь начал правку.
typedef ThemeBase = ({ThemeChoice choice, bool syncTheme});

/// Сохранение раздела «Тема» (SYNC_DESIGN «Специальные случаи»). Вид не
/// меняется скачком: при выключении сюда приходит действующая общая тема и
/// остаётся на устройстве, при включении тема устройства становится общей.
final class ThemeCommands {
  ThemeCommands({
    required this._mutator,
    required this._meta,
    required this._read,
  });

  final Mutator _mutator;
  final LocalMetaDao _meta;
  final Future<ThemeSettings> Function() _read;

  /// Сохранить [choice] и переключатель [syncTheme] одной транзакцией: сбой
  /// не оставит синхронизацию включённой без записанной темы.
  ///
  /// [from] — что пользователь видел, когда начал правку (по умолчанию —
  /// сохранённое сейчас). В общую сущность пишутся только поля, которые он
  /// изменил: иначе устройство, ещё не получившее общую тему, затёрло бы её
  /// своими умолчаниями, а незнакомое значение от более новой версии
  /// заменилось бы запасным. Оба поля пишутся только при включении
  /// синхронизации.
  Future<void> save(
    ThemeChoice choice, {
    required bool syncTheme,
    ThemeBase? from,
  }) => _mutator.batch(() async {
    final base = from ?? await _base();
    if (syncTheme) {
      final enabling = !base.syncTheme;
      final fields = {
        if (enabling || choice.themeId != base.choice.themeId)
          SettingsFields.themeId: choice.themeId,
        if (enabling || choice.appearance != base.choice.appearance)
          SettingsFields.themeAppearance: choice.appearance.name,
      };
      // Пустая правка — без `Mutator.update`: он будит синхронизацию.
      if (fields.isNotEmpty) {
        await _mutator.update(EntityTypes.settings, settingsEntityId, fields);
      }
    } else {
      await _meta.setLocalTheme(choice.themeId, choice.appearance.name);
    }
    await _meta.setThemeSync(syncTheme);
  });

  Future<ThemeBase> _base() async {
    final saved = await _read();
    return (choice: saved.effective, syncTheme: saved.syncTheme);
  }
}
