import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_palette.dart';
import '../../../domain/models.dart';
import '../../../l10n/app_localizations.dart';
import '../logic/due_dates.dart';
import '../logic/repeat_rules.dart';
import '../logic/task_commands.dart';
import 'custom_repeat_dialog.dart';
import 'due_ui.dart';
import 'duration_input.dart';
import 'time_dialog.dart';

/// Низ планировщика: «Время» (окно времени и длительности — [showTimeDialog]),
/// «Убрать время», «Повторить» (готовые варианты и «Пользовательский…»),
/// значок снятия повтора (help: «dismiss icon at the bottom of the
/// scheduler») и «Без срока». Выбор отдаёт новый срок в [onDone], окно
/// «Время» — срок и длительность в [onTime]. «Убрать время» нет, когда без
/// времени правило не посчитать (часовое): [TaskCommands.setDue] такой срок
/// не примет.
class SchedulerBottomBar extends StatelessWidget {
  const SchedulerBottomBar({
    super.key,
    required this.current,
    required this.lang,
    required this.now,
    required this.onDone,
    required this.onTime,
    this.duration,
    this.withDuration = false,
    this.wholeSeries = false,
  });

  final Due? current;

  /// Язык текста правила: `ru` или `en`.
  final String lang;

  /// «Сейчас» окна (стенное время) — то же, что у остальных частей
  /// планировщика.
  final DateTime now;
  final ValueChanged<Due?> onDone;

  /// Итог окна «Время»: срок с новым временем и длительность (`null` — окно
  /// без длительности).
  final void Function(Due due, ({TaskDuration? value})? duration) onTime;

  /// Длительность задачи — значение поля в окне «Время».
  final TaskDuration? duration;

  /// В окне «Время» есть длительность (одна задача).
  final bool withDuration;

  /// «Время» меняет всю серию, а не только ближайшее вхождение: у задачи из
  /// быстрого добавления вхождений ещё не было (решение А по О-65).
  final bool wholeSeries;

  Future<void> _time(BuildContext context, Due current) async {
    final picked = await showTimeDialog(
      context,
      time: current.time,
      duration: duration,
      withDuration: withDuration,
    );
    if (picked == null || !context.mounted) return;
    final due = picked.time == current.time
        ? current
        : dueWithTime(current, picked.time, wholeSeries: wholeSeries);
    onTime(due, picked.duration);
  }

  /// Подпись «Время»: время и длительность, если есть.
  String _timeLabel(AppLocalizations l10n, Due due) {
    final time = due.time;
    if (time == null) return l10n.addTime;
    final d = withDuration ? duration : null;
    return d == null ? time : '$time · ${durationLabel(l10n, d)}';
  }

  Future<void> _repeat(BuildContext context, Object pick) async {
    final Due? due = switch (pick) {
      final RepeatPreset preset => dueWithRule(
        current,
        presetRule(preset, repeatAnchor(current, now)),
        lang: lang,
        now: now,
      ),
      _ => await showCustomRepeat(
        context,
        current: current,
        lang: lang,
        now: now,
      ),
    };
    if (due != null && context.mounted) onDone(due);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final anchor = repeatAnchor(current, now);
    final due = current;
    final recurring = due?.isRecurring ?? false;
    // Правило без текста (пришло синхронизацией) — подпись «Повторить», но
    // снять его можно.
    final rule = recurring ? repeatText(context, due!) : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Wrap(
        spacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (due != null)
            TextButton.icon(
              icon: const Icon(Icons.schedule, size: 18),
              label: Text(_timeLabel(l10n, due)),
              onPressed: () => _time(context, due),
            ),
          if (due?.time != null &&
              TaskCommands.acceptsDue(
                dueWithTime(due!, null, wholeSeries: wholeSeries),
                now,
              ))
            TextButton(
              onPressed: () =>
                  onDone(dueWithTime(due, null, wholeSeries: wholeSeries)),
              child: Text(l10n.removeTime),
            ),
          PopupMenuButton<Object>(
            tooltip: l10n.repeat,
            onSelected: (pick) => _repeat(context, pick),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: RepeatPreset.daily,
                child: Text(l10n.repeatDaily),
              ),
              PopupMenuItem(
                value: RepeatPreset.weekly,
                child: Text(
                  l10n.repeatWeekly(DateFormat.E(locale).format(anchor)),
                ),
              ),
              PopupMenuItem(
                value: RepeatPreset.monthly,
                child: Text(l10n.repeatMonthly('${anchor.day}')),
              ),
              PopupMenuItem(
                value: RepeatPreset.yearly,
                child: Text(
                  l10n.repeatYearly(DateFormat.MMMd(locale).format(anchor)),
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(value: 'custom', child: Text(l10n.repeatCustom)),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.repeat, size: 18, color: palette.accent),
                  const SizedBox(width: 6),
                  // Правило с окончанием длиннее окна — обрезается.
                  Flexible(
                    child: Text(
                      rule ?? l10n.repeat,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: palette.accent),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (recurring)
            IconButton(
              tooltip: l10n.repeatRemove,
              iconSize: 18,
              icon: const Icon(Icons.close),
              onPressed: () => onDone(
                due!.copyWith(
                  rule: null,
                  string: null,
                  lang: null,
                  seriesTime: null,
                ),
              ),
            ),
          if (due != null)
            TextButton.icon(
              icon: const Icon(Icons.block, size: 18),
              label: Text(l10n.noDue),
              onPressed: () => onDone(null),
            ),
        ],
      ),
    );
  }
}
