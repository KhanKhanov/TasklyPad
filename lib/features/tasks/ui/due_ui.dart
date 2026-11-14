import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_palette.dart';
import '../../../domain/models.dart';
import '../../../l10n/app_localizations.dart';
import '../../../nlp/parse_context.dart';
import '../../../nlp/rule_text.dart';
import '../logic/due_dates.dart';
import '../state/today.dart';

/// Подпись срока для строки задачи и панели: «Сегодня», «Завтра», день недели
/// или дата, со временем; цвет — по [dueTone]. [timePassed] — время срока
/// сегодня уже прошло ([dueLabelOf] берёт его из [dueTimePassedProvider]).
({String text, Color color}) dueLabel(
  BuildContext context,
  String date,
  String? time,
  DateTime today, {
  bool timePassed = false,
}) {
  final palette = AppPalette.of(context);
  final day = parseIsoDate(date);
  if (day == null) return (text: date, color: palette.textSecondary);
  final color = switch (dueTone(day, today, timePassed: timePassed)) {
    DueTone.overdue => palette.danger,
    DueTone.today => palette.dateToday,
    DueTone.tomorrow => palette.dateTomorrow,
    DueTone.nextWeek => palette.dateNextWeek,
    DueTone.none => palette.textSecondary,
  };
  return (text: _dayText(context, day, time, today), color: color);
}

/// [dueLabel] срока задачи [due] — с прошедшим временем сегодня; вызывается
/// при сборке: подпись станет красной в момент срока.
({String text, Color color}) dueLabelOf(
  BuildContext context,
  WidgetRef ref,
  Due due,
  DateTime today,
) {
  final time = due.time;
  final passed =
      time != null && ref.watch(dueTimePassedProvider(due.date, time));
  return dueLabel(context, due.date, time, today, timePassed: passed);
}

/// Значок дедлайна — мишень, как 🎯 в анонсе дедлайнов Todoist: флажок —
/// значок приоритета, и красный флажок дедлайна читался как «Приоритет 1»
/// (решение 2А plans/m5 «Решения проверки M5.3»; вид в help не описан —
/// допущение О-69).
const IconData deadlineIcon = Icons.track_changes;

/// Подпись дедлайна: просрочен — дата красным, сегодня — «Сегодня» зелёным;
/// через 1–7 дней — обратный отсчёт «осталось N дней» (help «Add deadlines to
/// tasks»: countdown within 7 days; решение 3А plans/m5, формулировка —
/// допущение О-69), дальше — дата без цвета. Цвета сроков на дедлайн help не
/// переносит (допущение О-57). [countdown] — `false` там, где выбирают дату:
/// в выборе дедлайна и в быстром добавлении видна сама дата.
({String text, Color color}) deadlineLabel(
  BuildContext context,
  String deadline,
  DateTime today, {
  bool countdown = true,
}) {
  final palette = AppPalette.of(context);
  final day = parseIsoDate(deadline);
  if (day == null) return (text: deadline, color: palette.textSecondary);
  final color = switch (dueKind(day, today)) {
    DueKind.overdue || DueKind.overdueYesterday => palette.danger,
    DueKind.today => palette.dateToday,
    _ => palette.textSecondary,
  };
  final days = daysUntil(day, today);
  if (countdown && days >= 1 && days <= 7) {
    return (
      text: AppLocalizations.of(context).deadlineDaysLeft(days),
      color: color,
    );
  }
  return (text: _dayText(context, day, null, today), color: color);
}

String _dayText(
  BuildContext context,
  DateTime day,
  String? time,
  DateTime today,
) {
  final l10n = AppLocalizations.of(context);
  final locale = Localizations.localeOf(context).toLanguageTag();
  final name = switch (dueKind(day, today)) {
    DueKind.today => l10n.dueToday,
    DueKind.tomorrow => l10n.dueTomorrow,
    DueKind.overdueYesterday => l10n.dueYesterday,
    DueKind.thisWeek => DateFormat.EEEE(locale).format(day),
    _ when day.year != today.year => DateFormat.yMMMd(locale).format(day),
    _ => DateFormat.MMMd(locale).format(day),
  };
  return time == null ? name : '$name ${_time(context, time)}';
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

/// Текст правила повторяющегося [due] на языке интерфейса («каждый пн»);
/// у правила без текстовой формы — срок текстом, как его ввели. `null` —
/// срок не повторяется.
String? repeatText(BuildContext context, Due due) {
  final rule = due.rule;
  if (rule == null) return null;
  final lang = Localizations.localeOf(context).languageCode;
  return ruleText(rule, ParseContext.languageFor(lang)) ?? due.string;
}

/// Дедлайн [deadline] виден в строке задачи: у повторяющейся задачи после
/// даты дедлайна он пропадает из вида, срок идёт дальше (help «Complete a
/// task with a recurring date»; решение 6А «Ход M3.7»).
bool deadlineShown(Task task, String deadline, DateTime today) {
  if (!(task.due?.isRecurring ?? false)) return true;
  final day = parseIsoDate(deadline);
  return day == null || !day.isBefore(today);
}
