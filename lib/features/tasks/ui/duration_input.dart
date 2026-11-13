import 'package:flutter/material.dart';

import '../../../domain/models.dart';
import '../../../domain/rules.dart';
import '../../../l10n/app_localizations.dart';
import '../../../nlp/duration_text.dart';

/// Готовые варианты длительности, минуты.
const List<int> durationPresets = [15, 30, 45, 60, 90, 120];

/// Подпись длительности: «45 мин», «2 ч», «1 ч 30 мин».
String durationLabel(AppLocalizations l10n, TaskDuration d) =>
    minutesLabel(l10n, durationInMinutes(d));

String minutesLabel(AppLocalizations l10n, int minutes) {
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (hours == 0) return l10n.durationMinutes(rest);
  if (rest == 0) return l10n.durationHours(hours);
  return l10n.durationHoursMinutes(hours, rest);
}

/// Длительность из текста поля: `(value: null)` — поле пусто (без
/// длительности); `null` — текст не разобран или вне 1 минуты – 24 часов.
({TaskDuration? value})? readDuration(String text) {
  if (text.trim().isEmpty) return (value: null);
  final minutes = parseDurationMinutes(text);
  if (minutes == null || !Limits.durationInRange(minutes)) {
    return null;
  }
  return (value: TaskDuration(amount: minutes, unit: 'minute'));
}

/// Поле длительности «выбрать или ввести» (help «Set a task duration»):
/// текст, меню готовых вариантов и крестик, который убирает длительность
/// (help: «click the X beside the duration»).
class DurationInput extends StatelessWidget {
  const DurationInput({
    super.key,
    required this.controller,
    this.error,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
  });

  final TextEditingController controller;

  /// Текст ошибки под полем.
  final String? error;
  final VoidCallback? onChanged;
  final VoidCallback? onSubmitted;
  final bool autofocus;

  void _set(String text) {
    controller.text = text;
    onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TextField(
      controller: controller,
      autofocus: autofocus,
      decoration: InputDecoration(
        labelText: l10n.fieldDuration,
        hintText: l10n.durationHint,
        errorText: error,
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListenableBuilder(
              listenable: controller,
              builder: (context, _) => controller.text.isEmpty
                  ? const SizedBox.shrink()
                  : IconButton(
                      tooltip: l10n.removeDuration,
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => _set(''),
                    ),
            ),
            PopupMenuButton<int>(
              tooltip: l10n.fieldDuration,
              icon: const Icon(Icons.arrow_drop_down),
              onSelected: (m) => _set(minutesLabel(l10n, m)),
              itemBuilder: (context) => [
                for (final m in durationPresets)
                  PopupMenuItem(value: m, child: Text(minutesLabel(l10n, m))),
              ],
            ),
          ],
        ),
      ),
      onChanged: (_) => onChanged?.call(),
      onSubmitted: (_) => onSubmitted?.call(),
    );
  }
}

/// Окно «Своя длительность…» поля панели: поле [DurationInput], «Отмена» и
/// «Сохранить». Результат: `(value: …)` — новая длительность (`null` внутри —
/// убрать), `null` — окно закрыли.
Future<({TaskDuration? value})?> showDurationDialog(
  BuildContext context,
  TaskDuration? current,
) => showDialog<({TaskDuration? value})>(
  context: context,
  builder: (_) => _DurationDialog(
    initial: current == null
        ? ''
        : durationLabel(AppLocalizations.of(context), current),
  ),
);

class _DurationDialog extends StatefulWidget {
  const _DurationDialog({required this.initial});

  /// Текущая длительность подписью; пусто — без длительности.
  final String initial;

  @override
  State<_DurationDialog> createState() => _DurationDialogState();
}

class _DurationDialogState extends State<_DurationDialog> {
  late final TextEditingController _text = TextEditingController(
    text: widget.initial,
  );
  bool _bad = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _save() {
    final read = readDuration(_text.text);
    if (read == null) return setState(() => _bad = true);
    Navigator.pop(context, read);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.fieldDuration),
      content: SizedBox(
        width: 320,
        child: DurationInput(
          controller: _text,
          autofocus: true,
          error: _bad ? l10n.rejectBadDuration : null,
          onChanged: () => setState(() => _bad = false),
          onSubmitted: _save,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(onPressed: _save, child: Text(l10n.actionSave)),
      ],
    );
  }
}
