import 'package:clock/clock.dart' as pkg;

/// Источник времени приложения.
///
/// В domain/data/sync запрещён `DateTime.now()`: время приходит через этот
/// интерфейс, чтобы тесты могли «остановить» или «перемотать» часы. Все
/// значения — UTC; в локальное время переводит только UI.
abstract interface class AppClock {
  DateTime nowUtc();

  /// Unix-миллисекунды — формат, который ждёт HLC из oplog_sync.
  int nowMs();
}

/// Реальные часы. Внутри — `package:clock`, поэтому в тестах их тоже можно
/// подменить через `withClock(Clock.fixed(...))`, не меняя код.
final class SystemClock implements AppClock {
  const SystemClock();

  @override
  DateTime nowUtc() => pkg.clock.now().toUtc();

  @override
  int nowMs() => nowUtc().millisecondsSinceEpoch;
}

/// Управляемые часы для тестов: стоят, пока не сдвинуть [advance].
final class FixedClock implements AppClock {
  FixedClock(DateTime start) : _now = start.toUtc();

  DateTime _now;

  void advance(Duration delta) => _now = _now.add(delta);

  void set(DateTime value) => _now = value.toUtc();

  @override
  DateTime nowUtc() => _now;

  @override
  int nowMs() => _now.millisecondsSinceEpoch;
}
