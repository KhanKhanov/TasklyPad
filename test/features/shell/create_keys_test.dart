import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../app/support/pump_app.dart';

// Клавиши создания (help «Use keyboard shortcuts»; О-97, решение 6А plans/m5):
// `Alt+P` и `Ctrl+Shift+P` — новый проект, `Ctrl+Shift+L` — новая метка; в
// поле ввода не срабатывают. Локаль — en.
void main() {
  Future<void> chord(
    WidgetTester tester,
    List<LogicalKeyboardKey> modifiers,
    LogicalKeyboardKey key,
  ) async {
    for (final m in modifiers) {
      await tester.sendKeyDownEvent(m);
    }
    await tester.sendKeyEvent(key);
    for (final m in modifiers.reversed) {
      await tester.sendKeyUpEvent(m);
    }
    await tester.pumpAndSettle();
  }

  Finder dialog(String title) => find.widgetWithText(AlertDialog, title);

  const alt = LogicalKeyboardKey.altLeft;
  const ctrl = LogicalKeyboardKey.controlLeft;
  const shift = LogicalKeyboardKey.shiftLeft;

  testWidgets('`Alt+P` и `Ctrl+Shift+P` — окно нового проекта, '
      '`Ctrl+Shift+L` — новой метки', (tester) async {
    await withApp(tester, (device) async {
      for (final (mods, key, title) in [
        ([alt], LogicalKeyboardKey.keyP, 'Add project'),
        ([ctrl, shift], LogicalKeyboardKey.keyP, 'Add project'),
        ([ctrl, shift], LogicalKeyboardKey.keyL, 'Add label'),
      ]) {
        await chord(tester, mods, key);
        expect(dialog(title), findsOneWidget, reason: '$mods $key');
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
      }
    });
  });

  testWidgets('в поле быстрого добавления `Alt+P` окно проекта не '
      'открывает', (tester) async {
    await withApp(tester, (device) async {
      await tester.sendKeyEvent(LogicalKeyboardKey.keyQ);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'x');
      await chord(tester, [alt], LogicalKeyboardKey.keyP);
      expect(dialog('Add project'), findsNothing);
    });
  });

  testWidgets('`Ctrl+Alt+P` (AltGr) — не новый проект', (tester) async {
    await withApp(tester, (device) async {
      await chord(tester, [ctrl, alt], LogicalKeyboardKey.keyP);
      expect(dialog('Add project'), findsNothing);
    });
  });
}
