import 'dart:async';

import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logger/logger.dart';
import 'package:oplog_sync/oplog_sync.dart' show uuidV8;
import 'package:window_manager/window_manager.dart';

import '../conflict_notifier.dart';

/// Уведомление Windows (toast) через `flutter_local_notifications`.
///
/// Приложение без MSIX: при первом уведомлении плагин записывает в
/// HKCU свой AUMID (`Software\Classes\AppUserModelId`) и регистрирует
/// COM-класс активации, поэтому клик доходит до запущенного приложения. Если
/// приложение уже закрыто, клик ничего не делает (О-36). У профиля
/// (`--profile`) свои AUMID и GUID: два запуска не перехватывают клики друг
/// друга.
final class ToastConflictNotifier implements ConflictNotifier {
  ToastConflictNotifier({this._profile});

  final String? _profile;

  /// GUID класса активации основного профиля: постоянный, иначе в реестре
  /// копились бы записи от каждого запуска.
  static const String _guid = '53ced2e8-ac7c-4b5e-b51c-64c2a0de5f13';

  static final Logger _log = Logger();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final StreamController<void> _opened = StreamController.broadcast();
  Future<bool>? _ready;
  int _nextId = 0;

  String get _aumid =>
      _profile == null ? 'Planner.Desktop' : 'Planner.Desktop.$_profile';

  String get _activator =>
      _profile == null ? _guid : uuidV8(['planner.toast', _profile]);

  /// Окно приложения (window_manager 0.6: интерфейс nativeapi), запомненное.
  /// `getCurrent()` на Windows — `GetActiveWindow()`: окно есть, только пока
  /// приложение активно, а по клику на уведомление оно обычно свёрнуто или
  /// под другим окном (ревью M4.13). Поэтому окно запоминается, когда
  /// приложение становится активным ([_lifecycle]), и при каждом обращении,
  /// пока оно впереди. При запуске ([start] — до первого кадра) окно ещё не
  /// показано.
  Window? _window;

  /// Живёт всё время работы приложения, как и сам уведомитель.
  AppLifecycleListener? _lifecycle;

  Window? get _appWindow {
    try {
      return _window = WindowManager.instance.getCurrent() ?? _window;
    } on ArgumentError catch (error, stackTrace) {
      // Нативной библиотеки nativeapi нет — окном не управляем.
      _log.w(
        'Окно приложения недоступно',
        error: error,
        stackTrace: stackTrace,
      );
      return _window;
    }
  }

  /// Неудачная инициализация не запоминается: следующий вызов попробует
  /// снова.
  Future<bool> _ensurePlugin() => _ready ??=
      () async {
        final ok = await _plugin.initialize(
          settings: InitializationSettings(
            windows: WindowsInitializationSettings(
              appName: 'Planner',
              appUserModelId: _aumid,
              guid: _activator,
            ),
          ),
          onDidReceiveNotificationResponse: (_) => unawaited(_onOpened()),
        );
        if (ok != true) _ready = null;
        return ok ?? false;
      }().catchError((Object error) {
        _ready = null;
        throw error;
      });

  Future<void> _onOpened() async {
    try {
      final window = _appWindow;
      if (window == null) {
        _log.w('Окно приложения ещё не найдено — не показано по клику');
      } else {
        if (window.isMinimized) window.restore();
        window.show();
        window.focus();
      }
    } on Object catch (error, stackTrace) {
      // Окно не вышло на передний план — экран «Конфликты» всё равно откроется.
      _log.w('Окно не показано по клику', error: error, stackTrace: stackTrace);
    }
    _opened.add(null);
  }

  @override
  Future<void> start() async {
    _lifecycle ??= AppLifecycleListener(onResume: () => _appWindow);
    _appWindow;
    if (!await _ensurePlugin()) {
      _log.w('Уведомления Windows не инициализированы');
    }
  }

  @override
  Future<bool> isAppActive() async {
    final window = _appWindow;
    return window != null &&
        window.isVisible &&
        !window.isMinimized &&
        window.isFocused;
  }

  @override
  Future<void> show({required String title, required String body}) async {
    if (!await _ensurePlugin()) {
      throw StateError('Уведомления Windows не инициализированы');
    }
    await _plugin.show(id: _nextId++, title: title, body: body);
  }

  /// Уведомлений ещё не показывали — плагин не трогаем. `cancelAll` снимает
  /// все уведомления приложения: пока других нет, это только о конфликтах;
  /// с напоминаниями — снимать свои id (О-37, M7).
  @override
  Future<void> clear() async {
    if (_ready == null || !await _ensurePlugin()) return;
    await _plugin.cancelAll();
  }

  @override
  Stream<void> get opened => _opened.stream;
}
