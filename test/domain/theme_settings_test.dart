import 'package:flutter_test/flutter_test.dart';
import 'package:planner/app/theme/app_themes.dart';
import 'package:planner/domain/theme_settings.dart';

// Действующая тема — по каждому полю: общая (при синхронизации), своя,
// умолчание (SYNC_DESIGN «Специальные случаи»).
void main() {
  const dark = ThemeAppearance.dark;
  const light = ThemeAppearance.light;
  const system = ThemeAppearance.system;

  final cases = <(String, ThemeSettings, ThemeChoice)>[
    (
      'ничего не выбрано → Taskly и «как в системе»',
      const ThemeSettings(),
      const ThemeChoice(themeId: 'taskly', appearance: system),
    ),
    (
      'синхронизация включена, общая тема есть → общая, своя не действует',
      const ThemeSettings(
        sharedThemeId: 'kale',
        sharedAppearance: dark,
        localThemeId: 'moonstone',
        localAppearance: light,
      ),
      const ThemeChoice(themeId: 'kale', appearance: dark),
    ),
    (
      'синхронизация выключена → своя, общая не действует',
      const ThemeSettings(
        syncTheme: false,
        sharedThemeId: 'kale',
        sharedAppearance: dark,
        localThemeId: 'moonstone',
        localAppearance: light,
      ),
      const ThemeChoice(themeId: 'moonstone', appearance: light),
    ),
    (
      'синхронизация выключена, своей нет → умолчание, а не общая',
      const ThemeSettings(
        syncTheme: false,
        sharedThemeId: 'kale',
        sharedAppearance: dark,
      ),
      const ThemeChoice(themeId: 'taskly', appearance: system),
    ),
    (
      'общая только с внешним видом → тема своя, вид общий',
      const ThemeSettings(sharedAppearance: dark, localThemeId: 'moonstone'),
      const ThemeChoice(themeId: 'moonstone', appearance: dark),
    ),
    (
      'синхронизация включена, общей нет → своя',
      const ThemeSettings(localThemeId: 'kale', localAppearance: light),
      const ThemeChoice(themeId: 'kale', appearance: light),
    ),
  ];

  for (final (name, settings, expected) in cases) {
    test('действующая тема: $name', () {
      expect(settings.effective, expected);
    });
  }

  test('внешний вид из журнала: незнакомое значение и не строка → нет', () {
    expect(ThemeAppearance.parse('dark'), dark);
    expect(ThemeAppearance.parse('sepia'), isNull);
    expect(ThemeAppearance.parse(1), isNull);
    expect(ThemeAppearance.parse(null), isNull);
  });

  test('незнакомый id темы показывается темой Taskly', () {
    expect(appThemeById('kale'), tasklyTheme);
    expect(appThemeById('taskly'), tasklyTheme);
  });
}
