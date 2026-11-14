import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/app/theme/app_palette.dart';
import 'package:planner/app/theme/app_themes.dart';
import 'package:planner/features/common/ui/app_switch.dart';

// Переключатель по образцу Amnezia (решение 1А plans/m5 «Решения M5.3a»):
// переключение касанием, клавишами и подписью строки, семантика, вид
// включённого и выключенного, светлая и тёмная палитра.
void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    Brightness brightness = Brightness.light,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: buildThemeData(
        brightness == Brightness.light ? tasklyTheme.light : tasklyTheme.dark,
        brightness,
      ),
      home: Scaffold(body: Center(child: child)),
    ),
  );

  /// Переключатель со своим состоянием; [log] — значения из `onChanged`.
  Widget host(List<bool> log, {bool initial = false, bool enabled = true}) {
    var value = initial;
    return StatefulBuilder(
      builder: (context, setState) => AppSwitchTile(
        title: const Text('Favorite'),
        value: value,
        onChanged: enabled
            ? (v) {
                log.add(v);
                setState(() => value = v);
              }
            : null,
      ),
    );
  }

  BoxDecoration knob(WidgetTester tester) =>
      tester
              .widget<AnimatedContainer>(
                find
                    .descendant(
                      of: find.byType(AppSwitch),
                      matching: find.byType(AnimatedContainer),
                    )
                    .last,
              )
              .decoration!
          as BoxDecoration;

  testWidgets('касание переключателя и подписи строки — переключает туда и '
      'обратно', (tester) async {
    final log = <bool>[];
    await pump(tester, host(log));
    await tester.tap(find.byType(AppSwitch));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Favorite'));
    await tester.pumpAndSettle();
    expect(log, [true, false]);
  });

  testWidgets('Tab — фокус на переключателе (одна остановка), Space и Enter '
      'переключают', (tester) async {
    final log = <bool>[];
    await pump(tester, host(log));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(log, [true, false]);
  });

  testWidgets('семантика: переключатель с состоянием и подписью', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(tester, host([], initial: true));
    expect(
      tester.getSemantics(find.byType(AppSwitchTile)),
      matchesSemantics(
        label: 'Favorite',
        hasToggledState: true,
        isToggled: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
        hasFocusAction: true,
        isFocusable: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('выключенный: не переключается и полупрозрачный', (tester) async {
    final log = <bool>[];
    await pump(tester, host(log, enabled: false));
    await tester.tap(find.byType(AppSwitch));
    await tester.tap(find.text('Favorite'));
    await tester.pumpAndSettle();
    expect(log, isEmpty);
    final opacity = tester.widget<Opacity>(
      find.descendant(
        of: find.byType(AppSwitch),
        matching: find.byType(Opacity),
      ),
    );
    expect(opacity.opacity, 0.4);
  });

  testWidgets('включённый — кружок цвета акцента справа со свечением; '
      'выключенный — серый слева без свечения', (tester) async {
    await pump(tester, host([]));
    final palette = AppPalette.of(tester.element(find.byType(AppSwitch)));
    final offLeft = tester.getTopLeft(find.byType(AnimatedContainer).last).dx;
    expect(knob(tester).color, palette.textSecondary);
    expect(knob(tester).boxShadow!.every((s) => s.color.a == 0), isTrue);

    await tester.tap(find.byType(AppSwitch));
    await tester.pumpAndSettle();
    final onLeft = tester.getTopLeft(find.byType(AnimatedContainer).last).dx;
    expect(onLeft - offLeft, 20);
    expect(knob(tester).color, palette.accent);
    expect(knob(tester).boxShadow!.every((s) => s.color.a > 0), isTrue);
  });

  testWidgets('наведение мыши — проступает круг позади кружка', (tester) async {
    await pump(tester, host([]));
    double halo() => tester
        .widget<AnimatedOpacity>(
          find.descendant(
            of: find.byType(AppSwitch),
            matching: find.byType(AnimatedOpacity),
          ),
        )
        .opacity;
    expect(halo(), 0);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byType(AppSwitch)));
    await tester.pumpAndSettle();
    expect(halo(), 1);
    await mouse.removePointer();
  });

  testWidgets('тёмная палитра — строится без ошибок, кружок серый', (
    tester,
  ) async {
    await pump(tester, host([]), brightness: Brightness.dark);
    final palette = AppPalette.of(tester.element(find.byType(AppSwitch)));
    expect(knob(tester).color, palette.textSecondary);
    expect(tester.takeException(), isNull);
  });
}
