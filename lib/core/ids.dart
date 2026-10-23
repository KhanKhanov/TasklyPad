import 'dart:math';
import 'dart:typed_data';

import 'package:clock/clock.dart';

/// Генератор идентификаторов UUIDv7 (RFC 9562).
///
/// Первые 48 бит — Unix-время в миллисекундах, поэтому ID сортируются
/// хронологически и индекс в SQLite растёт «в конец», а не вразброс. Остальное —
/// случайные биты, так что два устройства никогда не выдадут один ID без
/// центрального счётчика.
///
/// Время берётся из `package:clock`: в тестах `withClock(Clock.fixed(...))`
/// делает ID детерминированными. Внутри одной миллисекунды ID монотонны
/// (12-битный счётчик в поле `rand_a`).
final class IdGenerator {
  IdGenerator({Random? random}) : _random = random ?? Random.secure();

  final Random _random;
  int _lastMs = 0;
  int _seq = 0;

  /// Новый UUIDv7 в каноническом виде `xxxxxxxx-xxxx-7xxx-yxxx-xxxxxxxxxxxx`.
  String next() {
    var ms = clock.now().toUtc().millisecondsSinceEpoch;
    if (ms <= _lastMs) {
      ms = _lastMs;
      _seq++;
      if (_seq > 0xFFF) {
        // Счётчик исчерпан — «занимаем» следующую миллисекунду.
        ms++;
        _seq = 0;
      }
    } else {
      _seq = _random.nextInt(0x800); // половина диапазона — запас на инкременты
    }
    _lastMs = ms;

    final bytes = Uint8List(16);
    for (var i = 0; i < 6; i++) {
      bytes[i] = (ms >> (8 * (5 - i))) & 0xFF;
    }
    bytes[6] = 0x70 | ((_seq >> 8) & 0x0F); // версия 7 + старшие 4 бита seq
    bytes[7] = _seq & 0xFF;
    for (var i = 8; i < 16; i++) {
      bytes[i] = _random.nextInt(256);
    }
    bytes[8] = (bytes[8] & 0x3F) | 0x80; // вариант RFC 4122

    final hex = StringBuffer();
    for (var i = 0; i < 16; i++) {
      if (i == 4 || i == 6 || i == 8 || i == 10) hex.write('-');
      hex.write(bytes[i].toRadixString(16).padLeft(2, '0'));
    }
    return hex.toString();
  }
}

/// Проверка формата UUIDv7 (для валидации входящих данных).
final RegExp uuidV7Pattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);
