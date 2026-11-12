import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/data_providers.dart';
import '../../../app/theme/app_palette.dart';
import '../../../domain/models.dart';
import '../../../l10n/app_localizations.dart';
import '../../common/ui/ui_kit.dart';

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

/// Поле «Длительность» (у срока со временем): готовые варианты нажатием на
/// всё поле.
class DurationField extends ConsumerWidget {
  const DurationField({super.key, required this.task, required this.enabled});

  final Task task;
  final bool enabled;

  static const _minutes = [15, 30, 45, 60, 90, 120];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final current = task.duration;
    final text = current == null
        ? l10n.noDuration
        : l10n.durationMinutes(
            current.unit == 'day' ? current.amount * 1440 : current.amount,
          );
    void set(TaskDuration? d) => runCommand(
      context,
      () => ref.read(taskCommandsProvider).setDuration(task.id, d),
    );
    return _FieldMenu(
      label: l10n.fieldDuration,
      enabled: enabled,
      items: [
        (child: Text(l10n.noDuration), pick: () => set(null)),
        for (final m in _minutes)
          (
            child: Text(l10n.durationMinutes(m)),
            pick: () => set(TaskDuration(amount: m, unit: 'minute')),
          ),
      ],
      child: Text(text),
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
