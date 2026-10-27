import 'package:path/path.dart' as p;

/// Профиль данных: `--profile <имя>` или `--profile=<имя>` в аргументах
/// запуска. У профиля своя база, своя метка узла и свой экземпляр приложения
/// (mutex в windows/runner/main.cpp разбирает аргументы так же), поэтому на
/// одном ПК живут два «устройства» для проверки синхронизации через общую
/// папку (docs/plans/m2-core-app.md, решение 14).
///
/// `null` — основной профиль: его папки не меняются, данные пользователя
/// остаются на месте.
String? profileFromArgs(List<String> args) {
  const flag = '--profile';
  for (var i = 0; i < args.length; i++) {
    if (args[i] == flag) {
      if (i + 1 >= args.length) throw const InvalidProfileException('');
      return _checked(args[i + 1]);
    }
    if (args[i].startsWith('$flag=')) {
      return _checked(args[i].substring(flag.length + 1));
    }
  }
  return null;
}

final RegExp _profileName = RegExp(r'^[a-z0-9-]{1,32}$');

// Имена устройств Windows: путь `profiles/con` вёл бы не в папку, а в
// устройство.
final RegExp _windowsDevice = RegExp(r'^(con|prn|aux|nul|com[1-9]|lpt[1-9])$');

String _checked(String name) {
  if (!_profileName.hasMatch(name) || _windowsDevice.hasMatch(name)) {
    throw InvalidProfileException(name);
  }
  return name;
}

/// Папки базы и метки узла профиля [profile] внутри основных [data] и
/// [marker]; у основного профиля (`null`) — они сами.
({String data, String marker}) profileDirectories({
  required String data,
  required String marker,
  required String? profile,
}) => profile == null
    ? (data: data, marker: marker)
    : (
        data: p.join(data, 'profiles', profile),
        marker: p.join(marker, 'profiles', profile),
      );

/// Имя профиля не подходит: нужны латинские строчные буквы, цифры и дефис,
/// до 32 символов, и не имя устройства Windows (`con`, `nul`, `com1`…) —
/// имя становится частью пути и имени mutex.
final class InvalidProfileException implements Exception {
  const InvalidProfileException(this.name);

  final String name;

  @override
  String toString() => 'InvalidProfileException: «$name»';
}
