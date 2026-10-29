import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/data_providers.dart';
import '../../../app/theme/app_palette.dart';
import '../../../domain/conflicts.dart';
import '../../../l10n/app_localizations.dart';
import '../../../domain/sync_status.dart';
import '../../common/ui/ui_kit.dart';
import '../../settings/ui/sync_section.dart';
import 'conflict_values.dart';

/// Ширина карточки, начиная с которой стороны стоят рядом, а не одна под
/// другой.
const double _sideBySideWidth = 560;

/// Карточка конфликта: что за сущность, две стороны с устройством, временем и
/// значениями, кнопка выбора у каждой; если поле правили после конфликта —
/// действующие значения и «Оставить текущее» (решение 3Б).
class ConflictCardView extends ConsumerWidget {
  const ConflictCardView({
    super.key,
    required this.card,
    required this.devices,
  });

  final ConflictCard card;

  /// Устройства из папки синхронизации — для имён сторон.
  final List<SyncDevice> devices;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final sides = [
      for (final side in [card.older, card.newer])
        _SideView(card: card, side: side, devices: devices),
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.raised,
        border: Border.all(color: palette.outline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            conflictEntityTitle(l10n, card),
            style: TextStyle(
              color: palette.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) =>
                constraints.maxWidth >= _sideBySideWidth
                ? IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: sides[0]),
                        const SizedBox(width: 12),
                        Expanded(child: sides[1]),
                      ],
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [sides[0], const SizedBox(height: 12), sides[1]],
                  ),
          ),
          if (card.current.isNotEmpty) _CurrentView(card: card),
        ],
      ),
    );
  }
}

/// Одна сторона: устройство и время, значения, кнопка выбора.
class _SideView extends ConsumerWidget {
  const _SideView({
    required this.card,
    required this.side,
    required this.devices,
  });

  final ConflictCard card;
  final ConflictSide side;
  final List<SyncDevice> devices;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final action = !card.isDelete
        ? l10n.conflictKeepThis
        : side.deletes
        ? l10n.conflictKeepDeleted
        : l10n.conflictRestore;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: side.isCurrent ? palette.accent : palette.divider,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            conflictDevice(l10n, side, devices),
            style: TextStyle(color: palette.textPrimary, fontSize: 13),
          ),
          Text(
            formatSyncTime(context, side.at),
            style: TextStyle(color: palette.textSecondary, fontSize: 12),
          ),
          if (side.isCurrent)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                l10n.conflictActive,
                style: TextStyle(
                  color: palette.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(height: 8),
          _Values(entity: card.entity, values: _shown(l10n)),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => _choose(context, ref),
            child: Text(action),
          ),
        ],
      ),
    );
  }

  /// У удаления — «Удалено»; у правки без показываемых полей (метка задачи
  /// записана заново целиком) — «Изменено».
  List<ConflictValue> _shown(AppLocalizations l10n) => side.values.isNotEmpty
      ? side.values
      : [
          ConflictValue(
            field: ConflictField.other,
            key: '',
            value: l10n.valueEdited,
          ),
        ];

  Future<void> _choose(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    // Удаление сейчас не действует (восстановили позже) — выбор удалит
    // заново вместе со всем внутри: как любое удаление в Todoist, только
    // после подтверждения.
    if (side.deletes && !side.isCurrent) {
      final ok = await confirmAction(
        context,
        title: l10n.conflictDeleteAgainTitle,
        body: l10n.conflictDeleteAgainBody(conflictEntityTitle(l10n, card)),
        action: l10n.conflictKeepDeleted,
        danger: true,
      );
      if (!ok || !context.mounted) return;
    }
    var hidden = false;
    await runCommand(context, () async {
      hidden = await ref.read(conflictCommandsProvider).keep(card, side);
    });
    if (hidden && messenger.mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.conflictRestoredHidden)),
      );
    }
  }
}

/// Значения, действующие сейчас, и «Оставить текущее».
class _CurrentView extends ConsumerWidget {
  const _CurrentView({required this.card});

  final ConflictCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.conflictCurrent,
                  style: TextStyle(color: palette.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 4),
                _Values(entity: card.entity, values: card.current),
              ],
            ),
          ),
          TextButton(
            onPressed: () => runCommand(
              context,
              () => ref.read(conflictCommandsProvider).keepCurrent(card),
            ),
            child: Text(l10n.conflictKeepCurrent),
          ),
        ],
      ),
    );
  }
}

/// Строки «Поле: значение»; у удаления и правки без полей — только значение.
class _Values extends StatelessWidget {
  const _Values({required this.entity, required this.values});

  final ConflictEntity entity;
  final List<ConflictValue> values;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final v in values)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text.rich(
              TextSpan(
                children: [
                  if (v.field != ConflictField.deleted && v.key.isNotEmpty)
                    TextSpan(
                      text: '${conflictFieldTitle(l10n, v)}: ',
                      style: TextStyle(color: palette.textSecondary),
                    ),
                  TextSpan(
                    text: v.key.isEmpty
                        ? '${v.value}'
                        : conflictValueText(l10n, locale, entity, v),
                  ),
                ],
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: palette.textPrimary, fontSize: 13),
            ),
          ),
      ],
    );
  }
}
