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

  /// Стенное время устройства («как на часах») в UTC-обёртке: цифры
  /// местного времени, `isUtc`. Для расчёта повторений
  /// (lib/domain/recurrence.dart): срок задачи — стенное время.
  DateTime nowWall();
}

/// Реальные часы. Внутри — `package:clock`, поэтому в тестах их тоже можно
/// подменить через `withClock(Clock.fixed(...))`, не меняя код.
final class SystemClock implements AppClock {
  const SystemClock();

  @override
  DateTime nowUtc() => pkg.clock.now().toUtc();

  @override
  int nowMs() => nowUtc().millisecondsSinceEpoch;

  @override
  DateTime nowWall() {
    final l = pkg.clock.now().toLocal();
    return DateTime.utc(
      l.year,
      l.month,
      l.day,
      l.hour,
      l.minute,
      l.second,
      l.millisecond,
    );
  }
}

/// Управляемые часы для тестов: стоят, пока не сдвинуть [advance].
///
/// [wallOffset] — пояс «устройства» для [nowWall]: явно, чтобы тесты не
/// зависели от пояса машины, на которой их запускают.
final class FixedClock implements AppClock {
  FixedClock(DateTime start, {this.wallOffset = Duration.zero})
    : _now = start.toUtc();

  final Duration wallOffset;

  DateTime _now;

  void advance(Duration delta) => _now = _now.add(delta);

  void set(DateTime value) => _now = value.toUtc();

  @override
  DateTime nowUtc() => _now;

  @override
  int nowMs() => _now.millisecondsSinceEpoch;

  @override
  DateTime nowWall() => _now.add(wallOffset);
}
