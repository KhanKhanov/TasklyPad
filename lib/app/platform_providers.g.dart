// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'platform_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Открытие ссылок из названия и описания; в тестах — фейк.

@ProviderFor(linkOpener)
final linkOpenerProvider = LinkOpenerProvider._();

/// Открытие ссылок из названия и описания; в тестах — фейк.

final class LinkOpenerProvider
    extends $FunctionalProvider<LinkOpener, LinkOpener, LinkOpener>
    with $Provider<LinkOpener> {
  /// Открытие ссылок из названия и описания; в тестах — фейк.
  LinkOpenerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'linkOpenerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$linkOpenerHash();

  @$internal
  @override
  $ProviderElement<LinkOpener> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LinkOpener create(Ref ref) {
    return linkOpener(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LinkOpener value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LinkOpener>(value),
    );
  }
}

String _$linkOpenerHash() => r'eeeaa46db28531562f1686891c01a1e38fb8839a';
