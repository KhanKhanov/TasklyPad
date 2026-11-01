import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_palette.dart';
import '../../../domain/models.dart';
import '../../../l10n/app_localizations.dart';
import '../logic/repeat_rules.dart';
import 'custom_repeat_parts.dart';

/// Окно «Пользовательский…» (help «Introduction to recurring dates»: Based
/// on, Every, On, Ends). Открывается значениями правила [current], если окно
/// их выражает. Возвращает срок с новым правилом; `null` — «Отмена».
Future<Due?> showCustomRepeat(
  BuildContext context, {
  required Due? current,
  required String lang,
  required DateTime now,
}) => showDialog<Due>(
  context: context,
  builder: (_) => _CustomRepeat(current: current, lang: lang, now: now),
);

class _CustomRepeat extends StatefulWidget {
  const _CustomRepeat({
    required this.current,
    required this.lang,
    required this.now,
  });

  final Due? current;
  final String lang;

  /// Стенное время устройства в UTC-обёртке.
  final DateTime now;

  @override
  State<_CustomRepeat> createState() => _CustomRepeatState();
}

class _CustomRepeatState extends State<_CustomRepeat> {
  late final DateTime _anchor = repeatAnchor(widget.current, widget.now);
  late CustomRepeat _value = customFromRule(widget.current?.rule, _anchor);
  late final TextEditingController _interval = TextEditingController(
    text: '${_value.interval}',
  );

  /// В поле «Каждые» число от 1.
  bool _intervalOk = true;

  @override
  void dispose() {
    _interval.dispose();
    super.dispose();
  }

  void _set(CustomRepeat value) => setState(() => _value = value);

  Future<void> _pickUntil() async {
    final day = await showDatePicker(
      context: context,
      initialDate: _value.until ?? _anchor,
      firstDate: DateTime(_anchor.year - 1),
      lastDate: DateTime(_anchor.year + 20),
    );
    if (day != null) _set(_value.copyWith(until: (date: day)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final v = _value;
    Due? withRule(CustomRepeat c) => dueWithRule(
      widget.current,
      customRule(c, _anchor),
      lang: widget.lang,
      now: widget.now,
    );
    // Пустое поле «Каждые» или 0 — сохранять нечего: старый шаг записался
    // бы молча.
    final due = _intervalOk ? withRule(v) : null;
    // Причина — по тому, спасает ли правило отказ от окончания: иначе любое
    // правило без текстовой формы выглядело бы «окончанием раньше начала».
    final error = due != null || !_intervalOk
        ? null
        : v.until != null && withRule(v.copyWith(until: (date: null))) != null
        ? l10n.repeatEndsBeforeStart
        : l10n.repeatUnsupported;
    return AlertDialog(
      title: Text(l10n.repeatCustomTitle),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RepeatField(
              label: l10n.repeatBasedOn,
              child: SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: false, label: Text(l10n.repeatFromDue)),
                  ButtonSegment(
                    value: true,
                    label: Text(l10n.repeatFromCompletion),
                  ),
                ],
                selected: {v.fromCompletion},
                onSelectionChanged: (s) =>
                    _set(v.copyWith(fromCompletion: s.single)),
              ),
            ),
            RepeatField(
              label: l10n.repeatEvery,
              child: Row(
                children: [
                  SizedBox(
                    width: 64,
                    child: TextField(
                      controller: _interval,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(3),
                      ],
                      decoration: const InputDecoration(isDense: true),
                      onChanged: (t) {
                        final n = int.tryParse(t);
                        setState(() {
                          _intervalOk = n != null && n >= 1;
                          if (_intervalOk) _value = v.copyWith(interval: n);
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<RepeatUnit>(
                    value: v.unit,
                    onChanged: (u) {
                      if (u == null) return;
                      // К неделе — отмечен день даты срока, как в правиле.
                      _set(
                        v.copyWith(
                          unit: u,
                          weekdays: v.weekdays.isEmpty
                              ? {_anchor.weekday}
                              : null,
                        ),
                      );
                    },
                    items: [
                      for (final (u, name) in [
                        (RepeatUnit.day, l10n.repeatUnitDay),
                        (RepeatUnit.week, l10n.repeatUnitWeek),
                        (RepeatUnit.month, l10n.repeatUnitMonth),
                        (RepeatUnit.year, l10n.repeatUnitYear),
                      ])
                        DropdownMenuItem(
                          value: u,
                          child: Text(name(v.interval)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (v.unit != RepeatUnit.day)
              RepeatOnField(
                value: v,
                anchor: _anchor,
                lang: widget.lang,
                onChanged: _set,
              ),
            RepeatField(
              label: l10n.repeatEnds,
              child: Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SegmentedButton<bool>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(
                        value: false,
                        label: Text(l10n.repeatNever),
                      ),
                      ButtonSegment(
                        value: true,
                        label: Text(l10n.repeatEndsOn),
                      ),
                    ],
                    selected: {v.until != null},
                    onSelectionChanged: (s) => s.single
                        ? _pickUntil()
                        : _set(v.copyWith(until: (date: null))),
                  ),
                  if (v.until case final until?)
                    TextButton(
                      onPressed: _pickUntil,
                      child: Text(DateFormat.yMMMd(locale).format(until)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              due?.string ?? error ?? '',
              style: TextStyle(
                color: due == null ? palette.danger : palette.textSecondary,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: due == null ? null : () => Navigator.pop(context, due),
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }
}
