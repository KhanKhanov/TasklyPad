import 'package:flutter_test/flutter_test.dart';
import 'package:planner/app/startup_error_app.dart';
import 'package:planner/data/db_backup.dart';

void main() {
  testWidgets('база новее приложения → экран с версиями и советом обновить', (
    tester,
  ) async {
    await tester.pumpWidget(
      StartupErrorApp(error: SchemaTooNewException(3, 1)),
    );
    await tester.pumpAndSettle();

    expect(find.text("Couldn't open your data"), findsOneWidget);
    expect(find.textContaining('schema 3'), findsOneWidget);
    expect(find.textContaining('up to 1'), findsOneWidget);
  });

  testWidgets('прочая ошибка → экран с подробностями', (tester) async {
    await tester.pumpWidget(StartupErrorApp(error: StateError('диск')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Details: Bad state: диск'), findsOneWidget);
  });
}
