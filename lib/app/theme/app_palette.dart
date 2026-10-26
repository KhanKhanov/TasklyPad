import 'package:flutter/material.dart';

/// Цвета интерфейса одной темы — токены, а не цвета в виджетах: виджет берёт
/// `AppPalette.of(context).accent`, и смена темы не требует правок экранов.
///
/// Значения — docs/plans/m2-core-app.md «Сверка с Todoist» (сняты с
/// официальных скриншотов Todoist и макета Taskly). Цвета, которых на
/// скриншотах не было, помечены и вынесены в docs/OBLIGATIONS.md (О-21).
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.sidebar,
    required this.raised,
    required this.selected,
    required this.onSelected,
    required this.divider,
    required this.outline,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
    required this.dateToday,
    required this.danger,
    required this.priority,
  });

  /// Фон области контента.
  final Color background;

  /// Фон сайдбара.
  final Color sidebar;

  /// Приподнятая поверхность: поля ввода, меню, диалоги.
  final Color raised;

  /// Фон выбранного пункта сайдбара.
  final Color selected;

  /// Текст и значок выбранного пункта.
  final Color onSelected;
  final Color divider;
  final Color outline;

  /// Главный акцент: «Добавить задачу», кнопки подтверждения.
  final Color accent;
  final Color textPrimary;
  final Color textSecondary;

  /// Срок «сегодня».
  final Color dateToday;

  /// Опасное действие: удаление.
  final Color danger;

  /// Цвет обводки кружка задачи по приоритету: [0] — P1 … [3] — P4.
  final List<Color> priority;

  static AppPalette of(BuildContext context) =>
      Theme.of(context).extension<AppPalette>()!;

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(AppPalette? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      background: c(background, other.background),
      sidebar: c(sidebar, other.sidebar),
      raised: c(raised, other.raised),
      selected: c(selected, other.selected),
      onSelected: c(onSelected, other.onSelected),
      divider: c(divider, other.divider),
      outline: c(outline, other.outline),
      accent: c(accent, other.accent),
      textPrimary: c(textPrimary, other.textPrimary),
      textSecondary: c(textSecondary, other.textSecondary),
      dateToday: c(dateToday, other.dateToday),
      danger: c(danger, other.danger),
      priority: [
        for (var i = 0; i < priority.length; i++)
          c(priority[i], other.priority[i]),
      ],
    );
  }
}

/// Палитра цветов проектов и меток — как в Todoist (официальный SDK,
/// `src/utils/colors.ts`). Ключ — имя цвета в данных (`berry_red` …).
const Map<String, Color> projectColors = {
  'berry_red': Color(0xFFB8255F),
  'red': Color(0xFFDB4035),
  'orange': Color(0xFFFF9933),
  'yellow': Color(0xFFFAD000),
  'olive_green': Color(0xFFAFB83B),
  'lime_green': Color(0xFF7ECC49),
  'green': Color(0xFF299438),
  'mint_green': Color(0xFF6ACCBC),
  'teal': Color(0xFF158FAD),
  'sky_blue': Color(0xFF14AAF5),
  'light_blue': Color(0xFF96C3EB),
  'blue': Color(0xFF4073FF),
  'grape': Color(0xFF884DFF),
  'violet': Color(0xFFAF38EB),
  'lavender': Color(0xFFEB96EB),
  'magenta': Color(0xFFE05194),
  'salmon': Color(0xFFFF8D85),
  'charcoal': Color(0xFF808080),
  'grey': Color(0xFFB8B8B8),
  'taupe': Color(0xFFCCAC93),
};

/// Цвет проекта по имени; незнакомое имя (от более новой версии) — charcoal.
Color projectColor(String name) =>
    projectColors[name] ?? projectColors['charcoal']!;
