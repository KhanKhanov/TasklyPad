import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';

import '../../../app/data_providers.dart';
import '../../../app/sync_providers.dart';
import '../../../l10n/app_localizations.dart';
import '../state/conflict_notices.dart';
import 'conflict_values.dart';
import 'conflicts_navigation.dart';

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

  /// Тост на экране (не в очереди за другим тостом): закрывается, как только
  /// нерешённых конфликтов не осталось — выбор мог быть сделан и на другом
  /// устройстве. Закрыть можно только текущий тост: `close` у тоста в
  /// очереди закрыл бы чужой («Отменить»).
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _toast;

  @override
  void initState() {
    super.initState();
    final notifier = ref.read(conflictNotificationsProvider);
    _opened = notifier.opened.listen((_) {
      if (mounted) showConflictsScreen(GoRouter.of(context));
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
    // Последний конфликт решён (здесь или на другом устройстве) — тост и
    // уведомления ОС о нём больше не нужны. Первое значение тоже: конфликт
    // могли решить на другом устройстве, пока приложение было закрыто.
    ref.listen(openConflictsProvider, (was, cards) {
      if (!(cards.value?.isEmpty ?? false)) return;
      _toast?.close();
      final before = was?.value;
      if (before == null || before.isNotEmpty) unawaited(_clearSystem());
    });
    return widget.child;
  }

  Future<void> _clearSystem() async {
    try {
      await ref.read(conflictNotificationsProvider).clear();
    } on Object catch (error, stackTrace) {
      // Уведомление останется в центре уведомлений — пользователь закроет
      // его сам; конфликтов при этом уже нет.
      _log.e(
        'Уведомления о конфликтах не убраны',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _notify(ConflictNotice notice) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final text = conflictNoticeText(
      l10n,
      notice.cards,
      mobile: Theme.of(context).platform == TargetPlatform.android,
    );
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
    late final ScaffoldFeatureController<SnackBar, SnackBarClosedReason> toast;
    toast = messenger.showSnackBar(
      SnackBar(
        content: Text(text),
        duration: conflictToastDuration,
        // Тост с кнопкой Flutter по умолчанию держит, пока его не закроют.
        persist: false,
        behavior: SnackBarBehavior.floating,
        width: 360,
        // Тост мог ждать в очереди, пока конфликт решали: тогда он уже не
        // нужен.
        onVisible: () {
          if (!mounted ||
              (ref.read(openConflictsProvider).value?.isEmpty ?? false)) {
            toast.close();
          } else {
            _toast = toast;
          }
        },
        action: SnackBarAction(
          label: l10n.conflictOpen,
          onPressed: () => showConflictsScreen(router),
        ),
      ),
    );
    unawaited(
      toast.closed.then((_) {
        if (identical(_toast, toast)) _toast = null;
      }),
    );
  }
}
