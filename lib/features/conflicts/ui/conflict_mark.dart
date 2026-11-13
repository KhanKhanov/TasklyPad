import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_palette.dart';
import '../../../domain/conflicts.dart';
import '../../../l10n/app_localizations.dart';
import '../state/conflict_marks.dart';
import 'conflict_cards_dialog.dart';

/// Спорная ли сущность — для строк, которым нужно решить, добавлять ли чип.
/// Строка берёт один `bool`: перестраивается, только когда он меняется.
bool isInConflict(WidgetRef ref, ConflictEntity entity, String id) =>
    ref.watch(conflictMarksProvider.select((m) => m.has(entity, id)));

/// Пометка «Конфликт» (решение 1Б «Хода M4.13»): значок и подпись цветом
/// предупреждения; [iconOnly] — только значок с подсказкой «Изменено на двух
/// устройствах» для узких строк сайдбара (решение 3А). [onTap] — чип
/// раздела открывает карточки; без него пометка не нажимается. Нет конфликта
/// — пустое место.
class ConflictMark extends ConsumerWidget {
  const ConflictMark({
    super.key,
    required this.entity,
    required this.id,
    this.iconOnly = false,
    this.onTap,
  });

  final ConflictEntity entity;
  final String id;
  final bool iconOnly;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isInConflict(ref, entity, id)) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final color = AppPalette.of(context).warning;
    final icon = Icon(Icons.sync_problem_outlined, size: 13, color: color);
    final mark = iconOnly
        ? Tooltip(message: l10n.conflictMarkTooltip, child: icon)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              icon,
              const SizedBox(width: 3),
              Text(
                l10n.conflictMark,
                style: TextStyle(fontSize: 12, color: color),
              ),
            ],
          );
    if (onTap == null) return mark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Tooltip(message: l10n.conflictMarkTooltip, child: mark),
    );
  }
}

/// Плашка под заголовком окна задачи, проекта или метки: «Изменено на двух
/// устройствах» и «Выбрать» — окно с карточками поверх текущего (решение 2А).
class ConflictBanner extends ConsumerWidget {
  const ConflictBanner({
    super.key,
    required this.entity,
    required this.id,
    this.margin = const EdgeInsets.fromLTRB(16, 8, 16, 0),
  });

  final ConflictEntity entity;
  final String id;

  /// Отступ снаружи: в окне задачи — от краёв, в заголовке экрана — свой.
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isInConflict(ref, entity, id)) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final color = AppPalette.of(context).warning;
    return Container(
      margin: margin,
      padding: const EdgeInsets.fromLTRB(12, 2, 4, 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(Icons.sync_problem_outlined, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.conflictMarkTooltip,
              style: TextStyle(fontSize: 13, color: color),
            ),
          ),
          TextButton(
            onPressed: () => showConflictCards(context, entity, id),
            child: Text(l10n.conflictChoose),
          ),
        ],
      ),
    );
  }
}
