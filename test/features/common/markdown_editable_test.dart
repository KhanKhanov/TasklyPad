import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/domain/markdown_text.dart';
import 'package:planner/features/common/ui/markdown_editable.dart';

// Поле с markdown по решению 7А плана M4: вне работы отрисовано, в работе —
// исходный текст.
void main() {
  Future<(TextEditingController, FocusNode)> pump(
    WidgetTester tester,
    String text, {
    bool readOnly = false,
  }) async {
    final controller = TextEditingController(text: text);
    final focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: Column(
            children: [
              MarkdownEditable(
                controller: controller,
                focusNode: focus,
                readOnly: readOnly,
                hasMarkup: hasInlineMarkup,
                decoration: const InputDecoration(),
                rendered: (t) => Text('rendered:${plainText(t)}'),
                editor: TextField(controller: controller, focusNode: focus),
              ),
              const TextField(key: Key('other')),
            ],
          ),
        ),
      ),
    );
    return (controller, focus);
  }

  testWidgets('с разметкой — отрисовано; нажатие — поле с исходным текстом и '
      'курсором; уход — снова отрисовано, уже с набранным', (tester) async {
    final (controller, focus) = await pump(tester, '**Bold**');
    expect(find.text('rendered:Bold'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    await tester.tap(find.text('rendered:Bold'));
    await tester.pumpAndSettle();
    expect(focus.hasFocus, isTrue);
    expect(find.text('**Bold**'), findsOneWidget);

    controller.text = '**New**';
    await tester.tap(find.byKey(const Key('other')));
    await tester.pumpAndSettle();
    expect(find.text('rendered:New'), findsOneWidget);
  });

  testWidgets('без разметки — сразу поле', (tester) async {
    await pump(tester, 'Plain');
    expect(find.text('Plain'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
  });

  testWidgets('только просмотр — нажатие поле не открывает', (tester) async {
    final (_, focus) = await pump(tester, '**Bold**', readOnly: true);
    await tester.tap(find.text('rendered:Bold'));
    await tester.pumpAndSettle();
    expect(focus.hasFocus, isFalse);
    expect(find.text('rendered:Bold'), findsOneWidget);
  });
}
