import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_palette.dart';
import '../../../l10n/app_localizations.dart';

/// Полоса недели «Предстоящего» (help «Plan your week with the Upcoming
/// view»): месяц — выбор даты, стрелки — соседняя неделя, «Сегодня» —
/// обратно к сегодняшнему дню, семь дней недели с выбранным. Неделя — с
/// понедельника (настройка начала недели — M10); прошлых дней нет: стрелка
/// назад не уходит раньше сегодня (допущение, О-69), вперёд — не дальше двух
/// лет ([lastDay]).
class WeekStrip extends StatelessWidget {
  const WeekStrip({
    super.key,
    required this.selected,
    required this.today,
    required this.onSelect,
  });

  final DateTime selected;
  final DateTime today;
  final ValueChanged<DateTime> onSelect;

  /// Последний день «Предстоящего»: на два года вперёд, как
  /// `Workspace.upcomingDays`.
  static DateTime lastDay(DateTime today) =>
      DateTime(today.year + 2, today.month, today.day - 1);

  static DateTime _monday(DateTime day) =>
      DateTime(day.year, day.month, day.day - (day.weekday - 1));

  /// День, на который ведёт стрелка «Предыдущая неделя» (и `Shift+←`): та же
  /// неделя раньше, но не раньше [today]; `null` — назад уже некуда.
  static DateTime? previousWeek(DateTime selected, DateTime today) {
    final monday = _monday(selected);
    if (!monday.isAfter(today)) return null;
    final previous = DateTime(monday.year, monday.month, monday.day - 7);
    return previous.isBefore(today) ? today : previous;
  }

  /// День, на который ведёт стрелка «Следующая неделя» (и `Shift+→`): понедельник
  /// следующей недели; `null` — дальше [lastDay] не уходим.
  static DateTime? nextWeek(DateTime selected, DateTime today) {
    final monday = _monday(selected);
    final next = DateTime(monday.year, monday.month, monday.day + 7);
    return next.isAfter(lastDay(today)) ? null : next;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final last = lastDay(today);
    final monday = _monday(selected);
    final previous = previousWeek(selected, today);
    final next = nextWeek(selected, today);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            TextButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: selected,
                  firstDate: today,
                  lastDate: last,
                  helpText: l10n.pickDate,
                );
                if (picked != null) onSelect(picked);
              },
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.arrow_drop_down, size: 20),
              label: Text(
                DateFormat.yMMMM(locale).format(selected),
                style: TextStyle(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Spacer(),
            IconButton(
              tooltip: l10n.previousWeek,
              icon: const Icon(Icons.chevron_left),
              onPressed: previous == null ? null : () => onSelect(previous),
            ),
            IconButton(
              tooltip: l10n.nextWeek,
              icon: const Icon(Icons.chevron_right),
              onPressed: next == null ? null : () => onSelect(next),
            ),
            TextButton(
              onPressed: selected == today ? null : () => onSelect(today),
              child: Text(l10n.todayView),
            ),
          ],
        ),
        Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: _DayCell(
                  day: DateTime(monday.year, monday.month, monday.day + i),
                  selected: selected,
                  today: today,
                  last: last,
                  onSelect: onSelect,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// День полосы: день недели и число; выбранный — залит цветом акцента,
/// сегодня — число цветом акцента, прошлые дни недоступны.
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.selected,
    required this.today,
    required this.last,
    required this.onSelect,
  });

  final DateTime day;
  final DateTime selected;
  final DateTime today;
  final DateTime last;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final enabled = !day.isBefore(today) && !day.isAfter(last);
    final isSelected = day == selected;
    final numberColor = isSelected
        ? Theme.of(context).colorScheme.onPrimary
        : !enabled
        ? palette.textSecondary.withValues(alpha: 0.5)
        : day == today
        ? palette.accent
        : palette.textPrimary;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: enabled && !isSelected ? () => onSelect(day) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            Text(
              DateFormat.E(locale).format(day),
              style: TextStyle(color: palette.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: isSelected
                  ? BoxDecoration(color: palette.accent, shape: BoxShape.circle)
                  : null,
              child: Text(
                '${day.day}',
                style: TextStyle(
                  color: numberColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
