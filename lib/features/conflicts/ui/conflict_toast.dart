import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';

import '../../../app/sync_providers.dart';
import '../../../l10n/app_localizations.dart';
import '../state/conflict_notices.dart';
import 'conflict_values.dart';

/// Сколько висит тост о конфликте: дольше «Отменить» — его надо успеть
/// прочитать и решить, открывать ли.
const Duration conflictToastDuration = Duration(seconds: 10);

/// Говорит о новых конфликтах ([ConflictNotices]): окно на переднем плане —
/// тост внутри окна с «Открыть», иначе — уведомление ОС (решение 15 плана
/// M2), клик по которому показывает окно и открывает «Конфликты».
class ConflictNoticeListener extends ConsumerStatefulWidget {
  const ConflictNoticeListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ConflictNoticeListener> createState() =>
      _ConflictNoticeListenerState();
}

class _ConflictNoticeListenerState
    extends ConsumerState<ConflictNoticeListener> {
  static final Logger _log = Logger();

  StreamSubscription<void>? _opened;

  @override
  void initState() {
    super.initState();
    final notifier = ref.read(conflictNotificationsProvider);
    _opened = notifier.opened.listen((_) {
      if (mounted) GoRouter.of(context).go('/conflicts');
    });
    unawaited(
      notifier.start().catchError((Object error, StackTrace stackTrace) {
        _log.e(
          'Уведомления ОС не подготовлены',
          error: error,
          stackTrace: stackTrace,
        );
      }),
    );
  }

  @override
  void dispose() {
    unawaited(_opened?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(conflictNoticesProvider, (_, notice) {
      if (notice != null) unawaited(_notify(notice));
    });
    return widget.child;
  }

  Future<void> _notify(ConflictNotice notice) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final text = conflictNoticeText(l10n, notice.cards);
    final notifier = ref.read(conflictNotificationsProvider);
    try {
      if (!await notifier.isAppActive()) {
        await notifier.show(title: l10n.conflictToastTitle, body: text);
        return;
      }
    } on Object catch (error, stackTrace) {
      // Уведомление ОС не вышло — тост в окне всё равно скажет.
      _log.e(
        'Уведомление о конфликте не показано',
        error: error,
        stackTrace: stackTrace,
      );
    }
    if (!messenger.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(text),
        duration: conflictToastDuration,
        behavior: SnackBarBehavior.floating,
        width: 360,
        action: SnackBarAction(
          label: l10n.conflictOpen,
          onPressed: () => router.go('/conflicts'),
        ),
      ),
    );
  }
}
