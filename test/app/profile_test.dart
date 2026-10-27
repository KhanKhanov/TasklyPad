import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:planner/app/profile.dart';
import 'package:planner/app/startup_error_app.dart';

void main() {
  group('profileFromArgs', () {
    final valid = <List<String>, String?>{
      const []: null,
      const ['--verbose']: null,
      const ['--profile', 'work']: 'work',
      const ['--profile=work']: 'work',
      const ['--x', '--profile', 'test-2']: 'test-2',
      ['--profile', 'a' * 32]: 'a' * 32,
    };
    for (final MapEntry(key: args, value: profile) in valid.entries) {
      test('$args → $profile', () => expect(profileFromArgs(args), profile));
    }

    final invalid = <List<String>>[
      const ['--profile'],
      const ['--profile='],
      const ['--profile', 'Work'],
      const ['--profile', 'a/b'],
      const ['--profile', '..'],
      const ['--profile', 'дом'],
      ['--profile', 'a' * 33],
      const ['--profile', 'con'],
      const ['--profile', 'nul'],
      const ['--profile', 'com1'],
      const ['--profile', 'lpt9'],
      const ['--profile', '--profile=x'],
    ];
    for (final args in invalid) {
      test('$args → InvalidProfileException', () {
        expect(
          () => profileFromArgs(args),
          throwsA(isA<InvalidProfileException>()),
        );
      });
    }
  });

  test('profileDirectories: основной профиль — папки прежние, данные '
      'пользователя остаются на месте', () {
    final dirs = profileDirectories(
      data: p.join('r', 'data'),
      marker: p.join('l', 'marker'),
      profile: null,
    );
    expect(dirs.data, p.join('r', 'data'));
    expect(dirs.marker, p.join('l', 'marker'));
  });

  test('profileDirectories: профиль — свои подпапки и для базы, и для '
      'метки узла', () {
    final dirs = profileDirectories(
      data: p.join('r', 'data'),
      marker: p.join('l', 'marker'),
      profile: 'b',
    );
    expect(dirs.data, p.join('r', 'data', 'profiles', 'b'));
    expect(dirs.marker, p.join('l', 'marker', 'profiles', 'b'));
  });

  testWidgets('неверное имя профиля → понятная ошибка запуска', (tester) async {
    await tester.pumpWidget(
      const StartupErrorApp(error: InvalidProfileException('Work')),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('"Work"'), findsOneWidget); // локаль тестов — en
    expect(find.textContaining('32'), findsOneWidget);
  });
}
