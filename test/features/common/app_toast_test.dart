import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/features/common/ui/app_toast.dart';
import 'package:planner/features/common/ui/genie_transition.dart';

// Нижнее уведомление с эффектом «джин» (решение пользователя 1А «Анимация
// уведомлений»): появление, уход по времени и по кнопке, «уменьшить
// движение», тост в очереди.
void main() {
  late ScaffoldMessengerState messenger;

  Future<void> pumpHost(WidgetTester tester, {bool reduceMotion = false}) =>
      tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(disableAnimations: reduceMotion),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                messenger = ScaffoldMessenger.of(context);
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      );

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
}
