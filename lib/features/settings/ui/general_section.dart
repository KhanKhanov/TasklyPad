import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../../../app/data_providers.dart';
import '../../../app/theme/app_palette.dart';
import '../../../l10n/app_localizations.dart';
import 'settings_screen.dart';

/// «Настройки → Основное»: «Умное распознавание дат» (help «Turn smart date
/// recognition on or off»). Как у «Темы», на компьютере выбор применяет
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
  bool _saving = false;

  /// Текст ошибки последнего сохранения; `null` — ошибки нет.
  String? _error;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final saved = ref.watch(smartDateRecognitionProvider).value ?? true;
    final instant = Theme.of(context).platform == TargetPlatform.android;
    if (!_saving && _smartDates == saved) _smartDates = null;
    final value = _smartDates ?? saved;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsHeader(l10n.generalSection),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            l10n.smartDateRecognition,
            style: TextStyle(
              color: palette.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            l10n.smartDateRecognitionHint,
            style: TextStyle(color: palette.textSecondary),
          ),
          value: value,
          onChanged: _saving
              ? null
              : (v) {
                  setState(() => _smartDates = v);
                  if (instant) _save(v);
                },
        ),
        if (_error case final error?)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(error, style: TextStyle(color: palette.danger)),
          ),
        if (!instant)
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: value != saved && !_saving ? () => _save(value) : null,
              child: Text(l10n.settingsUpdate),
            ),
          ),
      ],
    );
  }

  Future<void> _save(bool value) async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(generalSettingsCommandsProvider)
          .setSmartDateRecognition(value);
    } on Object catch (error, stackTrace) {
      _log.e('Настройка не сохранена', error: error, stackTrace: stackTrace);
      if (!mounted) return;
      // На компьютере выбор остаётся — «Обновить» можно нажать снова.
      setState(() {
        _error = l10n.actionFailed('$error');
        if (Theme.of(context).platform == TargetPlatform.android) {
          _smartDates = null;
        }
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
