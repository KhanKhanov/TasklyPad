import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/data_providers.dart';
import '../../../app/theme/app_palette.dart';
import '../../../domain/models.dart';
import '../../../l10n/app_localizations.dart';
import '../logic/due_dates.dart';

/// Подпись срока для строки задачи и панели: «Сегодня», «Завтра», день недели
/// или дата, со временем; цвет — просрочено / сегодня / прочее.
({String text, Color color}) dueLabel(
  BuildContext context,
  String date,
  String? time,
  DateTime today,
) {
  final l10n = AppLocalizations.of(context);
  final palette = AppPalette.of(context);
  final locale = Localizations.localeOf(context).toLanguageTag();
  final day = parseIsoDate(date);
  if (day == null) return (text: date, color: palette.textSecondary);
  final kind = dueKind(day, today);
  final name = switch (kind) {
    DueKind.today => l10n.dueToday,
    DueKind.tomorrow => l10n.dueTomorrow,
    DueKind.overdueYesterday => l10n.dueYesterday,
    DueKind.thisWeek => DateFormat.EEEE(locale).format(day),
    _ when day.year != today.year => DateFormat.yMMMd(locale).format(day),
    _ => DateFormat.MMMd(locale).format(day),
  };
  final color = switch (kind) {
    DueKind.overdue || DueKind.overdueYesterday => palette.danger,
    DueKind.today => palette.dateToday,
    _ => palette.textSecondary,
  };
  return (
    text: time == null ? name : '$name ${_time(context, time)}',
    color: color,
  );
}

/// Время срока в формате локали и системы: 24 часа в ru, 12 часов (AM/PM)
/// в en, если система не просит 24 часа.
String _time(BuildContext context, String time) {
  final parts = time.split(':');
  final (h, m) = (int.tryParse(parts.first), int.tryParse(parts.last));
  if (parts.length != 2 || h == null || m == null) return time;
  return MaterialLocalizations.of(context).formatTimeOfDay(
    TimeOfDay(hour: h, minute: m),
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
}

/// Выбор срока, как планировщик Todoist: быстрые варианты, своя дата,
/// время, «Без срока». Возвращает новый срок; `null` у записи — убрать срок;
/// сам `null` — пользователь закрыл выбор.
Future<({Due? due})?> pickDue(
  BuildContext context,
  WidgetRef ref,
  Due? current,
) async {
  final l10n = AppLocalizations.of(context);
  final today = ref.read(clockProvider).nowUtc().toLocal();
  final choice = await showDialog<Object>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(l10n.fieldDue),
      children: [
        for (final (option, label) in [
          (QuickDue.today, l10n.dueToday),
          (QuickDue.tomorrow, l10n.dueTomorrow),
          (QuickDue.weekend, l10n.dueWeekend),
          (QuickDue.nextWeek, l10n.dueNextWeek),
        ])
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, option),
            child: Text(label),
          ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, 'pick'),
          child: Text(l10n.pickDate),
        ),
        if (current != null)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'time'),
            child: Text(current.time == null ? l10n.addTime : l10n.removeTime),
          ),
        if (current != null)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'none'),
            child: Text(l10n.noDue),
          ),
      ],
    ),
  );
  if (choice == null || !context.mounted) return null;
  switch (choice) {
    case final QuickDue option:
      final day = quickDueDate(option, today);
      return (due: dueOnDate(current, isoDate(day)));
    case 'pick':
      final day = await showDatePicker(
        context: context,
        initialDate: parseIsoDate(current?.date ?? '') ?? today,
        firstDate: DateTime(today.year - 5),
        lastDate: DateTime(today.year + 20),
      );
      if (day == null) return null;
      return (due: dueOnDate(current, isoDate(day)));
    case 'time' when current != null:
      if (current.time != null) return (due: dueWithTime(current, null));
      final time = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 9, minute: 0),
      );
      if (time == null) return null;
      final hh = time.hour.toString().padLeft(2, '0');
      final mm = time.minute.toString().padLeft(2, '0');
      return (due: dueWithTime(current, '$hh:$mm'));
    case 'none':
      return (due: null);
  }
  return null;
}

/// Выбор дедлайна: дата или «Без дедлайна». `null` — выбор закрыт.
Future<({String? date})?> pickDeadline(
  BuildContext context,
  WidgetRef ref,
  String? current,
) async {
  final l10n = AppLocalizations.of(context);
  final today = ref.read(clockProvider).nowUtc().toLocal();
  if (current != null) {
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.fieldDeadline),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.pickDate),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.noDeadline),
          ),
        ],
      ),
    );
    if (remove == null || !context.mounted) return null;
    if (remove) return (date: null);
  }
  final day = await showDatePicker(
    context: context,
    initialDate: parseIsoDate(current ?? '') ?? today,
    firstDate: DateTime(today.year - 5),
    lastDate: DateTime(today.year + 20),
  );
  return day == null ? null : (date: isoDate(day));
}
