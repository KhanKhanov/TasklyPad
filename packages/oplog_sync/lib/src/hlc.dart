import 'package:meta/meta.dart';

/// Гибридные логические часы (Hybrid Logical Clock).
///
/// Метка времени из трёх частей: физическое время в миллисекундах (`wallMs`),
/// счётчик для событий в одну и ту же миллисекунду (`counter`) и идентификатор
/// узла (`nodeId`) как последний разделитель ничьей. Две метки с разных узлов
/// никогда не равны, а порядок сохраняется даже при расхождении часов устройств.
///
/// Строковая форма `000001761110400000:0003:node-id` сделана так, чтобы обычное
/// сравнение строк совпадало с [compareTo]: числа дополнены нулями до фиксированной
/// ширины. Это позволяет хранить HLC в SQLite как TEXT и сортировать запросом.
@immutable
final class Hlc implements Comparable<Hlc> {
  const Hlc({required this.wallMs, required this.counter, required this.nodeId})
    : assert(wallMs >= 0, 'wallMs не может быть отрицательным'),
      assert(counter >= 0 && counter <= maxCounter, 'counter вне диапазона');

  /// Нулевая метка — состояние «ничего ещё не происходило».
  const Hlc.zero(String nodeId) : this(wallMs: 0, counter: 0, nodeId: nodeId);

  /// Разбор строковой формы, обратной к [toString].
  factory Hlc.parse(String text) {
    final parts = text.split(':');
    if (parts.length != 3) {
      throw FormatException('Ожидалось "wall:counter:node"', text);
    }
    final wall = int.tryParse(parts[0]);
    final counter = int.tryParse(parts[1], radix: 16);
    // Строка может прийти из чужого файла — диапазоны проверяем здесь, а не
    // assert-ом конструктора, который в release-сборке отключён.
    if (wall == null ||
        wall < 0 ||
        counter == null ||
        counter < 0 ||
        counter > maxCounter ||
        parts[2].isEmpty) {
      throw FormatException('Неверный формат HLC', text);
    }
    return Hlc(wallMs: wall, counter: counter, nodeId: parts[2]);
  }

  /// Физическое время (Unix-миллисекунды, UTC).
  final int wallMs;

  /// Порядковый номер события внутри одной миллисекунды.
  final int counter;

  /// Идентификатор узла-автора. Не должен содержать `:`.
  final String nodeId;

  /// Ширина поля миллисекунд в строке: 15 цифр хватит на тысячи лет вперёд.
  static const int wallWidth = 15;

  /// Ширина счётчика в строке (hex): 4 знака, до 65535 событий в миллисекунду.
  static const int counterWidth = 4;

  /// Максимальное значение счётчика.
  static const int maxCounter = 0xFFFF;

  /// Допустимое опережение чужих часов. Op из «будущего» дальше этого порога
  /// не применяется — защита от устройства со сбитой датой.
  static const Duration maxDrift = Duration(hours: 1);

  /// Новая метка для локального события.
  ///
  /// `wall = max(now, last.wall)`; если миллисекунда та же — растёт счётчик.
  /// Так метки монотонны, даже если системные часы прыгнули назад.
  Hlc tick(int nowMs) {
    final wall = nowMs > wallMs ? nowMs : wallMs;
    final nextCounter = wall == wallMs ? counter + 1 : 0;
    _checkCounter(nextCounter);
    return Hlc(wallMs: wall, counter: nextCounter, nodeId: nodeId);
  }

  /// Новая локальная метка после получения метки [remote] с другого узла
  /// (правило из статьи Кулкарни и др. «Logical Physical Clocks», 2014).
  ///
  /// Гарантирует, что всё, что мы запишем после получения, будет позже [remote].
  /// Бросает [HlcDriftException], если [remote] опережает наше время больше
  /// чем на [maxDrift].
  Hlc receive(Hlc remote, int nowMs) {
    if (remote.wallMs - nowMs > maxDrift.inMilliseconds) {
      throw HlcDriftException(remote: remote, nowMs: nowMs);
    }
    final wall = [nowMs, wallMs, remote.wallMs].reduce((a, b) => a > b ? a : b);
    final int nextCounter;
    if (wall == wallMs && wall == remote.wallMs) {
      nextCounter = (counter > remote.counter ? counter : remote.counter) + 1;
    } else if (wall == wallMs) {
      nextCounter = counter + 1;
    } else if (wall == remote.wallMs) {
      nextCounter = remote.counter + 1;
    } else {
      nextCounter = 0;
    }
    _checkCounter(nextCounter);
    return Hlc(wallMs: wall, counter: nextCounter, nodeId: nodeId);
  }

  static void _checkCounter(int value) {
    if (value > maxCounter) {
      throw StateError('Переполнение счётчика HLC: $value');
    }
  }

  @override
  int compareTo(Hlc other) {
    if (wallMs != other.wallMs) return wallMs.compareTo(other.wallMs);
    if (counter != other.counter) return counter.compareTo(other.counter);
    return nodeId.compareTo(other.nodeId);
  }

  bool operator <(Hlc other) => compareTo(other) < 0;
  bool operator >(Hlc other) => compareTo(other) > 0;

  @override
  bool operator ==(Object other) =>
      other is Hlc &&
      wallMs == other.wallMs &&
      counter == other.counter &&
      nodeId == other.nodeId;

  @override
  int get hashCode => Object.hash(wallMs, counter, nodeId);

  @override
  String toString() {
    final wall = wallMs.toString().padLeft(wallWidth, '0');
    final cnt = counter
        .toRadixString(16)
        .toUpperCase()
        .padLeft(counterWidth, '0');
    return '$wall:$cnt:$nodeId';
  }
}

/// Чужая метка опережает наши часы сильнее, чем [Hlc.maxDrift].
final class HlcDriftException implements Exception {
  const HlcDriftException({required this.remote, required this.nowMs});

  final Hlc remote;
  final int nowMs;

  @override
  String toString() =>
      'HlcDriftException: $remote опережает локальное время $nowMs '
      'более чем на ${Hlc.maxDrift}';
}
