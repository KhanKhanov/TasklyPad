import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Детерминированный id: SHA-256 от [parts], разделённых нулевым символом,
/// оформленный как UUID версии 8 (RFC 9562, «свой алгоритм»).
///
/// Устройства, которые независимо создают «одну и ту же» сущность (конфликт
/// одной пары ops, метку задачи), считают id из одних данных и получают одну
/// запись, а не две. Нулевой символ не встречается в id и именах полей,
/// поэтому `['ab', 'c']` и `['a', 'bc']` дают разные id.
///
/// Формула входит в формат данных: id уже лежат в журналах устройств, менять
/// её нельзя.
String uuidV8(List<String> parts) {
  final bytes = sha256
      .convert(utf8.encode(parts.join('\u0000')))
      .bytes
      .sublist(0, 16);
  bytes[6] = 0x80 | (bytes[6] & 0x0F); // версия 8
  bytes[8] = 0x80 | (bytes[8] & 0x3F); // вариант RFC 4122
  final hex = StringBuffer();
  for (var i = 0; i < 16; i++) {
    if (i == 4 || i == 6 || i == 8 || i == 10) hex.write('-');
    hex.write(bytes[i].toRadixString(16).padLeft(2, '0'));
  }
  return hex.toString();
}
