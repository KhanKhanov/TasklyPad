/// Открыть ссылку из названия или описания во внешнем приложении (браузер,
/// почта). Интерфейс — чтобы нажатие на ссылку проверялось тестом без
/// настоящего браузера.
abstract interface class LinkOpener {
  /// `false` — открыть не удалось (нет подходящего приложения).
  Future<bool> open(Uri uri);
}

/// Адрес ссылки, которую можно открыть, или `null`. Только `http`, `https` и
/// `mailto`: `file:` и прочие схемы из чужого текста (пришёл синхронизацией
/// или вставлен) могли бы запустить программу на компьютере. Адрес без схемы
/// (`www.example.com` из автоссылки) — `http`.
Uri? openableLink(String? href) {
  if (href == null) return null;
  final text = href.trim();
  final uri = Uri.tryParse(text.contains(':') ? text : 'http://$text');
  if (uri == null) return null;
  return switch (uri.scheme.toLowerCase()) {
    'http' || 'https' => uri.host.isEmpty ? null : uri,
    // У письма — только адресаты, тема и текст: `attach=` из чужого текста
    // некоторые почтовые программы понимают как файл к письму.
    'mailto' => uri.replace(
      queryParameters: uri.queryParameters.isEmpty
          ? null
          : {
              for (final MapEntry(:key, :value) in uri.queryParameters.entries)
                if (_mailFields.contains(key.toLowerCase())) key: value,
            },
    ),
    _ => null,
  };
}

const Set<String> _mailFields = {'to', 'cc', 'bcc', 'subject', 'body'};
