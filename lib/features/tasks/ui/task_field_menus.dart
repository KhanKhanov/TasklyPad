import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/data_providers.dart';
import '../../../app/theme/app_palette.dart';
import '../../../domain/models.dart';
import '../../../l10n/app_localizations.dart';
import '../../common/ui/ui_kit.dart';
import 'duration_input.dart';

/// Поле правой колонки панели задачи: подпись и значение. Нажимается всё
/// поле — и подпись, и значение, как в Todoist; при наведении подсвечивается
/// (решение 11 «M4.10a» plans/m4). Без [onTap] — только показ.
class TaskField extends StatelessWidget {
  const TaskField({
    super.key,
    required this.label,
    required this.child,
    this.onTap,
  });

  final String label;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(6),
            hoverColor: palette.textPrimary.withValues(alpha: 0.06),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Подпись мельче и тише значения, чтобы поля не сливались.
                  Text(
                    label,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  DefaultTextStyle.merge(
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    child: child,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Divider(height: 1, color: palette.divider),
        ],
      ),
    );
  }
}

/// Поле «Приоритет»: меню P1–P4 открывается нажатием на всё поле.
class PriorityField extends ConsumerWidget {
  const PriorityField({super.key, required this.task, required this.enabled});

  final Task task;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    Widget item(int p) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.flag, size: 16, color: palette.priority[p - 1]),
        const SizedBox(width: 8),
        Text(l10n.priorityN(p)),
      ],
    );
    return _FieldMenu(
      label: l10n.fieldPriority,
      enabled: enabled,
      items: [
        for (var p = 1; p <= 4; p++)
          (
            child: item(p),
            pick: () => runCommand(
              context,
              () => ref.read(taskCommandsProvider).setPriority(task.id, p),
            ),
          ),
      ],
      child: item(task.priority.clamp(1, 4)),
    );
  }
}

/// Поле «Длительность» — видно всегда, и без срока (help «Set a task
/// duration»: «with or without a date and time»; решение 13А plans/m4):
/// готовые варианты и «Своя длительность…» нажатием на всё поле, крестик
/// рядом со значением убирает.
class DurationField extends ConsumerWidget {
  const DurationField({super.key, required this.task, required this.enabled});

  final Task task;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final current = task.duration;
    void set(TaskDuration? d) => runCommand(
      context,
      () => ref.read(taskCommandsProvider).setDuration(task.id, d),
    );
    Future<void> custom() async {
      final picked = await showDurationDialog(context, current);
      if (picked != null && context.mounted) set(picked.value);
    }

    return _FieldMenu(
      label: l10n.fieldDuration,
      enabled: enabled,
      items: [
        for (final m in durationPresets)
          (
            child: Text(minutesLabel(l10n, m)),
            pick: () => set(TaskDuration(amount: m, unit: 'minute')),
          ),
        (child: Text(l10n.durationCustom), pick: custom),
      ],
      child: current == null
          ? Text(l10n.noDuration)
          : Row(
              children: [
                Flexible(child: Text(durationLabel(l10n, current))),
                if (enabled)
                  IconButton(
                    tooltip: l10n.removeDuration,
                    visualDensity: VisualDensity.compact,
                    iconSize: 16,
                    icon: const Icon(Icons.close),
                    onPressed: () => set(null),
                  ),
              ],
            ),
    );
  }
}

/// Поле с меню под ним: нажатие на поле открывает меню, повторное —
/// закрывает.
class _FieldMenu extends StatelessWidget {
  const _FieldMenu({
    required this.label,
    required this.enabled,
    required this.items,
    required this.child,
  });

  final String label;
  final bool enabled;
  final List<({Widget child, VoidCallback pick})> items;
  final Widget child;

  @override
  Widget build(BuildContext context) => MenuAnchor(
    menuChildren: [
      for (final i in items) MenuItemButton(onPressed: i.pick, child: i.child),
    ],
    builder: (context, controller, _) => TaskField(
      label: label,
      onTap: enabled
          ? () => controller.isOpen ? controller.close() : controller.open()
          : null,
      child: child,
    ),
  );
}
