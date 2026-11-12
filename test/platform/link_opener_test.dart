import 'package:flutter_test/flutter_test.dart';
import 'package:planner/platform/link_opener.dart';

// Какие ссылки из текста можно открыть: только http, https, mailto —
// `file:` и прочие схемы из чужого текста могли бы запустить программу.
void main() {
  const rows = {
    'https://example.com/a?b=1': 'https://example.com/a?b=1',
    'http://example.com': 'http://example.com',
    'HTTPS://Example.com': 'https://example.com',
    'www.example.com': 'http://www.example.com',
    'mailto:me@example.com': 'mailto:me@example.com',
    'mailto:me@example.com?subject=Hi&attach=C:/secret.txt':
        'mailto:me@example.com?subject=Hi',
    'file:///C:/Windows/System32/calc.exe': null,
    'javascript:alert(1)': null,
    'ms-settings:privacy': null,
    'todoist://task?id=1': null,
    'https://': null,
    '': null,
  };
  for (final MapEntry(key: href, value: expected) in rows.entries) {
    test('«$href» → ${expected ?? 'не открывается'}', () {
      expect(openableLink(href)?.toString(), expected);
    });
  }

  test('нет адреса — не открывается', () => expect(openableLink(null), isNull));
}
