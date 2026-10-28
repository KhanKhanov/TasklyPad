import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../../../app/data_providers.dart';
import '../../../app/theme/app_palette.dart';
import '../../../app/theme/app_themes.dart';
import '../../../domain/theme_settings.dart';
import '../../../l10n/app_localizations.dart';
import '../logic/theme_commands.dart';
import 'settings_screen.dart';
import 'theme_texts.dart';

/// «Настройки → Тема»: тема, внешний вид и «Синхронизировать тему», как в
/// Todoist (docs/plans/m2-core-app.md, M2.3, коммит 4). На компьютере выбор
/// применяет «Обновить» (help: «Click Update to save your changes»), на
/// Android — сразу.
class ThemeSection extends ConsumerStatefulWidget {
  const ThemeSection({super.key});

  @override
  ConsumerState<ThemeSection> createState() => _ThemeSectionState();
}

class _ThemeSectionState extends ConsumerState<ThemeSection> {
  static final Logger _log = Logger();

  /// Выбор, который сохранённое ещё не догнало: на компьютере — до
  /// «Обновить», на Android — пока идёт запись. `null` — показывается
  /// сохранённое (и пришедшее синхронизацией).
  ThemeChoice? _choice;
  bool? _sync;

  /// Сохранения по одному, в порядке выбора: иначе второе нажатие на
  /// Android прочитало бы состояние до первого и отменило бы его.
  Future<void> _queue = Future<void>.value();
  int _saving = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final ThemeSettings saved =
        ref.watch(themeSettingsProvider).value ??
        ref.watch(initialThemeSettingsProvider);
    final instant = Theme.of(context).platform == TargetPlatform.android;
    // Сохранённое догнало выбор (своей записью или синхронизацией) — выбора
    // больше нет: дальше раздел показывает то, что придёт.
    if (_saving == 0 &&
        _choice == saved.effective &&
        _sync == saved.syncTheme) {
      _choice = null;
      _sync = null;
    }
    final choice = _choice ?? saved.effective;
    final sync = _sync ?? saved.syncTheme;
    final dirty = choice != saved.effective || sync != saved.syncTheme;
    // На компьютере, пока идёт запись, выбор не принимается: он потерялся бы.
    final locked = !instant && _saving > 0;
    final title = TextStyle(
      color: palette.textPrimary,
      fontWeight: FontWeight.w600,
    );

    // От текущего состояния, а не от значений этой сборки: два нажатия до
    // перерисовки иначе потеряли бы первое.
    void change({ThemeChoice Function(ThemeChoice)? edit, bool? syncTo}) {
      final from = (
        choice: _choice ?? saved.effective,
        syncTheme: _sync ?? saved.syncTheme,
      );
      final to = edit == null ? from.choice : edit(from.choice);
      final syncNow = syncTo ?? from.syncTheme;
      if (to == from.choice && syncNow == from.syncTheme) return;
      setState(() {
        _choice = to;
        _sync = syncNow;
      });
      if (instant) _save(to, syncNow, from);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsHeader(l10n.themeSection),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final theme in appThemes)
              _ThemeTile(
                theme: theme,
                title: themeTitle(l10n, theme.id),
                selected: appThemeById(choice.themeId) == theme,
                onTap: locked
                    ? null
                    : () => change(edit: (c) => c.copyWith(themeId: theme.id)),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Text(l10n.themeAppearance, style: title),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: SegmentedButton<ThemeAppearance>(
            showSelectedIcon: false,
            segments: [
              for (final a in ThemeAppearance.values)
                ButtonSegment(value: a, label: Text(appearanceTitle(l10n, a))),
            ],
            selected: {choice.appearance},
            onSelectionChanged: locked
                ? null
                : (value) =>
                      change(edit: (c) => c.copyWith(appearance: value.single)),
          ),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.syncTheme, style: title),
          value: sync,
          onChanged: locked ? null : (value) => change(syncTo: value),
        ),
        if (!instant)
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: dirty && !locked
                  ? () => _save(choice, sync, (
                      choice: saved.effective,
                      syncTheme: saved.syncTheme,
                    ))
                  : null,
              child: Text(l10n.themeUpdate),
            ),
          ),
      ],
    );
  }

  /// Записать выбор после предыдущих; [from] — от чего пользователь его
  /// сделал (в общую тему уходят только изменённые поля).
  void _save(ThemeChoice choice, bool sync, ThemeBase from) {
    final commands = ref.read(themeCommandsProvider);
    final instant = Theme.of(context).platform == TargetPlatform.android;
    setState(() => _saving++);
    _queue = _queue.then((_) async {
      try {
        await commands.save(choice, syncTheme: sync, from: from);
      } on Object catch (error, stackTrace) {
        _log.e('Тема не сохранена', error: error, stackTrace: stackTrace);
        // На компьютере выбор остаётся — «Обновить» можно нажать снова; на
        // Android кнопки нет, и раздел возвращается к сохранённому.
        if (instant && mounted) {
          setState(() {
            _choice = null;
            _sync = null;
          });
        }
      } finally {
        if (mounted) setState(() => _saving--);
      }
    });
  }
}

/// Плитка темы: образцы светлого и тёмного варианта, название, отметка.
class _ThemeTile extends StatelessWidget {
  const _ThemeTile({
    required this.theme,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final AppTheme theme;
  final String title;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 200,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? palette.accent : palette.outline,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              _Swatch(theme.light),
              const SizedBox(width: 4),
              _Swatch(theme.dark),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: palette.textPrimary),
                ),
              ),
              if (selected) Icon(Icons.check, size: 18, color: palette.accent),
            ],
          ),
        ),
      ),
    );
  }
}

/// Образец варианта темы: фон и акцент.
class _Swatch extends StatelessWidget {
  const _Swatch(this.palette);

  final AppPalette palette;

  @override
  Widget build(BuildContext context) => Container(
    width: 28,
    height: 28,
    alignment: Alignment.bottomRight,
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: palette.background,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: AppPalette.of(context).outline),
    ),
    child: Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: palette.accent, shape: BoxShape.circle),
    ),
  );
}
