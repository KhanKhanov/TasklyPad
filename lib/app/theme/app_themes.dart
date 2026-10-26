import 'package:flutter/material.dart';

import 'app_palette.dart';

/// Тема оформления: светлый и тёмный вариант, как у тем Todoist.
///
/// Сейчас одна тема — Taskly: светлый вариант снят с официальных скриншотов
/// Todoist, тёмный — с макета мобильного приложения пользователя. Тема
/// Todoist добавится, когда будут сняты цвета её тёмного варианта (О-21);
/// выбор темы — M2.3.
final class AppTheme {
  const AppTheme({required this.id, required this.light, required this.dark});

  final String id;
  final AppPalette light;
  final AppPalette dark;
}

/// P2 (оранжевый) на скриншотах не встречался чётко — значение не сверено (О-21).
const Color _p2Unverified = Color(0xFFEB8909);

const AppTheme tasklyTheme = AppTheme(
  id: 'taskly',
  light: AppPalette(
    background: Color(0xFFFFFFFF),
    sidebar: Color(0xFFFCFAF8),
    raised: Color(0xFFFFFFFF),
    selected: Color(0xFFFFF0E5),
    onSelected: Color(0xFFC54C38),
    divider: Color(0xFFF4F4F4),
    outline: Color(0xFFE4E1E5),
    accent: Color(0xFFDE4D40),
    textPrimary: Color(0xFF1F1F1F),
    textSecondary: Color(0xFF818181),
    dateToday: Color(0xFF249539),
    danger: Color(0xFFDE4D40),
    priority: [
      Color(0xFFDA4844),
      _p2Unverified,
      Color(0xFF2F73DF),
      Color(0xFFB9B9B9),
    ],
  ),
  dark: AppPalette(
    background: Color(0xFF0F1014),
    sidebar: Color(0xFF15181F),
    raised: Color(0xFF1C1F28),
    selected: Color(0xFF131B2E),
    onSelected: Color(0xFF38BDF8),
    divider: Color(0xFF1F232C),
    outline: Color(0xFF31333F),
    accent: Color(0xFF38BDF8),
    textPrimary: Color(0xFFF7FAFF),
    textSecondary: Color(0xFFA5ADBA),
    // Срок «сегодня» в тёмном макете не встречался — зелёный из светлого (О-21).
    dateToday: Color(0xFF3CA04F),
    danger: Color(0xFFD03F3F),
    priority: [
      Color(0xFFEA352C),
      _p2Unverified,
      Color(0xFF38BDF8),
      Color(0xFF63758C),
    ],
  ),
);

/// `ThemeData` Flutter по палитре: Material-виджеты (кнопки, поля, меню)
/// получают те же цвета, что и наши виджеты через [AppPalette].
ThemeData buildThemeData(AppPalette p, Brightness brightness) {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: p.accent,
        brightness: brightness,
      ).copyWith(
        primary: p.accent,
        surface: p.background,
        onSurface: p.textPrimary,
        onSurfaceVariant: p.textSecondary,
        outline: p.outline,
        outlineVariant: p.divider,
        error: p.danger,
      );
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: p.background,
    dividerColor: p.divider,
    dividerTheme: DividerThemeData(color: p.divider, space: 1, thickness: 1),
    dialogTheme: DialogThemeData(backgroundColor: p.raised),
    popupMenuTheme: PopupMenuThemeData(color: p.raised),
    extensions: [p],
  );
}
