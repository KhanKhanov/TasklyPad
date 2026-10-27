import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/sync_providers.dart';
import '../../../sync/sync_runner.dart';

part 'sync_controller.g.dart';

/// Состояние синхронизации для экрана настроек и оболочки.
@immutable
final class SyncStatus {
  const SyncStatus({
    this.loaded = false,
    this.folder,
    this.lastSync,
    this.running = false,
    this.error,
    this.issues = 0,
  });

  /// Папка и время прочитаны из базы.
  final bool loaded;

  /// Выбранная папка; `null` — синхронизация не настроена.
  final String? folder;

  /// Последняя удачная синхронизация (UTC).
  final DateTime? lastSync;

  /// Идёт проход.
  final bool running;

  /// Ошибка последнего прохода (`SyncFormatException`, сбой папки) или
  /// `null`, если он прошёл.
  final Object? error;

  /// Файлы чужих устройств, которые последний проход не смог прочитать
  /// (не докачаны облаком, повреждены) — перечитаются в следующий раз.
  final int issues;

  SyncStatus _copy({
    String? folder,
    DateTime? lastSync,
    bool? running,
    Object? error,
    bool clearError = false,
    int? issues,
  }) => SyncStatus(
    loaded: true,
    folder: folder ?? this.folder,
    lastSync: lastSync ?? this.lastSync,
    running: running ?? this.running,
    error: clearError ? null : (error ?? this.error),
    issues: issues ?? this.issues,
  );
}

/// Когда синхронизироваться (docs/plans/m2-core-app.md, решение 10): при
/// запуске, раз в [period], через [debounce] после своей правки, при
/// возврате окна на передний план и кнопкой «Синхронизировать».
@Riverpod(keepAlive: true)
class SyncController extends _$SyncController {
  static const Duration period = Duration(seconds: 60);
  static const Duration debounce = Duration(seconds: 5);

  static final Logger _log = Logger();

  Timer? _debounceTimer;

  @override
  SyncStatus build() {
    final timer = Timer.periodic(period, (_) => syncNow());
    final changes = ref.watch(mutatorProvider).localChanges.listen((_) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(debounce, syncNow);
    });
    final lifecycle = AppLifecycleListener(onResume: syncNow);
    ref.onDispose(() {
      timer.cancel();
      _debounceTimer?.cancel();
      unawaited(changes.cancel());
      lifecycle.dispose();
    });
    unawaited(_load());
    return const SyncStatus();
  }

  SyncRunner get _runner => ref.read(syncRunnerProvider);

  /// Идущий проход или смена папки: следующий запрос ждёт его, а не
  /// запускает второй параллельно.
  Future<void>? _busy;

  Future<void> _load() async {
    try {
      final folder = await _runner.folderPath();
      final lastSync = await _runner.lastSync();
      if (!ref.mounted) return;
      state = SyncStatus(loaded: true, folder: folder, lastSync: lastSync);
    } on Object catch (error, stackTrace) {
      _log.e(
        'Настройки синхронизации не прочитаны',
        error: error,
        stackTrace: stackTrace,
      );
      if (ref.mounted) state = SyncStatus(loaded: true, error: error);
      return;
    }
    await syncNow();
  }

  /// Синхронизировать сейчас. Без папки — ничего; во время прохода — ждёт
  /// его, второй не запускает.
  Future<void> syncNow() {
    if (state.folder == null) return Future.value();
    return _busy ??= _sync().whenComplete(() => _busy = null);
  }

  Future<void> _sync() async {
    state = state._copy(running: true);
    try {
      final report = await _runner.syncNow();
      final lastSync = await _runner.lastSync();
      if (!ref.mounted) return;
      state = state._copy(
        running: false,
        lastSync: lastSync,
        // Папка выбрана, а прохода не было — аренду держит другой проход.
        error: report == null ? const SyncBusyException() : null,
        clearError: report != null,
        issues: report?.issues.length ?? state.issues,
      );
    } on Object catch (error, stackTrace) {
      _log.e('Синхронизация не удалась', error: error, stackTrace: stackTrace);
      if (ref.mounted) state = state._copy(running: false, error: error);
    }
  }

  /// Другие устройства в текущей папке — для диалога смены папки: какие из
  /// них больше не используются. `null` — папку прочитать не удалось.
  Future<List<SyncDevice>?> otherDevices() async {
    try {
      return [
        for (final device in await _runner.devices())
          if (!device.isThisDevice) device,
      ];
    } on Object catch (error, stackTrace) {
      _log.w(
        'Устройства прежней папки не прочитаны',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Другие устройства из журнала этого устройства — для «Создать папку
  /// заново» ([SyncRunner.journalDevices]). `null` — журнал не прочитан.
  Future<List<SyncDevice>?> journalDevices() async {
    try {
      return await _runner.journalDevices();
    } on Object catch (error, stackTrace) {
      _log.w(
        'Устройства из журнала не прочитаны',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Выбрать или сменить папку и синхронизироваться с ней; правки устройств
  /// [retired] переиздаются в новую папку ([SyncRunner.setFolder]). `null` — не
  /// вышло: ошибка в состоянии, на экране — папка, которая действительно
  /// сохранена. Сбой первого прохода с уже сменённой папкой — тоже в
  /// состоянии, а итог смены возвращается.
  Future<FolderChange?> setFolder(
    String path, {
    Set<String> retired = const {},
    bool force = false,
  }) async {
    _debounceTimer?.cancel();
    // Идущий проход дописывает в прежнюю папку — сначала дождаться его.
    while (_busy != null) {
      await _busy;
    }
    final done = Completer<void>();
    _busy = done.future;
    state = state._copy(running: true);
    try {
      final change = await _runner.setFolder(
        path,
        retired: retired,
        force: force,
      );
      final lastSync = await _runner.lastSync();
      if (ref.mounted) {
        // Папка сменена, даже если первый проход с ней не удался: ошибка —
        // под статусом, итог переиздания — в тосте.
        state = state._copy(
          folder: path,
          running: false,
          lastSync: lastSync,
          error: change.error,
          clearError: change.error == null,
          issues: change.issues,
        );
      }
      return change;
    } on Object catch (error, stackTrace) {
      _log.e('Папка не подключена', error: error, stackTrace: stackTrace);
      final saved = await _runner.folderPath().catchError((
        Object readError,
        StackTrace readStack,
      ) {
        _log.w(
          'Сохранённая папка не прочитана',
          error: readError,
          stackTrace: readStack,
        );
        return state.folder;
      });
      if (ref.mounted) {
        state = SyncStatus(
          loaded: true,
          folder: saved,
          lastSync: state.lastSync,
          error: error,
          issues: state.issues,
        );
      }
      return null;
    } finally {
      _busy = null;
      done.complete();
    }
  }

  /// «Пересобрать базу из журнала».
  Future<void> rebuild() => _runner.rebuild();
}

/// Устройства в папке синхронизации; перечитываются после каждого удачного
/// прохода и после каждой ошибки — неудачный проход не меняет время
/// синхронизации, а папки уже может не быть.
@riverpod
Future<List<SyncDevice>> syncDevices(Ref ref) {
  ref.watch(
    syncControllerProvider.select((s) => (s.folder, s.lastSync, s.error)),
  );
  return ref.read(syncRunnerProvider).devices();
}
