import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/features/common/ui/app_toast.dart';
import 'package:planner/features/common/ui/genie_transition.dart';
import 'package:planner/features/common/ui/toast_lamp_anchor.dart';

import '../support/fake_notification_log.dart';

// Нижнее уведомление с эффектом «джин» (решение пользователя 1А «Анимация
// уведомлений»): появление, уход по времени и по кнопке, «уменьшить
// движение», тост в очереди.
void main() {
  late ScaffoldMessengerState messenger;
  late FakeNotificationLog log;

  /// Окно 800×600; [lamp] — «лампа» в правом нижнем углу (иначе её нет).
  Future<void> pumpHost(
    WidgetTester tester, {
    bool reduceMotion = false,
    bool lamp = false,
  }) {
    log = FakeNotificationLog();
    return tester.pumpWidget(
      ProviderScope(
        overrides: [fakeNotificationLog(log)],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(disableAnimations: reduceMotion),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                messenger = ScaffoldMessenger.of(context);
                return Stack(
                  children: [
                    const SizedBox.expand(),
                    if (lamp)
                      const Positioned(
                        right: 0,
                        bottom: 0,
                        child: ToastLampAnchor(
                          anchor: Alignment.bottomRight,
                          mouth: 24,
                          child: SizedBox(width: 1, height: 1),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Тост рисуется полосками — идёт «джин».
  bool genieRunning(WidgetTester tester, String text) =>
      find.text(text).evaluate().length > 1;

  testWidgets('появляется «джином»: в середине — полоски, в конце — один '
      'тост', (tester) async {
    await pumpHost(tester);
    showAppToast(messenger, text: 'Saved');
    await tester.pump();
    await tester.pump(toastGenieDuration ~/ 2);
    expect(find.byType(GenieTransition), findsOneWidget);
    expect(genieRunning(tester, 'Saved'), isTrue);

    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsOneWidget);
  });

  testWidgets('через [duration] втягивается «джином» и пропадает', (
    tester,
  ) async {
    await pumpHost(tester);
    showAppToast(
      messenger,
      text: 'Saved',
      duration: const Duration(seconds: 2),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(toastGenieDuration ~/ 2);
    expect(genieRunning(tester, 'Saved'), isTrue);

    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsNothing);
  });

  testWidgets('кнопка — её действие и уход «джином»', (tester) async {
    await pumpHost(tester);
    var pressed = 0;
    showAppToast(
      messenger,
      text: 'Task completed',
      action: (label: 'Undo', onPressed: () => pressed++),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Undo'));
    await tester.pump();
    await tester.pump(toastGenieDuration ~/ 2);
    expect(pressed, 1);
    expect(genieRunning(tester, 'Task completed'), isTrue);

    await tester.pumpAndSettle();
    expect(find.text('Task completed'), findsNothing);
  });

  testWidgets('«уменьшить движение» — без «джина»: сразу на месте и уходит '
      'сразу', (tester) async {
    await pumpHost(tester, reduceMotion: true);
    showAppToast(
      messenger,
      text: 'Saved',
      duration: const Duration(seconds: 2),
    );
    await tester.pump();
    await tester.pump(toastGenieDuration ~/ 2);
    expect(find.text('Saved'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Saved'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Saved'), findsNothing);
  });

  testWidgets('тост в очереди убрали — когда дойдёт очередь, не задержится', (
    tester,
  ) async {
    await pumpHost(tester);
    showAppToast(
      messenger,
      text: 'First',
      duration: const Duration(seconds: 2),
    );
    final second = showAppToast(messenger, text: 'Second');
    await tester.pumpAndSettle();
    second.dismiss();
    expect(find.text('First'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('First'), findsNothing);
    expect(find.text('Second'), findsNothing);
  });

  testWidgets('показанный тост записан в журнал один раз; убранный в очереди '
      '— нет', (tester) async {
    await pumpHost(tester);
    showAppToast(
      messenger,
      text: 'First',
      duration: const Duration(seconds: 1),
    );
    final second = showAppToast(messenger, text: 'Second');
    await tester.pumpAndSettle();
    second.dismiss();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(log.texts, ['First']);
  });

  testWidgets('с «лампой» в правом нижнем углу полоски уходят вправо — к '
      'ней, а не под середину тоста', (tester) async {
    await pumpHost(tester, lamp: true);
    await tester.pump();
    showAppToast(
      messenger,
      text: 'Saved',
      duration: const Duration(seconds: 1),
    );
    await tester.pumpAndSettle();
    final rest = tester.getCenter(find.text('Saved'));
    await tester.pump(const Duration(seconds: 1));
    // Середина ухода: края изогнуты, нижние полоски — у лампы.
    await tester.pump(toastGenieDuration * 0.6);
    expect(genieRunning(tester, 'Saved'), isTrue);
    expect(
      tester.widget<GenieTransition>(find.byType(GenieTransition)).target!.dx,
      greaterThan(300),
    );
    expect(rest.dx, closeTo(400, 1));
    // Полоски на экране — справа от середины тоста, к лампе.
    final strips = find.text('Saved');
    final xs = [
      for (var i = 0; i < strips.evaluate().length; i++)
        tester.getCenter(strips.at(i)).dx,
    ];
    expect(xs.reduce((a, b) => a > b ? a : b), greaterThan(rest.dx + 20));
    await tester.pumpAndSettle();
  });

  testWidgets('тост убрали сразу после показа, не дав появиться, — в журнал '
      'не записан', (tester) async {
    await pumpHost(tester);
    final toast = showAppToast(messenger, text: 'Gone');
    await tester.pump(const Duration(milliseconds: 100));
    toast.close();
    await tester.pumpAndSettle();
    expect(log.texts, isEmpty);
  });
}
