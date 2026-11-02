import 'package:flutter_test/flutter_test.dart';
import 'package:planner/nlp/parse_context.dart';

// Язык разбора — язык интерфейса (решение 8А плана M3).
void main() {
  test('languageFor — ru и en как есть, незнакомый язык — en, как у '
      'интерфейса', () {
    expect(ParseContext.languageFor('ru'), 'ru');
    expect(ParseContext.languageFor('en'), 'en');
    expect(ParseContext.languageFor('de'), 'en');
  });
}
