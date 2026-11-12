import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../platform/link_opener.dart';
import '../platform/url_link_opener.dart';

part 'platform_providers.g.dart';

/// Открытие ссылок из названия и описания; в тестах — фейк.
@Riverpod(keepAlive: true)
LinkOpener linkOpener(Ref ref) => const UrlLinkOpener();
