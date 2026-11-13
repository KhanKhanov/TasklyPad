import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/conflicts.dart';
import '../../../l10n/app_localizations.dart';
import '../../common/ui/close_own_route.dart';
import '../../common/ui/layout.dart';
import '../../settings/state/sync_controller.dart';
import '../state/conflict_marks.dart';
import 'conflict_card.dart';

/// Открыть окно с открытыми карточками сущности [id] поверх текущего экрана
/// или окна (решение 2А «Хода M4.13»): выбор стороны не уводит с задачи.
Future<void> showConflictCards(
  BuildContext context,
  ConflictEntity entity,
  String id,
) => showDialog<void>(
  context: context,
  builder: (_) => _ConflictCardsDialog(entity: entity, id: id),
);

/// Окно карточек: широкий экран — диалог до 640, узкий — на весь экран.
/// Закрывается само, когда карточек не осталось (выбрали или решили на
/// другом устройстве); `Esc` закрывает окно.
class _ConflictCardsDialog extends ConsumerStatefulWidget {
  const _ConflictCardsDialog({required this.entity, required this.id});

  final ConflictEntity entity;
  final String id;

  @override
  ConsumerState<_ConflictCardsDialog> createState() =>
      _ConflictCardsDialogState();
}

class _ConflictCardsDialogState extends ConsumerState<_ConflictCardsDialog> {
  bool _closing = false;

  void _closeOnce() {
    if (_closing) return;
    _closing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) closeOwnRoute(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cards = ref
        .watch(conflictMarksProvider)
        .cardsFor(widget.entity, widget.id);
    if (cards.isEmpty) _closeOnce();
    final devices = ref.watch(syncDevicesProvider).value ?? const [];
    final body = Column(
      children: [
        Row(
          children: [
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                l10n.conflicts,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final card in cards)
                ConflictCardView(
                  key: ValueKey(card.key),
                  card: card,
                  devices: devices,
                ),
            ],
          ),
        ),
      ],
    );
    // Свой ScaffoldMessenger и Scaffold: тосты выбора — внутри окна, а не
    // под его затемнением (как в `TaskDialogLayout`).
    final content = ScaffoldMessenger(
      child: Scaffold(backgroundColor: Colors.transparent, body: body),
    );
    if (MediaQuery.sizeOf(context).width < wideLayoutWidth) {
      return Dialog.fullscreen(child: SafeArea(child: content));
    }
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 640),
        child: content,
      ),
    );
  }
}
