import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../../tasks/logic/due_dates.dart';
import '../../tasks/ui/due_ui.dart';

/// Заголовок группы дня: «5 нояб. · Завтра», «7 нояб. · пятница» на
/// ближайшую неделю, дальше и в прошлом — дата (подписи — О-68).
String dayTitle(BuildContext context, String date, DateTime today) {
  final day = parseIsoDate(date);
  if (day == null) return date;
  final name = dueLabel(context, date, null, today).text;
  final relative = switch (dueKind(day, today)) {
    DueKind.overdueYesterday ||
    DueKind.today ||
    DueKind.tomorrow ||
    DueKind.thisWeek => true,
    DueKind.overdue || DueKind.later => false,
  };
  if (!relative) return name;
  final locale = Localizations.localeOf(context).toLanguageTag();
  return AppLocalizations.of(context)
      .groupDay(DateFormat.MMMd(locale).format(day), name);
}

/// Заголовок дня «Сегодня» и «Предстоящего» — всегда с днём недели:
/// «4 нояб. · Сегодня · среда», «6 нояб. · пятница»; год — у дат другого
/// года (подписи — О-68).
String fullDayTitle(BuildContext context, String date, DateTime today) {
  final day = parseIsoDate(date);
  if (day == null) return date;
  final l10n = AppLocalizations.of(context);
  final locale = Localizations.localeOf(context).toLanguageTag();
  final text = (day.year == today.year ? DateFormat.MMMd : DateFormat.yMMMd)(
    locale,
  ).format(day);
  final weekday = DateFormat.EEEE(locale).format(day);
  return switch (dueKind(day, today)) {
    DueKind.today => l10n.upcomingDay(text, l10n.dueToday, weekday),
    DueKind.tomorrow => l10n.upcomingDay(text, l10n.dueTomorrow, weekday),
    _ => l10n.groupDay(text, weekday),
  };
}
