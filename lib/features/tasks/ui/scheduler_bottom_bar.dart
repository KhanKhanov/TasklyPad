import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/data_providers.dart';
import '../../../app/theme/app_palette.dart';
import '../../../domain/models.dart';
import '../../../l10n/app_localizations.dart';
import '../logic/due_dates.dart';
import '../logic/repeat_rules.dart';
import 'custom_repeat_dialog.dart';
import 'due_ui.dart';

/// Низ планировщика: «Время», «Повторить» (готовые варианты и
/// «Пользовательский…»), значок снятия повтора (help: «dismiss icon at the
/// bottom of the scheduler») и «Без срока». Выбор отдаёт новый срок в
/// [onDone].
class SchedulerBottomBar extends ConsumerWidget {
  const SchedulerBottomBar({
    super.key,
    required this.current,
    required this.lang,
    required this.onDone,
  });

  final Due? current;

  /// Язык текста правила: `ru` или `en`.
  final String lang;
  final ValueChanged<Due?> onDone;

  Future<void> _time(BuildContext context, Due current) async {
    if (current.time != null) return onDone(dueWithTime(current, null));
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (time == null || !context.mounted) return;
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    onDone(dueWithTime(current, '$hh:$mm'));
  }

  Future<void> _repeat(BuildContext context, WidgetRef ref, Object pick) async {
    final now = ref.read(clockProvider).nowWall();
    final Due? due = switch (pick) {
      final RepeatPreset preset => dueWithRule(
        current,
        presetRule(preset, repeatAnchor(current, now)),
        lang: lang,
        now: now,
      ),
      _ => await showCustomRepeat(
        context,
        current: current,
        lang: lang,
        now: now,
      ),
    };
    if (due != null && context.mounted) onDone(due);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final anchor = repeatAnchor(current, ref.watch(clockProvider).nowWall());
    final due = current;
    final recurring = due?.isRecurring ?? false;
    // Правило без текста (пришло синхронизацией) — подпись «Повторить», но
    // снять его можно.
    final rule = recurring ? repeatText(context, due!) : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Wrap(
        spacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (due != null)
            TextButton.icon(
              icon: const Icon(Icons.schedule, size: 18),
              label: Text(due.time == null ? l10n.addTime : l10n.removeTime),
              onPressed: () => _time(context, due),
            ),
          PopupMenuButton<Object>(
            tooltip: l10n.repeat,
            onSelected: (pick) => _repeat(context, ref, pick),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: RepeatPreset.daily,
                child: Text(l10n.repeatDaily),
              ),
              PopupMenuItem(
                value: RepeatPreset.weekly,
                child: Text(
                  l10n.repeatWeekly(DateFormat.E(locale).format(anchor)),
                ),
              ),
              PopupMenuItem(
                value: RepeatPreset.monthly,
                child: Text(l10n.repeatMonthly('${anchor.day}')),
              ),
              PopupMenuItem(
                value: RepeatPreset.yearly,
                child: Text(
                  l10n.repeatYearly(DateFormat.MMMd(locale).format(anchor)),
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(value: 'custom', child: Text(l10n.repeatCustom)),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.repeat, size: 18, color: palette.accent),
                  const SizedBox(width: 6),
                  // Правило с окончанием длиннее окна — обрезается.
                  Flexible(
                    child: Text(
                      rule ?? l10n.repeat,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: palette.accent),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (recurring)
            IconButton(
              tooltip: l10n.repeatRemove,
              iconSize: 18,
              icon: const Icon(Icons.close),
              onPressed: () =>
                  onDone(due!.copyWith(rule: null, string: null, lang: null)),
            ),
          if (due != null)
            TextButton.icon(
              icon: const Icon(Icons.block, size: 18),
              label: Text(l10n.noDue),
              onPressed: () => onDone(null),
            ),
        ],
      ),
    );
  }
}
