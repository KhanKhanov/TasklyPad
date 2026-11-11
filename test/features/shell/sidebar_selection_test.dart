import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/app/theme/app_palette.dart';
import 'package:planner/features/shell/ui/sidebar.dart';
import 'package:planner/features/shell/ui/sidebar_selection.dart';

import '../../app/support/pump_app.dart';

// Выделение пункта сайдбара: рамка и тень (решение 12Б M4.10a). Локаль — en.
void main() {
  Finder item(String text) => find.ancestor(
    of: find.descendant(of: find.byType(Sidebar), matching: find.text(text)),
    matching: find.byType(SidebarSelectable),
  );

  BoxDecoration decoration(WidgetTester tester, String text) {
    final box = tester.widget<DecoratedBox>(
      find
          .descendant(of: item(text), matching: find.byType(DecoratedBox))
          .first,
    );
    return box.decoration as BoxDecoration;
  }

  testWidgets('выбранный пункт — рамка и тень, другие без них', (tester) async {
    await withApp(tester, (device) async {
      await tester.tap(
        find.descendant(of: find.byType(Sidebar), matching: find.text('Today')),
      );
      await settle(tester);

      final palette = AppPalette.of(tester.element(find.byType(Sidebar)));
      final selected = decoration(tester, 'Today');
      expect((selected.border! as Border).top.color, palette.selectedBorder);
      expect(selected.boxShadow, isNotEmpty);
      expect(selected.boxShadow!.first.color, palette.selectedShadow);

      final other = decoration(tester, 'Upcoming');
      expect((other.border! as Border).top.color, Colors.transparent);
      expect(other.boxShadow, isNull);
    });
  });
}
