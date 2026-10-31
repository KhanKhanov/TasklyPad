import 'dart:convert';
import 'dart:io';

import 'package:planner/nlp/parse_context.dart';

/// Строки fixtures разбора (формат — test/fixtures/README.md).
List<Map<String, Object?>> loadRows(String file) => (jsonDecode(
  File('test/fixtures/$file').readAsStringSync(),
) as List<Object?>).cast<Map<String, Object?>>();

/// Контекст строки: стенное время из `now` — цифры до смещения.
ParseContext contextOf(Map<String, Object?> row, {String? lang}) {
  final now = row['now']! as String;
  return ParseContext(
    now: DateTime.parse('${now.substring(0, 19)}Z'),
    lang: lang ?? row['lang']! as String,
  );
}

/// Имя теста: ввод, язык, момент.
String nameOf(Map<String, Object?> row) =>
    '«${row['input']}» (${row['lang']}, ${(row['now']! as String).substring(0, 16)})';

Map<String, Object?> expectOf(Map<String, Object?> row) =>
    row['expect']! as Map<String, Object?>;
