import 'package:freezed_annotation/freezed_annotation.dart';

part 'theme_settings.freezed.dart';

// Тема оформления: общая (сущность `settings`) и своя на устройстве
// (`local_meta`). Где что хранится — SYNC_DESIGN «Специальные случаи».

/// Внешний вид: всегда светлый, всегда тёмный или как в системе.
enum ThemeAppearance {
  light,
  dark,
  system;

  /// Значение из журнала или `local_meta`; незнакомое (от более новой версии,
  /// испорченное) — `null`, как будто его нет.
  static ThemeAppearance? parse(Object? raw) {
    for (final value in values) {
      if (value.name == raw) return value;
    }
    return null;
  }
}

/// Тема без выбора пользователя.
const String defaultThemeId = 'taskly';

/// Выбранная тема и внешний вид.
@freezed
abstract class ThemeChoice with _$ThemeChoice {
  const factory ThemeChoice({
    required String themeId,
    required ThemeAppearance appearance,
  }) = _ThemeChoice;
}

/// Всё, из чего складывается тема на этом устройстве.
@freezed
abstract class ThemeSettings with _$ThemeSettings {
  const factory ThemeSettings({
    /// «Синхронизировать тему» на этом устройстве.
    @Default(true) bool syncTheme,

    /// Общая тема — поля сущности `settings`; `null` — поля нет.
    String? sharedThemeId,
    ThemeAppearance? sharedAppearance,

    /// Тема устройства из `local_meta`; `null` — не выбиралась.
    String? localThemeId,
    ThemeAppearance? localAppearance,
  }) = _ThemeSettings;

  const ThemeSettings._();

  /// Действующая тема — по каждому полю отдельно: общая (если синхронизация
  /// включена), иначе своя, иначе Taskly и «как в системе».
  ThemeChoice get effective => ThemeChoice(
    themeId:
        (syncTheme ? sharedThemeId : null) ?? localThemeId ?? defaultThemeId,
    appearance:
        (syncTheme ? sharedAppearance : null) ??
        localAppearance ??
        ThemeAppearance.system,
  );
}
