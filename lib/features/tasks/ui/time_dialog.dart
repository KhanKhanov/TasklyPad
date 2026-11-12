import 'package:flutter/material.dart';

import '../../../domain/models.dart';
import '../../../l10n/app_localizations.dart';
import 'duration_input.dart';

/// Выбор в окне «Время»: время `HH:MM` (`null` — без времени) и
/// длительность (`duration: null` — окно без поля длительности; `value: null`
/// внутри — без длительности).
typedef TimePick = ({String? time, ({TaskDuration? value})? duration});

/// Окно «Время» планировщика, как в Todoist на Windows (help «Set a task
/// duration»: «Date → Time → Duration → Save»; решение 1А «Часть M4.11»
/// plans/m4): время, длительность — выбрать или ввести, крестик её убирает —
/// и «Сохранить». [withDuration] `false` — только время (несколько задач
/// сразу: у каждой своя длительность). `null` — окно закрыли.
Future<TimePick?> showTimeDialog(
  BuildContext context, {
  required String? time,
  required TaskDuration? duration,
  required bool withDuration,
}) => showDialog<TimePick>(
  context: context,
  builder: (_) => _TimeDialog(
    time: time,
    durationText: duration == null
        ? ''
        : durationLabel(AppLocalizations.of(context), duration),
    withDuration: withDuration,
  ),
);

class _TimeDialog extends StatefulWidget {
  const _TimeDialog({
    required this.time,
    required this.durationText,
    required this.withDuration,
  });

  final String? time;
  final String durationText;
  final bool withDuration;

  @override
  State<_TimeDialog> createState() => _TimeDialogState();
}

class _TimeDialogState extends State<_TimeDialog> {
  late String? _time = widget.time;
  late final TextEditingController _duration = TextEditingController(
    text: widget.durationText,
  );
  bool _bad = false;

  @override
  void dispose() {
    _duration.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final parts = _time?.split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: parts == null
          ? const TimeOfDay(hour: 9, minute: 0)
          : TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
    );
    if (picked == null || !mounted) return;
    final hh = picked.hour.toString().padLeft(2, '0');
    final mm = picked.minute.toString().padLeft(2, '0');
    setState(() => _time = '$hh:$mm');
  }

  void _save() {
    if (!widget.withDuration) {
      Navigator.pop(context, (time: _time, duration: null));
      return;
    }
    final read = readDuration(_duration.text);
    if (read == null) return setState(() => _bad = true);
    Navigator.pop(context, (time: _time, duration: read));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.timeDialogTitle),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.schedule, size: 18),
              label: Text(_time ?? l10n.addTime),
              onPressed: _pickTime,
            ),
            if (widget.withDuration) ...[
              const SizedBox(height: 16),
              DurationInput(
                controller: _duration,
                error: _bad ? l10n.rejectBadDuration : null,
                onChanged: () => setState(() => _bad = false),
                onSubmitted: _save,
              ),
            ],
          ],
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
