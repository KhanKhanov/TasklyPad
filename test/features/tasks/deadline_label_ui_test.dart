import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/app/theme/app_palette.dart';
import 'package:planner/features/tasks/ui/due_ui.dart';
import 'package:planner/features/tasks/ui/task_dialog.dart';
import 'package:planner/features/tasks/ui/task_row.dart';
import 'package:planner/l10n/app_localizations.dart';

import '../../app/support/pump_app.dart';
import '../support/app_commands.dart';

// Дедлайн в строке задачи (решения 2А, 3А plans/m5 «Решения проверки M5.3»):
// значок — мишень, не флажок приоритета; за 1–7 дней — обратный отсчёт (help
// «Add deadlines to tasks»). Часы — пт 23.10.2026 9:00, локаль — en.
void main() {
  Finder row(String content) =>
      find.ancestor(of: find.text(content), matching: find.byType(TaskRow));

  Finder inRow(String content, Finder f) =>
      find.descendant(of: row(content), matching: f);

  Future<void> add(
    WidgetTester tester,
    AppCommands app,
    String content,
    String deadline,
  ) async {
    await tester.runAsync(
      () => app.tasks.add(content: content, deadline: deadline),
    );
    await settle(tester);
  }

  testWidgets('просрочен — дата красным; сегодня — «Today»; через 1 и 7 дней '
      '— отсчёт; через 8 — дата; значок — мишень, флажка нет', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await add(tester, app, 'Late', '2026-10-20');
      await add(tester, app, 'Now', '2026-10-23');
      await add(tester, app, 'Next', '2026-10-24');
      await add(tester, app, 'Week', '2026-10-30');
      await add(tester, app, 'Far', '2026-10-31');

      expect(inRow('Now', find.text('Today')), findsOneWidget);
      expect(inRow('Next', find.text('1 day left')), findsOneWidget);
      expect(inRow('Week', find.text('7 days left')), findsOneWidget);
      for (final name in ['Late', 'Far']) {
        expect(inRow(name, find.textContaining('left')), findsNothing);
      }
      for (final name in ['Late', 'Now', 'Next', 'Week', 'Far']) {
        expect(inRow(name, find.byIcon(deadlineIcon)), findsOneWidget);
        expect(inRow(name, find.byIcon(Icons.outlined_flag)), findsNothing);
      }
      final palette = AppPalette.of(tester.element(row('Late')));
      final late = tester.widget<Icon>(
        inRow('Late', find.byIcon(deadlineIcon)),
      );
      expect(late.color, palette.danger);
    });
  });

  test('русские формы отсчёта: 1 — «остался», 2–4 — «дня», 5–7 — «дней»', () {
    final ru = lookupAppLocalizations(const Locale('ru'));
    expect(
      [
        for (final n in [1, 2, 4, 5, 7]) ru.deadlineDaysLeft(n),
      ],
      [
        'остался 1 день',
        'осталось 2 дня',
        'осталось 4 дня',
        'осталось 5 дней',
        'осталось 7 дней',
      ],
    );
  });

  testWidgets('окно задачи — тот же отсчёт', (tester) async {
    await withApp(tester, (device) async {
      final app = AppCommands(device);
      await add(tester, app, 'Report', '2026-10-26');
      await tester.tap(find.text('Report'));
      await settle(tester);
      expect(
        find.descendant(
          of: find.byType(TaskDialog),
          matching: find.text('3 days left'),
        ),
        findsOneWidget,
      );
    });
  });
}
