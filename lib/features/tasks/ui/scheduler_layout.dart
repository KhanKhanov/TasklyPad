import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_palette.dart';
import '../../../l10n/app_localizations.dart';
import '../logic/due_dates.dart';

/// Ширина экрана, с которой окно выбора даты раскладывается в два столбца.
const double schedulerWideScreen = 760;

const double _leftWidth = 300;
const double _calendarWidth = 340;

/// Раскладка окон выбора срока и дедлайна — одна на оба (решение 1Б «Ход
/// M3.8»): на широком экране поле и быстрые варианты слева, календарь справа,
/// низ во всю ширину; на узком (телефон) — всё в столбец. Низ закреплён: в
/// невысоком окне прокручивается только верх.
class SchedulerLayout extends StatelessWidget {
  const SchedulerLayout({
    super.key,
    required this.top,
    required this.calendar,
    this.bottom,
  });

  /// Поле ввода, распознанное значение и быстрые варианты.
  final List<Widget> top;
  final Widget calendar;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final wide = MediaQuery.sizeOf(context).width >= schedulerWideScreen;
    Widget column(List<Widget> children) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
    // Без `IntrinsicHeight`: календарь (PageView) не умеет считать свою
    // высоту заранее — граница столбцов рисуется рамкой календаря.
    final body = wide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: _leftWidth, child: column(top)),
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(left: BorderSide(color: palette.divider)),
                ),
                child: SizedBox(width: _calendarWidth, child: calendar),
              ),
            ],
          )
        : column([
            ...top,
            Divider(color: palette.divider, height: 8),
            calendar,
          ]);
    final bottom = this.bottom;
    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: wide ? _leftWidth + _calendarWidth + 1 : _calendarWidth,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(child: SingleChildScrollView(child: body)),
            if (bottom != null) ...[
              Divider(color: palette.divider, height: 8),
              bottom,
            ],
          ],
        ),
      ),
    );
  }
}

/// Быстрый вариант даты: значок, подпись, день недели справа.
class SchedulerOption extends StatelessWidget {
  const SchedulerOption({
    super.key,
    required this.icon,
    required this.label,
    required this.day,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final DateTime day;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 20, color: palette.textSecondary),
      title: Text(label),
      trailing: Text(
        DateFormat.E(locale).format(day),
        style: TextStyle(color: palette.textSecondary, fontSize: 12),
      ),
      onTap: onTap,
    );
  }
}

/// Календарь окна выбора даты: нажатый день — в [onPicked]. Дата вне обычного
/// диапазона (пришла синхронизацией или импортом) календарь не ломает:
/// границы расширяются до неё.
class SchedulerCalendar extends StatefulWidget {
  const SchedulerCalendar({
    super.key,
    required this.shown,
    required this.today,
    required this.onPicked,
  });

  final DateTime shown;
  final DateTime today;
  final ValueChanged<DateTime> onPicked;

  @override
  State<SchedulerCalendar> createState() => _SchedulerCalendarState();
}

class _SchedulerCalendarState extends State<SchedulerCalendar> {
  /// Календарь только что сменил месяц (листание или выбор года) — до
  /// конца текущего вызова; см. `onDisplayedMonthChanged`.
  bool _monthChanged = false;

  @override
  Widget build(BuildContext context) {
    final shown = widget.shown;
    final first = DateTime(widget.today.year - 5);
    final last = DateTime(widget.today.year + 20);
    return CalendarDatePicker(
      initialDate: shown,
      currentDate: widget.today,
      firstDate: shown.isBefore(first) ? shown : first,
      lastDate: shown.isAfter(last) ? shown : last,
      // Выбор года Flutter сообщает и сменой месяца, и «выбранной датой» в
      // том же вызове — это переход по календарю, а не новая дата: окно
      // остаётся открытым.
      onDisplayedMonthChanged: (_) {
        _monthChanged = true;
        scheduleMicrotask(() => _monthChanged = false);
      },
      onDateChanged: (day) {
        if (!_monthChanged) widget.onPicked(day);
      },
    );
  }
}

/// Быстрые варианты обоих окон: «Сегодня», «Завтра», «На выходных»,
/// «Следующая неделя».
List<(QuickDue, IconData, String)> quickDueOptions(AppLocalizations l10n) => [
  (QuickDue.today, Icons.today_outlined, l10n.dueToday),
  (QuickDue.tomorrow, Icons.wb_sunny_outlined, l10n.dueTomorrow),
  (QuickDue.weekend, Icons.weekend_outlined, l10n.dueWeekend),
  (QuickDue.nextWeek, Icons.arrow_forward, l10n.dueNextWeek),
];
