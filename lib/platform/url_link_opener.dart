import 'package:url_launcher/url_launcher.dart';

import 'link_opener.dart';

/// [LinkOpener] через пакет `url_launcher`: ссылка открывается в приложении
/// по умолчанию (браузер, почта) — на Windows и Android одинаково.
final class UrlLinkOpener implements LinkOpener {
  const UrlLinkOpener();

  @override
  Future<bool> open(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Exception {
      // Нет приложения для схемы — экран покажет «Не удалось открыть
      // ссылку».
      return false;
    }
  }
}
