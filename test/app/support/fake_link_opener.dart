import 'package:planner/platform/link_opener.dart';

/// Фейк открытия ссылок: запоминает адреса вместо браузера; [result] — что
/// вернуть (`false` — «не удалось»).
final class FakeLinkOpener implements LinkOpener {
  FakeLinkOpener({this.result = true});

  final bool result;
  final List<Uri> opened = [];

  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return result;
  }
}
