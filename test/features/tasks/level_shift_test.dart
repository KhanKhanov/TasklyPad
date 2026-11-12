import 'package:flutter_test/flutter_test.dart';
import 'package:planner/features/tasks/ui/task_drag.dart';

// Уровень подзадачи при перетаскивании — с гистерезисом (решение 5А «M4.10a»
// plans/m4, пороги — уточнение 12.11.2026): вправо на 1¼ шага, влево на шаг,
// обратно — на ½.
void main() {
  const step = 28.0;

  test('сдвиг указателя по шагам → уровень с гистерезисом', () {
    final cases = <(double, int, int)>[
      // (сдвиг в шагах, прошлый сдвиг уровня, ожидаемый)
      (0.8, 0, 0), // меньше 1¼ шага — уровень прежний
      (1.2, 0, 0),
      (1.3, 0, 1), // 1¼ пройдены — на уровень глубже
      (0.6, 1, 1), // назад меньше чем на ½ шага — ещё глубже
      (0.4, 1, 0), // назад на ½ шага — прежний уровень
      (2.3, 1, 2),
      (3.0, 0, 2), // рывок — сразу на два уровня
      (-0.9, 0, 0), // влево меньше шага — уровень прежний
      (-1.1, 0, -1), // влево на шаг — на уровень выше
      (-0.6, -1, -1),
      (-0.4, -1, 0),
    ];
    for (final (shift, last, expected) in cases) {
      expect(
        levelShift(dx: shift * step, step: step, last: last),
        expected,
        reason: 'сдвиг $shift шага, прошлый $last',
      );
    }
  });

  test('повторный расчёт с тем же сдвигом → тот же уровень', () {
    var last = 0;
    for (final dx in [20.0, 36.0, 36.0, 20.0, 20.0, 13.0, 13.0]) {
      final once = levelShift(dx: dx, step: step, last: last);
      expect(
        levelShift(dx: dx, step: step, last: once),
        once,
        reason: '$dx',
      );
      last = once;
    }
    expect(last, 0);
  });
}
