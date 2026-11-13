import 'package:flutter_test/flutter_test.dart';
import 'package:planner/domain/models.dart';
import 'package:planner/domain/rules.dart';
import 'package:planner/nlp/duration_text.dart';
import 'package:planner/nlp/parse_context.dart';
import 'package:planner/nlp/quick_add.dart';

import 'fixtures.dart';

// Табличный тест своей длительности поля: строки — test/fixtures/durations.json
// (О-83). `in_range` — проверка `Limits.durationInRange`, общая с быстрым
// добавлением и командами.

void main() {
  final rows = loadRows('durations.json');

  test('fixtures — у каждой строки есть источник', () {
    for (final row in rows) {
      expect(row['source'], isA<String>(), reason: '${row['input']}');
    }
  });

  for (final row in rows) {
    final input = row['input']! as String;
    final expected = expectOf(row);
    test('«$input» — ${row['source']}', () {
      final minutes = parseDurationMinutes(input);
      if (expected['none'] == true) {
        expect(minutes, isNull);
        return;
      }
      expect(minutes, expected['minutes']);
      if (expected['in_range'] case final bool inRange) {
        expect(Limits.durationInRange(minutes!), inRange);
      }
    });
  }

  group('одна проверка диапазона на оба разбора', () {
    final ctx = ParseContext(now: DateTime.utc(2026, 11, 13, 10), lang: 'en');

    test('быстрое добавление: 24 ч — длительность, 25 ч — текст', () {
      expect(
        parseQuickAdd('Task for 24h', ctx).duration,
        const TaskDuration(amount: 1440, unit: 'minute'),
      );
      expect(parseQuickAdd('Task for 25h', ctx).duration, isNull);
    });

    test('команды: сутки в единицах `day` — вне диапазона', () {
      expect(
        () => Limits.checkDuration(const TaskDuration(amount: 2, unit: 'day')),
        throwsA(isA<CommandRejected>()),
      );
      Limits.checkDuration(const TaskDuration(amount: 1, unit: 'day'));
      Limits.checkDuration(null);
    });
  });
}
