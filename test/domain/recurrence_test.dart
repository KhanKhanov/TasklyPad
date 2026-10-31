import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:planner/domain/models.dart';
import 'package:planner/domain/recurrence.dart';

// Табличный тест: строки — test/fixtures/recurrence_next.json (`source` —
// страница help или «допущение О-57»). `now` записан со смещением пояса
// срока; функция получает его стенное время.

/// Стенное время из `2026-10-26T10:00:00+03:00` — цифры до смещения.
DateTime _wall(String now) {
  final local = now.substring(0, 19);
  return DateTime.parse('${local}Z');
}

Due _due(Map<String, Object?> json) {
  final rule = json['rule']! as Map<String, Object?>;
  return Due(
    date: json['date']! as String,
    time: json['time'] as String?,
    tz: json['tz'] as String?,
    string: 'каждый раз',
    lang: 'ru',
    rule: RecurrenceRule(
      rrule: (rule['rrule']! as List<Object?>).cast<String>(),
      fromCompletion: rule['from_completion']! as bool,
    ),
  );
}

void main() {
  final rows = (jsonDecode(
    File('test/fixtures/recurrence_next.json').readAsStringSync(),
  ) as List<Object?>).cast<Map<String, Object?>>();

  test('fixtures — у каждой строки есть источник', () {
    for (final row in rows) {
      expect(row['source'], isA<String>(), reason: '${row['name']}');
    }
  });

  for (final row in rows) {
    test('${row['name']} (${row['source']})', () {
      final due = _due(row['input']! as Map<String, Object?>);
      final expected = row['expect']! as Map<String, Object?>;
      final next = nextOccurrence(
        due,
        completedAt: _wall(row['now']! as String),
        postpone: row['postpone'] == true,
      );
      if (expected['ended'] == true) {
        expect(next, isNull);
      } else {
        // Новый срок — тот же, кроме даты и времени: текст, язык, правило и
        // пояс сохраняются.
        expect(
          next,
          due.copyWith(
            date: expected['date']! as String,
            time: expected['time'] as String?,
          ),
        );
      }
    });
  }

  group('ошибки входа', () {
    const daily = RecurrenceRule(rrule: ['FREQ=DAILY'], fromCompletion: false);
    final now = DateTime.utc(2026, 10, 26, 10);

    test('срок без правила — ArgumentError', () {
      expect(
        () => nextOccurrence(const Due(date: '2026-10-26'), completedAt: now),
        throwsArgumentError,
      );
    });

    test('пустой список правил — ArgumentError, а не «серия закончилась»', () {
      expect(
        () => nextOccurrence(
          const Due(
            date: '2026-10-26',
            rule: RecurrenceRule(rrule: [], fromCompletion: false),
          ),
          completedAt: now,
        ),
        throwsArgumentError,
      );
    });

    test('время выполнения не в UTC-обёртке — ArgumentError', () {
      expect(
        () => nextOccurrence(
          const Due(date: '2026-10-26', rule: daily),
          completedAt: DateTime(2026, 10, 26, 10),
        ),
        throwsArgumentError,
      );
    });

    for (final (name, due) in [
      (
        'неразбираемая строка RRULE',
        const Due(
          date: '2026-10-26',
          rule: RecurrenceRule(rrule: ['BAD'], fromCompletion: false),
        ),
      ),
      (
        'COUNT — счёт сбивался бы при каждом пересчёте от нового срока',
        const Due(
          date: '2026-10-26',
          rule: RecurrenceRule(
            rrule: ['FREQ=DAILY;COUNT=3'],
            fromCompletion: false,
          ),
        ),
      ),
      for (final (what, line) in [
        ('SECONDLY — у пакета бесконечный перебор', 'FREQ=SECONDLY'),
        ('MINUTELY', 'FREQ=MINUTELY;INTERVAL=30'),
        ('часть вне набора (BYHOUR)', 'FREQ=DAILY;BYHOUR=9'),
        ('BYSETPOS у недели', 'FREQ=WEEKLY;BYDAY=MO,WE,FR;BYSETPOS=1'),
        (
          '30 февраля — перебор до 9999 года',
          'FREQ=YEARLY;BYMONTH=2;BYMONTHDAY=30',
        ),
        ('UNTIL не дата и не UTC', 'FREQ=DAILY;UNTIL=20261103T235959'),
        (
          'UNTIL 31 ноября — пакет перенёс бы на 1 декабря',
          'FREQ=DAILY;UNTIL=20261131',
        ),
        ('INTERVAL=0 — у пакета бесконечный цикл', 'FREQ=DAILY;INTERVAL=0'),
        ('INTERVAL=0 у месяца — деление на ноль', 'FREQ=MONTHLY;INTERVAL=0'),
        ('INTERVAL=-1', 'FREQ=MONTHLY;INTERVAL=-1'),
        ('номер дня недели у недели', 'FREQ=WEEKLY;BYDAY=1MO'),
        ('число месяца у недели', 'FREQ=WEEKLY;BYMONTHDAY=15'),
        ('BYSETPOS без дней недели', 'FREQ=MONTHLY;BYSETPOS=1'),
        (
          '24-й рабочий день — в месяце их не больше 23',
          'FREQ=MONTHLY;BYDAY=MO,TU,WE,TH,FR;BYSETPOS=24',
        ),
        ('шестой понедельник месяца', 'FREQ=MONTHLY;BYDAY=6MO'),
        (
          '29 февраля раз в 4 года — от невисокосного не наступит',
          'FREQ=YEARLY;INTERVAL=4;BYMONTH=2;BYMONTHDAY=29',
        ),
        (
          '31-е раз в 12 месяцев — от февраля не наступит',
          'FREQ=MONTHLY;INTERVAL=12;BYMONTHDAY=31',
        ),
        ('день у года без месяца', 'FREQ=YEARLY;BYMONTHDAY=15'),
        ('WKST не MO — пакет не поддерживает', 'FREQ=WEEKLY;WKST=SU;BYDAY=MO'),
        ('повтор части', 'FREQ=DAILY;FREQ=WEEKLY'),
        ('дни недели у дня с шагом 7', 'FREQ=DAILY;INTERVAL=7;BYDAY=TU'),
        ('15-е и первый понедельник', 'FREQ=MONTHLY;BYMONTHDAY=15;BYDAY=1MO'),
        (
          'месяц года без числа — взялось бы число срока',
          'FREQ=YEARLY;BYMONTH=2',
        ),
        (
          '23-й рабочий день раз в 12 месяцев',
          'FREQ=MONTHLY;INTERVAL=12;BYDAY=MO,TU,WE,TH,FR;BYSETPOS=23',
        ),
      ])
        (
          what,
          Due(
            date: '2026-10-26',
            time: '09:00',
            rule: RecurrenceRule(rrule: [line], fromCompletion: false),
          ),
        ),
      (
        'часовое правило у срока без времени',
        const Due(
          date: '2026-10-26',
          rule: RecurrenceRule(rrule: ['FREQ=HOURLY'], fromCompletion: false),
        ),
      ),
      ('неверная дата срока', const Due(date: '26.10.2026', rule: daily)),
      (
        'неверное время срока',
        const Due(date: '2026-10-26', time: '9 утра', rule: daily),
      ),
    ]) {
      test('$name — FormatException своей проверки', () {
        // Не assert пакета (его нет в релизной сборке — правило прошло бы в
        // перебор; `_parseRule` пропускает AssertionError как есть) и не
        // обёрнутая ошибка разбора пакета.
        expect(
          () => nextOccurrence(due, completedAt: now),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              isNot(startsWith('строка RRULE не разобрана')),
            ),
          ),
        );
      });
    }
  });
}
