import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/app/app.dart';

void main() {
  testWidgets(
    'приложение стартует → открыт экран Входящие (локаль теста — en)',
    (tester) async {
      await tester.pumpWidget(const ProviderScope(child: PlannerApp()));
      await tester.pumpAndSettle();

      expect(find.text('Inbox'), findsOneWidget);
      expect(find.text('No tasks yet'), findsOneWidget);
    },
  );
}
