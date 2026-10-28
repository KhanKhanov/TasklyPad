import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/data_providers.dart';
import '../../../domain/conflicts.dart';
import '../../settings/state/sync_controller.dart';

part 'conflict_notices.g.dart';

/// Новые конфликты, о которых пора сказать пользователю.
@immutable
final class ConflictNotice {
  const ConflictNotice(this.cards);

  final List<ConflictCard> cards;
}

/// Ищет новые конфликты по таблице конфликтов, а не по отчёту прохода (О-9):
/// после каждого прохода и смены папки — удачных или нет; при запуске —
/// после первого прохода, а без папки — как только настройки прочитаны.
/// Не на каждое изменение таблицы: проход — несколько транзакций, и конфликт,
/// который разрешит следующий чанк того же прохода, дал бы ложное
/// уведомление. Каждое новое состояние — повод уведомить (оболочка).
@Riverpod(keepAlive: true)
class ConflictNotices extends _$ConflictNotices {
  static final Logger _log = Logger();

  Future<void> _queue = Future.value();

  @override
  ConflictNotice? build() {
    ref.listen(
      syncControllerProvider.select(
        (s) =>
            (loaded: s.loaded, noFolder: s.folder == null, running: s.running),
      ),
      (was, now) {
        final passEnded = was != null && was.running && !now.running;
        // Уже загружено к моменту подписки, или загрузилось без папки —
        // прохода, после которого проверить, не будет.
        final idleAtStart =
            now.loaded &&
            !now.running &&
            (was == null || (!was.loaded && now.noFolder));
        if (passEnded || idleAtStart) unawaited(check());
      },
      fireImmediately: true,
    );
    return null;
  }

  /// Проверить сейчас. Проверки идут по очереди, чтобы одна карточка не
  /// дала двух уведомлений.
  Future<void> check() => _queue = _queue.then((_) => _check());

  Future<void> _check() async {
    if (!ref.mounted) return;
    try {
      final cards = await ref.read(conflictRepositoryProvider).takeUnnotified();
      if (cards.isNotEmpty && ref.mounted) state = ConflictNotice(cards);
    } on Object catch (error, stackTrace) {
      // Пункт «Конфликты» в сайдбаре читает таблицу сам — он не пропадёт.
      _log.e(
        'Новые конфликты не прочитаны',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
