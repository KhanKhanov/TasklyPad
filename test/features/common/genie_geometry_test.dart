import 'package:flutter_test/flutter_test.dart';
import 'package:planner/features/common/ui/genie_transition.dart';

// Геометрия «джина» (решения 1А–5А plans/m5 «Решения M5.3a»): полоска
// уходит к лампе по S-кривой. Тост 360×60, лампа справа внизу.
void main() {
  const w = 360.0;
  const lamp = Offset(300, 120);
  const mouth = 20.0;

  GenieBand band(double collapse, double mid) => genieBand(
    collapse: collapse,
    bandMid: mid,
    width: w,
    target: lamp,
    mouthWidth: mouth,
  );

  test('на месте (collapse 0) — полоска без сдвига, сжатия и смещения', () {
    for (final mid in [1.0, 30.0, 59.0]) {
      final b = band(0, mid);
      expect(b.centerX, w / 2);
      expect(b.scaleX, 1);
      expect(b.slide, 0);
      expect(b.visible, isTrue);
    }
  });

  test('в лампе (collapse 1) — все полоски за горлышком, не видны', () {
    for (final mid in [1.0, 30.0, 59.0]) {
      expect(band(1, mid).visible, isFalse);
    }
  });

  test('на изгибе центр — между серединой и X лампы и тем ближе к лампе, '
      'чем ниже полоска; ширина сужается к горлышку', () {
    final upper = band(0.5, 10);
    final lower = band(0.5, 50);
    for (final b in [upper, lower]) {
      expect(b.centerX, greaterThan(w / 2));
      expect(b.centerX, lessThan(lamp.dx));
      expect(b.scaleX, lessThan(1));
      expect(b.scaleX, greaterThan(mouth / w));
    }
    expect(lower.centerX, greaterThan(upper.centerX));
    expect(lower.scaleX, lessThan(upper.scaleX));
  });

  test('S-кривая: у тоста и у горлышка край почти вертикален, в середине '
      'пути изгиб сильнее всего', () {
    // Смещение центра на равных шагах вниз; σ′ = 0 на концах.
    double shift(double y) => band(0.5, y).centerX;
    const step = 1.0;
    final nearTop = shift(step) - shift(0);
    final middle = shift(lamp.dy / 2 + step) - shift(lamp.dy / 2);
    expect(nearTop, lessThan(middle / 20));
  });

  test('вторая фаза — полоски съезжают вниз, нижние уходят в горлышко '
      'первыми', () {
    // collapse 0.9: сдвиг 0.8 × 120 = 96; полоска на 50 — на 146, за
    // горлышком (120), на 10 — на 106, ещё видна.
    expect(band(0.9, 50).slide, closeTo(96, 1e-9));
    expect(band(0.9, 50).visible, isFalse);
    expect(band(0.9, 10).visible, isTrue);
  });

  test('лампа прямо под серединой — центр полосок не смещается', () {
    final b = genieBand(
      collapse: 0.5,
      bandMid: 40,
      width: w,
      target: const Offset(w / 2, 76),
      mouthWidth: w * 0.06,
    );
    expect(b.centerX, w / 2);
    expect(b.scaleX, lessThan(1));
  });
}
