import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/data_providers.dart';
import '../../../app/theme/app_palette.dart';
import '../../../domain/models.dart';
import '../../../domain/rules.dart';
import '../../../l10n/app_localizations.dart';
import '../../../nlp/parse_context.dart';
import '../../../nlp/quick_add.dart';
import '../logic/due_dates.dart';
import '../logic/task_commands.dart';
import 'due_ui.dart';
import 'scheduler_bottom_bar.dart';

/// Выбор в планировщике: новый срок ([due]; `null` — без срока) или
/// «Отложить» повторяющуюся задачу ([postpone]).
typedef DuePick = ({Due? due, bool postpone});

/// Планировщик срока, как в Todoist (help «Introduction to recurring
/// dates»): поле «Введите срок», быстрые варианты, «Отложить» у
/// повторяющейся задачи при [canPostpone], календарь, «Время», «Повторить»,
/// «Без срока». Текст в поле заменяет срок вместе с правилом, дата из
/// календаря и быстрых вариантов переносит только вхождение. `null` —
/// пользователь закрыл выбор.
Future<DuePick?> pickDue(
  BuildContext context,
  WidgetRef ref,
  Due? current, {
  bool canPostpone = false,
}) => showDialog<DuePick>(
  context: context,
  builder: (_) => _Scheduler(current: current, canPostpone: canPostpone),
);

class _Scheduler extends ConsumerStatefulWidget {
  const _Scheduler({required this.current, required this.canPostpone});

  final Due? current;
  final bool canPostpone;

  @override
  ConsumerState<_Scheduler> createState() => _SchedulerState();
}

class _SchedulerState extends ConsumerState<_Scheduler> {
  final TextEditingController _text = TextEditingController();

  /// Разобранный текст поля; `null` — поле пусто или это не срок.
  ({Due? due})? _typed;

  /// Календарь только что сменил месяц (листание или выбор года) — до
  /// конца текущего вызова; см. `onDisplayedMonthChanged`.
  bool _monthChanged = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  /// Язык разбора — язык интерфейса (решение 8А плана M3).
  String get _lang {
    final code = Localizations.localeOf(context).languageCode;
    return ParseContext.supportedLanguages.contains(code) ? code : 'en';
  }

  void _parse(String text) {
    final match = text.trim().isEmpty
        ? null
        : parseDueText(
            text,
            ParseContext(now: ref.read(clockProvider).nowWall(), lang: _lang),
          );
    setState(() {
      _typed = match == null || (match.due == null && !match.noDate)
          ? null
          : (due: match.noDate ? null : match.due);
    });
  }

  void _done(Due? due) => Navigator.pop(context, (due: due, postpone: false));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    // Одно «сейчас» на окно: разбор, «Отложить», быстрые варианты и
    // календарь считают от одной даты.
    final now = ref.watch(clockProvider).nowWall();
    final today = DateTime(now.year, now.month, now.day);
    final current = widget.current;
    final typed = _typed;
    final shown = parseIsoDate(current?.date ?? '') ?? today;
    // Срок вне обычного диапазона (пришёл синхронизацией или импортом) не
    // должен ломать календарь: границы расширяются до него.
    final first = DateTime(today.year - 5);
    final last = DateTime(today.year + 20);
    final postponed = widget.canPostpone && current != null
        ? _postponed(current, now)
        : null;
    Widget option(IconData icon, String label, DateTime day, VoidCallback on) =>
        ListTile(
          dense: true,
          leading: Icon(icon, size: 20, color: palette.textSecondary),
          title: Text(label),
          trailing: Text(
            DateFormat.E(locale).format(day),
            style: TextStyle(color: palette.textSecondary, fontSize: 12),
          ),
          onTap: on,
        );
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        // Низ с «Повторить» закреплён: в невысоком окне прокручивается
        // только верх с календарём, а не прячется под край весь низ.
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: TextField(
                        controller: _text,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: l10n.dueInputHint,
                        ),
                        onChanged: _parse,
                        // `_typed`, а не значение прошлого кадра: Enter может
                        // прийти в одном кадре с последней правкой.
                        onSubmitted: (_) {
                          if (_typed case final typed?) _done(typed.due);
                        },
                      ),
                    ),
                    if (typed != null)
                      ListTile(
                        dense: true,
                        leading: Icon(
                          Icons.event,
                          size: 20,
                          color: palette.accent,
                        ),
                        title: Text(
                          typed.due == null
                              ? l10n.noDue
                              : dueLabel(
                                  context,
                                  typed.due!.date,
                                  typed.due!.time,
                                  today,
                                ).text,
                        ),
                        subtitle: switch (typed.due) {
                          final due? when due.isRecurring => Text(
                            repeatText(context, due) ?? '',
                          ),
                          _ => null,
                        },
                        onTap: () => _done(typed.due),
                      ),
                    Divider(color: palette.divider, height: 8),
                    for (final (quick, icon, label) in [
                      (QuickDue.today, Icons.today_outlined, l10n.dueToday),
                      (
                        QuickDue.tomorrow,
                        Icons.wb_sunny_outlined,
                        l10n.dueTomorrow,
                      ),
                      (
                        QuickDue.weekend,
                        Icons.weekend_outlined,
                        l10n.dueWeekend,
                      ),
                      (
                        QuickDue.nextWeek,
                        Icons.arrow_forward,
                        l10n.dueNextWeek,
                      ),
                    ])
                      for (final day in [quickDueDate(quick, today)])
                        option(
                          icon,
                          label,
                          day,
                          () => _done(dueOnDate(current, isoDate(day))),
                        ),
                    if (postponed != null)
                      for (final day in [parseIsoDate(postponed.date)!])
                        option(
                          Icons.update,
                          l10n.postpone,
                          day,
                          () => Navigator.pop(context, (
                            due: current,
                            postpone: true,
                          )),
                        ),
                    Divider(color: palette.divider, height: 8),
                    CalendarDatePicker(
                      initialDate: shown,
                      currentDate: today,
                      firstDate: shown.isBefore(first) ? shown : first,
                      lastDate: shown.isAfter(last) ? shown : last,
                      // Выбор года Flutter сообщает и сменой месяца, и
                      // «выбранной датой» в том же вызове — это переход по
                      // календарю, а не новый срок: окно остаётся открытым.
                      onDisplayedMonthChanged: (_) {
                        _monthChanged = true;
                        scheduleMicrotask(() => _monthChanged = false);
                      },
                      onDateChanged: (day) {
                        if (!_monthChanged) {
                          _done(dueOnDate(current, isoDate(day)));
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            Divider(color: palette.divider, height: 8),
            SchedulerBottomBar(current: current, lang: _lang, onDone: _done),
          ],
        ),
      ),
    );
  }

  /// Срок после «Отложить»; `null` — переносить некуда (серия закончилась)
  /// или правило битое: тогда пункта нет, а не тихий отказ.
  static Due? _postponed(Due current, DateTime now) {
    if (!current.isRecurring) return null;
    try {
      return TaskCommands.postponedDue(current, now);
    } on CommandRejected {
      return null;
    }
  }
}
