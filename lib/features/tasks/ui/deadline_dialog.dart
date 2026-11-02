import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/data_providers.dart';
import '../../../app/theme/app_palette.dart';
import '../../../l10n/app_localizations.dart';
import '../../../nlp/parse_context.dart';
import '../../../nlp/quick_add.dart';
import '../logic/due_dates.dart';
import 'due_ui.dart';
import 'scheduler_layout.dart';

/// Выбор дедлайна: поле «Введите дедлайн», быстрые варианты, календарь и
/// «Без дедлайна» — в той же раскладке, что планировщик срока (решение 1Б
/// «Ход M3.8»; help «Introduction to deadlines»: поле сверху и календарь).
/// Дедлайн — только дата: время из текста не берётся, повторение — не
/// дедлайн. `null` — выбор закрыт.
Future<({String? date})?> pickDeadline(
  BuildContext context,
  WidgetRef ref,
  String? current,
) => showDialog<({String? date})>(
  context: context,
  builder: (_) => _DeadlineScheduler(current: current),
);

class _DeadlineScheduler extends ConsumerStatefulWidget {
  const _DeadlineScheduler({required this.current});

  final String? current;

  @override
  ConsumerState<_DeadlineScheduler> createState() => _DeadlineSchedulerState();
}

class _DeadlineSchedulerState extends ConsumerState<_DeadlineScheduler> {
  final TextEditingController _text = TextEditingController();

  /// Разобранный текст поля; `null` — поле пусто или это не дата.
  ({String? date})? _typed;

  /// Одно «сейчас» на окно (стенное время), как у планировщика срока.
  late final DateTime _now = ref.read(clockProvider).nowWall();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _parse(String text) {
    final lang = ParseContext.languageFor(
      Localizations.localeOf(context).languageCode,
    );
    final match = text.trim().isEmpty
        ? null
        : parseDueText(text, ParseContext(now: _now, lang: lang));
    setState(() {
      _typed = switch (match) {
        null => null,
        _ when match.noDate => (date: null),
        _ => switch (match.due) {
          final due? when !due.isRecurring => (date: due.date),
          _ => null,
        },
      };
    });
  }

  void _done(String? date) => Navigator.pop(context, (date: date));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final today = DateTime(_now.year, _now.month, _now.day);
    final current = widget.current;
    final typed = _typed;
    return SchedulerLayout(
      top: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _text,
            autofocus: true,
            decoration: InputDecoration(hintText: l10n.deadlineInputHint),
            onChanged: _parse,
            onSubmitted: (_) {
              if (_typed case final typed?) _done(typed.date);
            },
          ),
        ),
        if (typed != null)
          ListTile(
            dense: true,
            leading: Icon(Icons.outlined_flag, size: 20, color: palette.accent),
            title: Text(
              typed.date == null
                  ? l10n.noDeadline
                  : dueLabel(context, typed.date!, null, today).text,
            ),
            onTap: () => _done(typed.date),
          ),
        Divider(color: palette.divider, height: 8),
        for (final (quick, icon, label) in quickDueOptions(l10n))
          for (final day in [quickDueDate(quick, today)])
            SchedulerOption(
              icon: icon,
              label: label,
              day: day,
              onTap: () => _done(isoDate(day)),
            ),
      ],
      calendar: SchedulerCalendar(
        shown: parseIsoDate(current ?? '') ?? today,
        today: today,
        onPicked: (day) => _done(isoDate(day)),
      ),
      bottom: current == null
          ? null
          : Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.block, size: 18),
                  label: Text(l10n.noDeadline),
                  onPressed: () => _done(null),
                ),
              ),
            ),
    );
  }
}
