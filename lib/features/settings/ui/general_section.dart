import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../../../app/data_providers.dart';
import '../../../app/theme/app_palette.dart';
import '../../../l10n/app_localizations.dart';
import 'settings_screen.dart';

/// «Настройки → Основное»: «Умное распознавание дат» (help «Turn smart date
/// recognition on or off») и в «Дополнительно» — «Добавлять подзадачи снова»
/// (help «Reset a sub-task»). Как у «Темы», на компьютере выбор применяет
/// «Обновить», на Android — сразу.
class GeneralSection extends ConsumerStatefulWidget {
  const GeneralSection({super.key});

  @override
  ConsumerState<GeneralSection> createState() => _GeneralSectionState();
}

class _GeneralSectionState extends ConsumerState<GeneralSection> {
  static final Logger _log = Logger();

  /// Выбор, который сохранённое ещё не догнало; `null` — показывается
  /// сохранённое (и пришедшее синхронизацией).
  bool? _smartDates;
  bool? _resetSubtasks;
  bool _saving = false;

  /// Текст ошибки последнего сохранения; `null` — ошибки нет.
  String? _error;

  bool get _instant => Theme.of(context).platform == TargetPlatform.android;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final savedSmart = ref.watch(smartDateRecognitionProvider).value ?? true;
    final savedReset = ref.watch(resetRecurringSubtasksProvider).value ?? false;
    if (!_saving && _smartDates == savedSmart) _smartDates = null;
    if (!_saving && _resetSubtasks == savedReset) _resetSubtasks = null;
    final smart = _smartDates ?? savedSmart;
    final reset = _resetSubtasks ?? savedReset;
    final changed = smart != savedSmart || reset != savedReset;
    Widget toggle({
      required String title,
      String? hint,
      required bool value,
      required ValueChanged<bool> onChanged,
    }) => SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: TextStyle(
          color: palette.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: hint == null
          ? null
          : Text(hint, style: TextStyle(color: palette.textSecondary)),
      value: value,
      onChanged: _saving ? null : onChanged,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsHeader(l10n.generalSection),
        toggle(
          title: l10n.smartDateRecognition,
          hint: l10n.smartDateRecognitionHint,
          value: smart,
          onChanged: (v) {
            setState(() => _smartDates = v);
            if (_instant) _save(smartDates: v);
          },
        ),
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Text(
            l10n.generalAdvanced,
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        toggle(
          // Подпись на компьютере и на Android разная (help ru).
          title: _instant ? l10n.resetSubtasksMobile : l10n.resetSubtasks,
          value: reset,
          onChanged: (v) {
            setState(() => _resetSubtasks = v);
            if (_instant) _save(resetSubtasks: v);
          },
        ),
        if (_error case final error?)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(error, style: TextStyle(color: palette.danger)),
          ),
        if (!_instant)
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: changed && !_saving
                  ? () => _save(
                      smartDates: smart == savedSmart ? null : smart,
                      resetSubtasks: reset == savedReset ? null : reset,
                    )
                  : null,
              child: Text(l10n.settingsUpdate),
            ),
          ),
      ],
    );
  }

  Future<void> _save({bool? smartDates, bool? resetSubtasks}) async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(generalSettingsCommandsProvider)
          .save(
            smartDateRecognition: smartDates,
            resetRecurringSubtasks: resetSubtasks,
          );
    } on Object catch (error, stackTrace) {
      _log.e('Настройка не сохранена', error: error, stackTrace: stackTrace);
      if (!mounted) return;
      // На компьютере выбор остаётся — «Обновить» можно нажать снова.
      setState(() {
        _error = l10n.actionFailed('$error');
        if (_instant) {
          _smartDates = null;
          _resetSubtasks = null;
        }
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
