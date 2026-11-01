import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/data_providers.dart';
import '../../../app/theme/app_palette.dart';
import '../../../domain/models.dart';
import '../../../l10n/app_localizations.dart';
import '../../../nlp/parse_context.dart';
import '../../../nlp/rule_text.dart';
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

/// Текст правила повторяющегося [due] на языке интерфейса («каждый пн»);
/// у правила без текстовой формы — срок текстом, как его ввели. `null` —
/// срок не повторяется.
String? repeatText(BuildContext context, Due due) {
  final rule = due.rule;
  if (rule == null) return null;
  final lang = Localizations.localeOf(context).languageCode;
  final text = ParseContext.supportedLanguages.contains(lang)
      ? ruleText(rule, lang)
      : null;
  return text ?? due.string;
}

/// Дедлайн [deadline] виден в строке задачи: у повторяющейся задачи после
/// даты дедлайна он пропадает из вида, срок идёт дальше (help «Complete a
/// task with a recurring date»; решение 6А «Ход M3.7»).
bool deadlineShown(Task task, String deadline, DateTime today) {
  if (!(task.due?.isRecurring ?? false)) return true;
  final day = parseIsoDate(deadline);
  return day == null || !day.isBefore(today);
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
