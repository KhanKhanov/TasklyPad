import 'dart:async';

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
  Future<void>? _window;
  Future<bool>? _ready;
  int _nextId = 0;

  String get _aumid =>
      _profile == null ? 'Planner.Desktop' : 'Planner.Desktop.$_profile';

  String get _activator =>
      _profile == null ? _guid : uuidV8(['planner.toast', _profile]);

  Future<void> _ensureWindow() => _window ??= windowManager.ensureInitialized();

  /// Неудачная инициализация не запоминается: следующий вызов попробует
  /// снова.
  Future<bool> _ensurePlugin() => _ready ??=
      () async {
        await _ensureWindow();
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
      await windowManager.show();
      await windowManager.focus();
    } on Object catch (error, stackTrace) {
      // Окно не вышло на передний план — экран «Конфликты» всё равно откроется.
      _log.w('Окно не показано по клику', error: error, stackTrace: stackTrace);
    }
    _opened.add(null);
  }

  @override
  Future<void> start() async {
    if (!await _ensurePlugin()) {
      _log.w('Уведомления Windows не инициализированы');
    }
  }

  @override
  Future<bool> isAppActive() async {
    await _ensureWindow();
    return await windowManager.isVisible() &&
        !await windowManager.isMinimized() &&
        await windowManager.isFocused();
  }

  @override
  Future<void> show({required String title, required String body}) async {
    if (!await _ensurePlugin()) {
      throw StateError('Уведомления Windows не инициализированы');
    }
    await _plugin.show(id: _nextId++, title: title, body: body);
  }

  @override
  Stream<void> get opened => _opened.stream;
}
