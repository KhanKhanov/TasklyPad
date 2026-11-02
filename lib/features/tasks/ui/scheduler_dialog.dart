import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import 'scheduler_layout.dart';

/// Выбор в планировщике: новый срок ([due]; `null` — без срока) или
/// «Отложить» повторяющуюся задачу ([postpone]).
typedef DuePick = ({Due? due, bool postpone});

/// Планировщик срока, как в Todoist (help «Introduction to recurring
/// dates»): поле «Введите срок», быстрые варианты, «Отложить» у
/// повторяющейся задачи при [canPostpone], календарь, «Время», «Повторить»,
/// «Без срока». Текст в поле заменяет срок вместе с правилом, дата из
/// календаря и быстрых вариантов переносит только вхождение. `null` —
/// пользователь закрыл выбор. Раскладка — [SchedulerLayout]: на компьютере
/// календарь справа, а не под вариантами (решение 1Б «Ход M3.8»).
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

  /// Одно «сейчас» на окно (стенное время): разбор, «Отложить», быстрые
  /// варианты, календарь и «Повторить» считают от одной даты, даже если окно
  /// открыто через полночь.
  late final DateTime _now = ref.read(clockProvider).nowWall();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  /// Язык разбора — язык интерфейса (решение 8А плана M3).
  String get _lang =>
      ParseContext.languageFor(Localizations.localeOf(context).languageCode);

  void _parse(String text) {
    final match = text.trim().isEmpty
        ? null
        : parseDueText(text, ParseContext(now: _now, lang: _lang));
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
    final now = _now;
    final today = DateTime(now.year, now.month, now.day);
    final current = widget.current;
    final typed = _typed;
    final postponed = widget.canPostpone && current != null
        ? _postponed(current, now)
        : null;
    return SchedulerLayout(
      top: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _text,
            autofocus: true,
            decoration: InputDecoration(hintText: l10n.dueInputHint),
            onChanged: _parse,
            // `_typed`, а не значение прошлого кадра: Enter может прийти в
            // одном кадре с последней правкой.
            onSubmitted: (_) {
              if (_typed case final typed?) _done(typed.due);
            },
          ),
        ),
        if (typed != null)
          ListTile(
            dense: true,
            leading: Icon(Icons.event, size: 20, color: palette.accent),
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
        for (final (quick, icon, label) in quickDueOptions(l10n))
          for (final day in [quickDueDate(quick, today)])
            SchedulerOption(
              icon: icon,
              label: label,
              day: day,
              onTap: () => _done(dueOnDate(current, isoDate(day))),
            ),
        if (postponed != null)
          SchedulerOption(
            icon: Icons.update,
            label: l10n.postpone,
            day: parseIsoDate(postponed.date)!,
            onTap: () => Navigator.pop(context, (due: current, postpone: true)),
          ),
      ],
      calendar: SchedulerCalendar(
        shown: parseIsoDate(current?.date ?? '') ?? today,
        today: today,
        onPicked: (day) => _done(dueOnDate(current, isoDate(day))),
      ),
      bottom: SchedulerBottomBar(
        current: current,
        lang: _lang,
        now: now,
        onDone: _done,
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
