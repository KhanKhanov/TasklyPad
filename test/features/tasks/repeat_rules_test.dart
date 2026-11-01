import 'package:flutter_test/flutter_test.dart';
import 'package:planner/domain/models.dart';
import 'package:planner/domain/recurrence.dart';
import 'package:planner/features/tasks/logic/repeat_rules.dart';
import 'package:planner/features/tasks/logic/task_commands.dart';
import 'package:planner/nlp/parse_context.dart';
import 'package:planner/nlp/quick_add.dart';

void main() {
  // Пт 23.10.2026 09:00 — стенное время в UTC-обёртке.
  final now = DateTime.utc(2026, 10, 23, 9);
  final friday = DateTime(2026, 10, 23);

  RecurrenceRule rule(String line, {bool fromCompletion = false}) =>
      RecurrenceRule(rrule: [line], fromCompletion: fromCompletion);

  group('готовые варианты «Повторить»', () {
    test('без срока — с сегодня, текст правила на языке интерфейса', () {
      final ru = {
        for (final p in RepeatPreset.values)
          p: dueWithRule(null, presetRule(p, friday), lang: 'ru', now: now)!,
      };
      expect(ru.values.map((d) => d.date).toSet(), {'2026-10-23'});
      expect(
        [for (final d in ru.values) d.string],
        ['каждый день', 'каждый пт', 'каждое 23', 'каждое 23 окт'],
      );
      expect(ru.values.map((d) => d.lang).toSet(), {'ru'});
      final en = dueWithRule(
        null,
        presetRule(RepeatPreset.weekly, friday),
        lang: 'en',
        now: now,
      )!;
      expect((en.string, en.lang), ('every fri', 'en'));
    });

    test('день недели, число и дата — в правиле: перенесённое вхождение '
        'возвращается к расписанию', () {
      expect(
        [for (final p in RepeatPreset.values) presetRule(p, friday).rrule],
        [
          ['FREQ=DAILY'],
          ['FREQ=WEEKLY;BYDAY=FR'],
          ['FREQ=MONTHLY;BYMONTHDAY=23'],
          ['FREQ=YEARLY;BYMONTH=10;BYMONTHDAY=23'],
        ],
      );
      // «Каждый пт», вхождение перенесено на пн 26.10 и выполнено — снова пт.
      final weekly = dueWithRule(
        const Due(date: '2026-10-23'),
        presetRule(RepeatPreset.weekly, friday),
        lang: 'ru',
        now: now,
      )!;
      final next = nextOccurrence(
        weekly.copyWith(date: '2026-10-26'),
        completedAt: DateTime.utc(2026, 10, 26, 9),
      );
      expect(next?.date, '2026-10-30');
    });

    test('срок с датой и временем — дата, время и пояс прежние', () {
      const current = Due(
        date: '2026-11-03',
        time: '07:00',
        tz: 'Europe/Moscow',
      );
      final due = dueWithRule(
        current,
        presetRule(RepeatPreset.monthly, DateTime(2026, 11, 3)),
        lang: 'ru',
        now: now,
      )!;
      expect(
        due,
        current.copyWith(
          string: 'каждое 3',
          lang: 'ru',
          rule: rule('FREQ=MONTHLY;BYMONTHDAY=3'),
        ),
      );
    });
  });

  group('«Отложить» — TaskCommands.postponedDue', () {
    Due daily(String date, [String? time]) => Due(
      date: date,
      time: time,
      string: 'every day',
      lang: 'en',
      rule: rule('FREQ=DAILY'),
    );

    test('просроченная — на завтра со временем и правилом; сегодняшняя и '
        'будущая — на следующее вхождение', () {
      expect(
        TaskCommands.postponedDue(daily('2026-10-20'), now)?.date,
        '2026-10-24',
      );
      expect(
        TaskCommands.postponedDue(daily('2026-10-23', '07:00'), now),
        daily('2026-10-24', '07:00'),
      );
      expect(
        TaskCommands.postponedDue(daily('2026-10-23'), now)?.date,
        '2026-10-24',
      );
      final weekly = Due(
        date: '2026-10-23',
        time: '20:00',
        rule: rule('FREQ=WEEKLY;BYDAY=FR'),
      );
      expect(TaskCommands.postponedDue(weekly, now)?.date, '2026-10-30');
    });

    test('серия закончилась — null', () {
      expect(
        TaskCommands.postponedDue(
          daily('2026-10-23').copyWith(rule: rule('FREQ=DAILY;UNTIL=20261023')),
          now,
        ),
        isNull,
      );
    });
  });

  group('«Пользовательский…» → правило', () {
    test('без срока — дата того же текста в поле: «каждую вторую пт» со '
        'второй пятницы; со сроком — ближайшая пт не раньше него', () {
      final r = customRule(const CustomRepeat(interval: 2), friday);
      final due = dueWithRule(null, r, lang: 'en', now: now)!;
      final typed = parseDueText(
        due.string!,
        ParseContext(now: now, lang: 'en'),
      )!.due!;
      expect((due.date, due.rule), (typed.date, typed.rule));
      expect(due.date, isNot('2026-10-23'));
      final dated = dueWithRule(
        const Due(date: '2026-10-26'),
        r,
        lang: 'en',
        now: now,
      )!;
      expect(dated.date, '2026-10-30');
    });

    test('неделя с днями — BYDAY, срок — ближайший из дней', () {
      final r = customRule(
        const CustomRepeat(weekdays: {DateTime.monday, DateTime.wednesday}),
        friday,
      );
      expect(r, rule('FREQ=WEEKLY;BYDAY=MO,WE'));
      final due = dueWithRule(
        const Due(date: '2026-10-23'),
        r,
        lang: 'ru',
        now: now,
      )!;
      expect((due.date, due.string), ('2026-10-26', 'каждый пн, ср'));
    });

    test('неделя без отмеченных дней — день даты срока', () {
      expect(
        customRule(const CustomRepeat(interval: 2), friday),
        rule('FREQ=WEEKLY;INTERVAL=2;BYDAY=FR'),
      );
    });

    test('шаг больше двух недель — серия от даты без дней (текстом «каждые 3 '
        'недели» дни не записать)', () {
      expect(
        customRule(
          const CustomRepeat(interval: 3, weekdays: {DateTime.monday}),
          friday,
        ),
        rule('FREQ=WEEKLY;INTERVAL=3'),
      );
    });

    test('месяц: число даты — без частей BY…, день недели — по номеру; пятый '
        '— последний', () {
      expect(
        customRule(const CustomRepeat(unit: RepeatUnit.month), friday),
        rule('FREQ=MONTHLY'),
      );
      const weekday = CustomRepeat(
        unit: RepeatUnit.month,
        monthDay: MonthDay.weekday,
      );
      expect(customRule(weekday, friday), rule('FREQ=MONTHLY;BYDAY=4FR'));
      expect(
        customRule(weekday, DateTime(2026, 10, 30)),
        rule('FREQ=MONTHLY;BYDAY=-1FR'),
      );
    });

    test('по дате выполнения и окончание — `every!` и UNTIL датой', () {
      final r = customRule(
        CustomRepeat(
          fromCompletion: true,
          unit: RepeatUnit.day,
          interval: 3,
          until: DateTime(2027, 1, 14),
        ),
        friday,
      );
      expect(
        r,
        rule('FREQ=DAILY;INTERVAL=3;UNTIL=20270114', fromCompletion: true),
      );
      expect(
        dueWithRule(null, r, lang: 'ru', now: now)!.string,
        'каждые! 3 дня до 14 янв 2027',
      );
      expect(
        dueWithRule(null, r, lang: 'en', now: now)!.string,
        'every! 3 days until jan 14 2027',
      );
    });
  });

  group('что записать нельзя — null', () {
    test('день недели месяца с шагом больше месяца — у правила нет текста', () {
      final r = customRule(
        const CustomRepeat(
          unit: RepeatUnit.month,
          interval: 2,
          monthDay: MonthDay.weekday,
        ),
        friday,
      );
      expect(dueWithRule(null, r, lang: 'ru', now: now), isNull);
      expect(dueWithRule(null, r, lang: 'en', now: now), isNull);
    });

    test('текст есть, но разбирается в другое правило — не записать: '
        'показанное и посчитанное разошлись бы', () {
      // «every day» разбирается в `FREQ=DAILY` без INTERVAL=1.
      expect(
        dueWithRule(null, rule('FREQ=DAILY;INTERVAL=1'), lang: 'en', now: now),
        isNull,
      );
    });

    test('окончание раньше первого вхождения', () {
      final r = customRule(CustomRepeat(until: DateTime(2026, 10, 22)), friday);
      expect(
        dueWithRule(
          const Due(date: '2026-10-23'),
          r,
          lang: 'ru',
          now: now,
        ),
        isNull,
      );
    });
  });

  group('правило → значения окна', () {
    test('то, что окно записало, открывается теми же значениями', () {
      final values = [
        CustomRepeat(weekdays: const {1, 5}, until: DateTime(2027, 1, 14)),
        const CustomRepeat(fromCompletion: true, unit: RepeatUnit.day),
        const CustomRepeat(interval: 2, weekdays: {5}),
        const CustomRepeat(unit: RepeatUnit.month, monthDay: MonthDay.weekday),
        const CustomRepeat(unit: RepeatUnit.year, interval: 2),
      ];
      for (final c in values) {
        final back = customFromRule(customRule(c, friday), friday);
        expect(customRule(back, friday), customRule(c, friday));
      }
    });

    test('форма, которой в окне нет, — неделя по дню даты', () {
      for (final r in [
        rule('FREQ=MONTHLY;BYMONTHDAY=2,15'),
        rule('FREQ=MONTHLY;BYDAY=MO,TU,WE,TH,FR;BYSETPOS=3'),
        rule('FREQ=DAILY;UNTIL=20270114T120000Z'),
        const RecurrenceRule(
          rrule: ['FREQ=YEARLY;BYMONTH=1;BYMONTHDAY=14', 'FREQ=YEARLY'],
          fromCompletion: false,
        ),
        // «1-й вт» у срока в 4-ю пт (вхождение перенесено) — окно выражает
        // только день недели даты, «Сохранить» не должно менять серию молча.
        rule('FREQ=MONTHLY;BYDAY=1TU'),
      ]) {
        final c = customFromRule(r, friday);
        final why = r.rrule.join(' | ');
        expect(
          (c.unit, c.interval, c.until),
          (RepeatUnit.week, 1, null),
          reason: why,
        );
        expect(c.weekdays, {DateTime.friday}, reason: why);
      }
    });

    test('без правила — неделя по дню даты', () {
      expect(customFromRule(null, friday).weekdays, {DateTime.friday});
    });
  });
}
