import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_palette.dart';
import '../../../l10n/app_localizations.dart';
import '../../../nlp/rule_text.dart';
import '../logic/repeat_rules.dart';

/// Поле окна «Пользовательский…»: подпись и значение под ней.
class RepeatField extends StatelessWidget {
  const RepeatField({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

/// «В»: дни недели у недели, число или день недели по номеру у месяца, дата
/// срока у года. Дни считаются от даты [anchor].
class RepeatOnField extends StatelessWidget {
  const RepeatOnField({
    super.key,
    required this.value,
    required this.anchor,
    required this.lang,
    required this.onChanged,
  });

  final CustomRepeat value;
  final DateTime anchor;

  /// Язык текста правила: `ru` или `en`.
  final String lang;
  final ValueChanged<CustomRepeat> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final v = value;
    // Неделя в Todoist по умолчанию начинается с понедельника.
    final monday = DateTime(2026, 10, 19);
    return RepeatField(
      label: l10n.repeatOn,
      child: switch (v.unit) {
        RepeatUnit.week => Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (var d = DateTime.monday; d <= DateTime.sunday; d++)
              FilterChip(
                label: Text(
                  DateFormat.E(locale)
                      .format(monday.add(Duration(days: d - 1))),
                ),
                // Дни недели текстом — только у шага в 1–2 недели.
                selected: v.interval <= 2 && v.weekdays.contains(d),
                onSelected: v.interval > 2
                    ? null
                    : (on) {
                        final days = {...v.weekdays};
                        on ? days.add(d) : days.remove(d);
                        if (days.isNotEmpty) {
                          onChanged(v.copyWith(weekdays: days));
                        }
                      },
              ),
          ],
        ),
        RepeatUnit.month => SegmentedButton<MonthDay>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: MonthDay.date,
              label: Text(l10n.repeatMonthDate(anchor.day)),
            ),
            ButtonSegment(
              value: MonthDay.weekday,
              label: Text(
                ruleText(
                      customRule(
                        const CustomRepeat(
                          unit: RepeatUnit.month,
                          monthDay: MonthDay.weekday,
                        ),
                        anchor,
                      ),
                      lang,
                    ) ??
                    '',
              ),
            ),
          ],
          selected: {v.monthDay},
          onSelectionChanged: (s) => onChanged(v.copyWith(monthDay: s.single)),
        ),
        _ => Text(DateFormat.MMMd(locale).format(anchor)),
      },
    );
  }
}
