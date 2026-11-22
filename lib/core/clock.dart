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

  /// Стенное время устройства для момента [utc] — в том же виде, что
  /// [nowWall]: цифры местного времени в UTC-обёртке, до миллисекунд. Для
  /// времени, записанного в UTC (дата создания и выполнения задачи), в
  /// фильтре `created:` и группах «по дате добавления» — так «сегодня» и день
  /// задачи считаются в одном поясе.
  DateTime wallOf(DateTime utc);
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
  DateTime nowWall() => wallOf(pkg.clock.now());

  /// По поясу устройства на момент [utc]: на другой стороне перехода на
  /// летнее время сдвиг свой, как у часов в тот момент.
  @override
  DateTime wallOf(DateTime utc) {
    final l = utc.toLocal();
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
/// [wallOffset] — пояс «устройства» для [nowWall] и [wallOf]: явно, чтобы тесты не
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
  DateTime nowWall() => wallOf(_now);

  @override
  DateTime wallOf(DateTime utc) => utc.toUtc().add(wallOffset);
}
