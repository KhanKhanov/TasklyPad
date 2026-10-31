import 'package:flutter_test/flutter_test.dart';
import 'package:planner/domain/models.dart';
import 'package:planner/nlp/quick_add.dart';
import 'package:planner/nlp/scanner.dart';

import 'fixtures.dart';

// Табличный тест быстрого добавления: строки — test/fixtures/quick_add.json.
// Сравниваются только ключи `expect`; `dismissed` — подстроки, подсветку
// которых пользователь отменил.

void main() {
  final rows = loadRows('quick_add.json');

  test('fixtures — у каждой строки есть источник', () {
    for (final row in rows) {
      expect(row['source'], isA<String>(), reason: nameOf(row));
    }
  });

  for (final row in rows) {
    test('${nameOf(row)} — ${row['source']}', () {
      final input = row['input']! as String;
      final dismissed = [
        for (final s
            in (row['dismissed'] as List<Object?>? ?? const []).cast<String>())
          Span(input.indexOf(s), input.indexOf(s) + s.length),
      ];
      final result = parseQuickAdd(
        input,
        contextOf(row),
        dismissed: dismissed,
        smartDates: row['smart_dates'] != false,
      );
      final expected = expectOf(row);
      expect(result.title, expected['title']);
      for (final MapEntry(:key, :value) in expected.entries) {
        switch (key) {
          case 'title':
            break;
          case 'due':
            _expectDue(result.due, value as Map<String, Object?>?);
          case 'project':
            expect(result.project, value);
          case 'section':
            expect(result.section, value);
          case 'labels':
            expect(result.labels, value);
          case 'priority':
            expect(result.priority, value);
          case 'deadline':
            expect(result.deadline, value);
          case 'duration':
            final d = value! as Map<String, Object?>;
            expect(
              result.duration,
              TaskDuration(
                amount: d['amount']! as int,
                unit: d['unit']! as String,
              ),
            );
          case 'description':
            expect(result.description, value);
          case 'no_date':
            expect(result.noDate, value);
          case 'highlights':
            expect([
              for (final h in result.highlights)
                {'text': input.substring(h.start, h.end), 'kind': h.kind.name},
            ], value);
          default:
            fail('неизвестный ключ expect: $key');
        }
      }
    });
  }
}

void _expectDue(Due? due, Map<String, Object?>? expected) {
  if (expected == null) {
    expect(due, isNull);
    return;
  }
  expect(due, isNotNull);
  expect(due!.date, expected['date']);
  expect(due.time, expected['time']);
  if (expected['rrule'] case final List<Object?> rrule) {
    expect(
      due.rule,
      RecurrenceRule(
        rrule: rrule.cast<String>(),
        fromCompletion: expected['from_completion']! as bool,
      ),
    );
  } else {
    expect(due.rule, isNull);
  }
  if (expected.containsKey('string')) expect(due.string, expected['string']);
  if (expected.containsKey('lang')) expect(due.lang, expected['lang']);
}
