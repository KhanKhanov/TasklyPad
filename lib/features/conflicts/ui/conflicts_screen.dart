import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../../../app/data_providers.dart';
import '../../../app/theme/app_palette.dart';
import '../../../l10n/app_localizations.dart';
import '../../projects/ui/project_screen.dart';
import '../../settings/state/sync_controller.dart';
import 'conflict_card.dart';

/// Экран «Конфликты» (наше дополнение, в Todoist нет; SYNC_DESIGN
/// «Конфликты: решает пользователь»): параллельные правки карточками, новые
/// сверху; выбор стороны закрывает карточку на всех устройствах.
class ConflictsScreen extends ConsumerWidget {
  const ConflictsScreen({super.key});

  static final Logger _logger = Logger();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    // Имена устройств — из папки синхронизации; без неё — конец id.
    final devices = ref.watch(syncDevicesProvider).value ?? const [];
    final body = switch (ref.watch(openConflictsProvider)) {
      AsyncData(value: final cards) when cards.isEmpty => [
        Text(
          l10n.conflictsEmpty,
          style: TextStyle(color: palette.textSecondary),
        ),
      ],
      AsyncData(value: final cards) => [
        for (final card in cards)
          ConflictCardView(
            key: ValueKey(card.key),
            card: card,
            devices: devices,
          ),
      ],
      AsyncError(:final error, :final stackTrace) => [
        _error(l10n, palette, error, stackTrace),
      ],
      _ => const <Widget>[],
    };
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: contentMaxWidth),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(32, 8, 32, 48),
          children: [
            Text(
              l10n.conflicts,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 26,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.conflictsHint,
              style: TextStyle(color: palette.textSecondary),
            ),
            const SizedBox(height: 24),
            ...body,
          ],
        ),
      ),
    );
  }

  Widget _error(
    AppLocalizations l10n,
    AppPalette palette,
    Object error,
    StackTrace stack,
  ) {
    _logger.e('Конфликты не загрузились', error: error, stackTrace: stack);
    return Text(
      l10n.loadError('$error'),
      style: TextStyle(color: palette.danger),
    );
  }
}
